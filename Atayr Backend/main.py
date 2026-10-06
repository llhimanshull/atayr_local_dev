"""
Atayr Ghost Mannequin Generator — Minimal Test API

Upload a photo of someone wearing an outfit.
Get back the outfit analysis JSON.
(Image generation is temporarily disabled per requirements).

Usage:
    1. Copy .env.example to .env and add your Gemini API key
    2. pip install -r requirements.txt
    3. uvicorn main:app --reload
    4. Open http://localhost:8000/docs and test the /analyze-only endpoint
"""

import os
import uuid
import json
import asyncio
import base64
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Depends, Header
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, HTMLResponse
import jwt

from services.analyzer import analyze_outfit
from services.generator import generate_garment_image
from services.background_remover import remove_background

MAX_CONCURRENT_GENERATIONS = int(os.getenv("MAX_CONCURRENT_GENERATIONS", "2"))

# Load environment variables
load_dotenv()

# Validate API key is set
if not os.getenv("GEMINI_API_KEY") and not os.getenv("GOOGLE_CLOUD_PROJECT"):
    print("=" * 60)
    print("WARNING: GEMINI_API_KEY or GOOGLE_CLOUD_PROJECT not found in environment!")
    print("Copy .env.example to .env and add your API key.")
    print("Get a free key at: https://aistudio.google.com/apikey")
    print("=" * 60)

# Create static directory
STATIC_DIR = Path("static")
STATIC_DIR.mkdir(exist_ok=True)

ENABLE_API_DOCS = os.getenv("ENABLE_API_DOCS", "true").lower() == "true"
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost,http://127.0.0.1").split(",")

# FastAPI app
app = FastAPI(
    title="Atayr Ghost Mannequin Generator - Analysis API",
    description=(
        "Upload a photo of someone wearing an outfit → "
        "Get structured metadata of visible garments."
    ),
    version="0.2.0",
    docs_url="/docs" if ENABLE_API_DOCS else None,
    redoc_url="/redoc" if ENABLE_API_DOCS else None,
    openapi_url="/openapi.json" if ENABLE_API_DOCS else None,
)

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in ALLOWED_ORIGINS if origin.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="static"), name="static")

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}

from services.supabase_job_service import SupabaseJobService
supabase_job_service = SupabaseJobService()

async def get_authenticated_user(authorization: Optional[str] = Header(None)):
    """Validate Supabase JWT and return user_id."""
    if not authorization or not authorization.startswith("Bearer "):
        print(f"JWT Verification Failed: Missing or malformed token (Authorization header: {authorization})")
        raise HTTPException(status_code=401, detail="Missing or malformed token")
    
    token = authorization.replace("Bearer ", "")
    
    try:
        user_resp = supabase_job_service.supabase.auth.get_user(token)
        if not user_resp or not user_resp.user:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_resp.user.id
    except Exception as e:
        print(f">>>> AUTH ERROR: Supabase Auth Verification Failed - {type(e).__name__}: {e}")
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")

class RateLimiter:
    def __init__(self, max_requests: int, window_seconds: int, name: str):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.name = name

    def __call__(self, user_id: str = Depends(get_authenticated_user)):
        from services.cache_service import CacheService
        key = f"rate_limit:{self.name}:{user_id}"
        current = CacheService.get(key)
        if current is None:
            CacheService.set(key, 1, ttl=self.window_seconds)
        elif current >= self.max_requests:
            raise HTTPException(status_code=429, detail="Rate limit exceeded. Please try again later.")
        else:
            CacheService.set(key, current + 1, ttl=self.window_seconds)
        return user_id

# Rate limiters for different endpoints
process_job_limiter = RateLimiter(max_requests=60, window_seconds=60, name="process_job")
ai_limiter = RateLimiter(max_requests=10, window_seconds=60, name="ai_endpoint")


@app.get("/")
def root():
    """Health check + quick links."""
    return {
        "service": "Atayr Ghost Mannequin Generator",
        "status": "running",
        "docs": "/docs",
        "test_ui": "/test",
        "usage": "POST /analyze-only with an image file",
    }


@app.get("/health")
def health_check():
    """Lightweight health check endpoint for UptimeRobot."""
    return {"status": "ok"}


@app.get("/test", response_class=HTMLResponse)
def test_ui():
    """Serve the test UI."""
    return (STATIC_DIR / "test.html").read_text(encoding="utf-8")


@app.post("/analyze-only")
async def analyze_only(
    image: UploadFile = File(..., description="Photo of a person wearing an outfit"),
    user_id: str = Depends(ai_limiter)
):
    """
    Run ONLY the analysis step to extract visible items.
    """
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image type: {image.content_type}. Allowed: {', '.join(ALLOWED_TYPES)}",
        )

    image_bytes = await image.read()

    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")

    if len(image_bytes) > 20 * 1024 * 1024:  # 20MB limit
        raise HTTPException(status_code=400, detail="Image too large (max 20MB)")

    source_image_id = str(uuid.uuid4())

    try:
        outfit_json = analyze_outfit(image_bytes, image.content_type)
        
        return JSONResponse({
            "source_image_id": source_image_id,
            "people": outfit_json.get("people", [])
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@app.post("/generate")
async def generate(
    image: UploadFile = File(..., description="Photo of a person wearing an outfit"),
    analysis_result: str = Form(..., description="JSON string of the complete analysis result containing the items array"),
    user_id: str = Depends(ai_limiter)
):
    """
    Generate standalone studio images for every item in the analysis result concurrently.
    """
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image type: {image.content_type}. Allowed: {', '.join(ALLOWED_TYPES)}",
        )

    image_bytes = await image.read()
    
    if len(image_bytes) > 20 * 1024 * 1024:  # 20MB limit
        raise HTTPException(status_code=400, detail="Image too large (max 20MB)")

    try:
        analysis_dict = json.loads(analysis_result)
        items = analysis_dict.get("items", [])
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in analysis_result")

    semaphore = asyncio.Semaphore(MAX_CONCURRENT_GENERATIONS)

    async def process_item(item):
        item_id = item.get("id", "unknown_id")
        async with semaphore:
            try:
                # Run the blocking generation function in a separate thread
                img_bytes, generated_id = await asyncio.to_thread(
                    generate_garment_image,
                    image_bytes,
                    image.content_type,
                    item
                )
                
                # Background Removal
                transparent_bytes, bg_status = await asyncio.to_thread(
                    remove_background,
                    img_bytes
                )
                
                # Base64 encode the final transparent bytes
                img_str = base64.b64encode(transparent_bytes).decode("utf-8")
                
                result = {
                    "item_id": generated_id,
                    "metadata": item,
                    "image_base64": img_str,
                    "status": "success",
                    "background_removal_status": bg_status
                }
                
                if bg_status == "failed":
                    result["warning"] = "Background removal failed; original generated image retained."
                    
                return result
            except Exception as e:
                return {
                    "item_id": item_id,
                    "status": "failed",
                    "error": str(e)
                }

    tasks = [process_item(item) for item in items]
    results = await asyncio.gather(*tasks)

    return JSONResponse({
        "source_image_id": analysis_dict.get("source_image_id", str(uuid.uuid4())),
        "results": results
    })

# ==============================================================================
# STEP 9: ASYNC BATCH PROCESSING
# ==============================================================================

from fastapi import BackgroundTasks
from services.analyzer import embed_garment
from services.suggestion_service import generate_suggestion
import asyncio
import uuid

# --- DEDUPLICATION CONSTANTS ---
# Using distance where 0.0 is identical. 
# We require distance <= 0.15 (similarity >= 0.85) to confidently merge garments.
CONFIDENT_MATCH_DISTANCE_THRESHOLD = 0.15

# Categories that can safely be matched against each other
CATEGORY_FAMILIES = {
    'eyewear': ['glasses', 'sunglasses', 'eyewear'],
    'glasses': ['glasses', 'sunglasses', 'eyewear'],
    'sunglasses': ['glasses', 'sunglasses', 'eyewear'],
    'bag': ['bag', 'handbag', 'purse', 'backpack', 'accessory'],
    'accessory': ['bag', 'handbag', 'purse', 'backpack', 'accessory', 'jewelry', 'watch', 'belt', 'hat'],
}

def get_compatible_categories(cat: str) -> list[str]:
    cat = cat.lower()
    return CATEGORY_FAMILIES.get(cat, [cat])

def cosine_distance(v1, v2):
    dot = sum(a*b for a,b in zip(v1, v2))
    mag1 = sum(a*a for a in v1) ** 0.5
    mag2 = sum(b*b for b in v2) ** 0.5
    if mag1 * mag2 == 0: return 1.0
    return 1.0 - (dot / (mag1 * mag2))

async def process_job_background(job_id: str):
    """
    Background worker that fetches job items, downloads source images,
    runs the AI generation, and uploads results to Supabase.
    Now uses batch processing and deduplication.
    """
    try:
        supabase_job_service.update_job_status(job_id, "processing")
        
        job = supabase_job_service.get_job(job_id)
        if not job:
            print(f"Job {job_id} not found.")
            return

        user_id = job.get("user_id")
        items = supabase_job_service.get_job_items(job_id)
        
        if not items:
            supabase_job_service.update_job_status(job_id, "completed", completed_items=0, failed_items=0)
            return

        completed_count = 0
        failed_count = 0
        
        # Phase 1: Analyze all items and extract garments
        garments_to_process = []
        for item in items:
            if item.get("status") != "queued":
                if item.get("status") == "completed":
                    completed_count += 1
                else:
                    failed_count += 1
                continue
                
            item_id = item["id"]
            source_path = item["source_image_path"]
            
            # Atomic claim
            if not supabase_job_service.claim_job_item(item_id):
                continue
            
            try:
                # File size limit before processing
                file_metadata = supabase_job_service.supabase.storage.from_("wardrobe").get_public_url(source_path) # Just as a URL placeholder for size checking if possible, but actually we have to download.
                image_data = supabase_job_service.supabase.storage.from_("wardrobe").download(source_path)
                
                if len(image_data) > 20 * 1024 * 1024:  # 20MB limit
                    supabase_job_service.update_job_item_status(item_id, "failed", error_message="Image too large (max 20MB)")
                    failed_count += 1
                    continue
                    
                supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.3)
                
                outfit_json = analyze_outfit(image_data, "image/jpeg")
                people = outfit_json.get("people", [])
                
                if not people:
                    supabase_job_service.update_job_item_status(item_id, "failed", error_message="No people found in image.")
                    failed_count += 1
                    continue
                    
                if len(people) > 1:
                    supabase_job_service.update_job_item_status(
                        item_id, "failed", 
                        error_message="Multiple people detected. Atayr currently works with photos containing one person."
                    )
                    failed_count += 1
                    continue

                garments_found = people[0].get("garments", [])
                seen_garment_ids = set()
                for garment_item in garments_found:
                    g_id = garment_item.get("id")
                    if g_id in seen_garment_ids:
                        continue
                    seen_garment_ids.add(g_id)
                    
                    garments_to_process.append({
                        "item_id": item_id,
                        "source_path": source_path,
                        "image_data": image_data,
                        "garment_item": garment_item
                    })
                    
            except Exception as e:
                print(f"Error analyzing item {item_id}: {e}")
                supabase_job_service.update_job_item_status(item_id, "failed", error_message=str(e))
                failed_count += 1

        # Phase 2: Deduplication and Generation
        # We will keep track of new unique garments created in this batch
        # so intra-batch duplicates map to the same newly created garment ID.
        new_unique_garments = [] # List of dicts: {"garment_id": str, "embedding": list, "category": str}
        
        # Group garments by item_id to update item status properly
        item_progress = {g["item_id"]: 0 for g in garments_to_process}
        failed_item_ids = set()
        limit_hit_item_ids = set()
        
        for g in garments_to_process:
            item_id = g["item_id"]
            if item_id in failed_item_ids:
                continue
                
            garment_item = g["garment_item"]
            image_data = g["image_data"]
            source_path = g["source_path"]
            
            supabase_job_service.update_job_item_status(item_id, "generating", progress=0.5)
            
            embedding, log_data = await asyncio.to_thread(embed_garment, garment_item, image_data)
            category = garment_item.get("category", "Unknown")
            
            if not embedding:
                print(f"\n[EMBEDDING FAILURE]")
                print(f"  Garment Temp ID: {garment_item.get('id', 'unknown')}")
                print(f"  Category: {category}")
                print(f"  Embedding Model: text-embedding-004")
                print(f"  Failure Reason: EMBEDDING_GENERATION_FAILED")
                print(f"  Retry Status: Marked item {item_id} as failed/retryable\n")
                
                failed_item_ids.add(item_id)
                supabase_job_service.update_job_item_status(item_id, "failed", error_message="EMBEDDING_GENERATION_FAILED")
                failed_count += 1
                continue

            matched_garment_id = None
            
            # 1. Check against DB
            compatible_cats = get_compatible_categories(category)
            db_candidates = []
            for c_cat in compatible_cats:
                db_candidates.extend(supabase_job_service.match_garment_observation(user_id, c_cat, embedding, threshold=CONFIDENT_MATCH_DISTANCE_THRESHOLD))
            
            # 2. Check against in-memory (intra-batch)
            memory_candidates = []
            for nu in new_unique_garments:
                if nu["category"].lower() in compatible_cats:
                    dist = cosine_distance(nu["embedding"], embedding)
                    if dist <= CONFIDENT_MATCH_DISTANCE_THRESHOLD:
                        memory_candidates.append({"garment_id": nu["garment_id"], "similarity": 1.0 - dist})
            
            all_candidates = db_candidates + memory_candidates
            all_candidates.sort(key=lambda x: x["similarity"], reverse=True)
            
            if all_candidates:
                top_candidate = all_candidates[0]
                best_similarity = top_candidate["similarity"]
                best_distance = 1.0 - best_similarity
                best_id = top_candidate["garment_id"]
                
                print(f"\n[DUPLICATE MATCH]")
                print(f"User: {user_id}")
                print(f"Category: {category} (Compatible searched: {compatible_cats})")
                print(f"Candidate garment: {best_id}")
                print(f"Cosine distance: {best_distance:.4f}")
                print(f"Threshold: <= {CONFIDENT_MATCH_DISTANCE_THRESHOLD}")
                
                if best_distance <= CONFIDENT_MATCH_DISTANCE_THRESHOLD:
                    matched_garment_id = best_id
                    print("Decision: REUSE_EXISTING")
                else:
                    print("Decision: CREATE_NEW (Uncertain match defaulted to new garment to prevent false merges)")
            else:
                print(f"\n[DUPLICATE MATCH]")
                print(f"User: {user_id}")
                print(f"Category: {category}")
                print("Candidate garment: None")
                print("Decision: CREATE_NEW (No candidates found)")

            if matched_garment_id:
                # It's a duplicate, just insert observation
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': matched_garment_id,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern"),
                        'style': garment_item.get("style"),
                        'fit': garment_item.get("fit")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
            else:
                # It's a new garment, Re-check job item status before expensive generation
                check_item = supabase_job_service.supabase.table("processing_job_items").select("status").eq("id", item_id).execute()
                if not check_item.data or check_item.data[0]["status"] not in ("analyzing", "generating"):
                    print(f"Skipping generation for {item_id}: status changed.")
                    failed_item_ids.add(item_id)
                    continue

                # Generate studio image
                img_bytes, generated_id = await asyncio.to_thread(
                    generate_garment_image, image_data, "image/jpeg", garment_item
                )
                
                transparent_bytes, bg_status = await asyncio.to_thread(
                    remove_background, img_bytes
                )
                
                # Double-Checked Vector Search (Concurrency Protection)
                # Another worker might have inserted the canonical garment while we were generating.
                re_candidates = []
                for c_cat in compatible_cats:
                    re_candidates.extend(supabase_job_service.match_garment_observation(user_id, c_cat, embedding, threshold=CONFIDENT_MATCH_DISTANCE_THRESHOLD))
                
                re_candidates.sort(key=lambda x: x["similarity"], reverse=True)
                if re_candidates and (1.0 - re_candidates[0]["similarity"]) <= CONFIDENT_MATCH_DISTANCE_THRESHOLD:
                    print(f"\n[DOUBLE-CHECKED LOCK] Caught concurrent insertion! Reusing {re_candidates[0]['garment_id']}")
                    matched_garment_id = re_candidates[0]["garment_id"]
                    
                    obs_uuid = str(uuid.uuid4())
                    obs_row = {
                        'id': obs_uuid,
                        'garment_id': matched_garment_id,
                        'source_image_path': source_path,
                        'embedding': embedding,
                        'detected_attributes': {
                            'category': category,
                            'subcategory': garment_item.get("subcategory"),
                            'primary_color': garment_item.get("primary_color"),
                            'secondary_color': garment_item.get("secondary_color"),
                            'pattern': garment_item.get("pattern"),
                            'style': garment_item.get("style"),
                            'fit': garment_item.get("fit")
                        }
                    }
                    supabase_job_service.insert_garment_observation(obs_row)
                    continue # skip insertion
                
                # 4. Upload garment to Supabase
                
                garment_uuid = str(uuid.uuid4())
                studio_image_path = f"{user_id}/garments/{garment_uuid}.png"
                thumb_image_path = f"{user_id}/garments/{garment_uuid}_thumb.webp"
                medium_image_path = f"{user_id}/garments/{garment_uuid}_medium.webp"
                
                from services.image_optimizer import generate_image_variants
                thumb_bytes, med_bytes = generate_image_variants(transparent_bytes)
                
                # Upload original
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=studio_image_path,
                    file=transparent_bytes,
                    file_options={"content-type": "image/png"}
                )
                
                # Upload variants
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=thumb_image_path, file=thumb_bytes, file_options={"content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable"}
                )
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=medium_image_path, file=med_bytes, file_options={"content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable"}
                )
                
                db_row = {
                    'id': garment_uuid,
                    'user_id': user_id,
                    'name': garment_item.get("name", "Generated Garment"),
                    'category': category,
                    'subcategory': garment_item.get("subcategory"),
                    'primary_color': garment_item.get("primary_color"),
                    'secondary_color': garment_item.get("secondary_color"),
                    'pattern': garment_item.get("pattern"),
                    'style': garment_item.get("style"),
                    'fit': garment_item.get("fit"),
                    'studio_image_path': studio_image_path,
                    'source_image_path': source_path,
                    'embedding': embedding, # keeping on garment table too for legacy support
                }
                insert_result = supabase_job_service.insert_garment_if_under_limit(db_row)
                
                if not insert_result.get("success"):
                    print(f"Skipping insertion for {garment_uuid}: Wardrobe limit reached.")
                    limit_hit_item_ids.add(item_id)
                    continue
                
                # Insert observation
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': garment_uuid,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
                
                # Add to in-memory list so next items in batch can match it
                new_unique_garments.append({
                    "garment_id": garment_uuid,
                    "embedding": embedding,
                    "category": category
                })
        
        # Mark all fully processed items as completed
        processed_item_ids = set([g["item_id"] for g in garments_to_process])
        for item_id in processed_item_ids:
            if item_id in failed_item_ids:
                continue
            elif item_id in limit_hit_item_ids:
                supabase_job_service.update_job_item_status(item_id, "completed", error_message="Your free wardrobe is full (30 items).", progress=1.0)
                completed_count += 1
            else:
                supabase_job_service.update_job_item_status(item_id, "completed", progress=1.0)
                completed_count += 1

        # Finalize Job Status
        remaining_items = supabase_job_service.supabase.table("processing_job_items").select("*").eq("job_id", job_id).execute()
        
        all_done = True
        for i in remaining_items.data:
            if i["status"] not in ["completed", "failed", "cancelled", "skipped"]:
                all_done = False
                break
                
        if all_done:
            final_status = "completed" if failed_count < len(items) else "failed"
            supabase_job_service.update_job_status(
                job_id, 
                final_status,
                completed_items=completed_count,
                failed_items=failed_count
            )
        
    except Exception as e:
        print(f"Fatal error in background job {job_id}: {e}")
        supabase_job_service.update_job_status(job_id, "failed", error_message=str(e))


async def resume_job_item_background(item_id: str, person_id: str):
    """
    Resumes processing for a job item that was paused for person selection.
    """
    try:
        # Atomic claim
        if not supabase_job_service.claim_paused_job_item(item_id):
            print(f"Item {item_id} is already being resumed or processed.")
            return

        item_res = supabase_job_service.supabase.table("processing_job_items").select("*").eq("id", item_id).execute()
        if not item_res.data:
            return
        item = item_res.data[0]
        job_id = item["job_id"]
        user_id = item["user_id"]
        source_path = item["source_image_path"]
        
        supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.3)
        image_data = supabase_job_service.supabase.storage.from_("wardrobe").download(source_path)
        
        outfit_json = item.get("analysis_data", {})
        people = outfit_json.get("people", [])
        
        target_person = next((p for p in people if p["id"] == person_id), None)
        if not target_person:
            supabase_job_service.update_job_item_status(item_id, "failed", error_message=f"Person {person_id} not found in analysis data.")
            return
            
        garments_found = target_person.get("garments", [])
        
        supabase_job_service.update_job_item_status(item_id, "generating", progress=0.5)
        
        has_failure = False
        for garment_item in garments_found:
            
            # --- DEDUPLICATION LOGIC (STEP 12) ---
            embedding, log_data = await asyncio.to_thread(embed_garment, garment_item, image_data)
            category = garment_item.get("category", "Unknown")
            
            print(f"\n[DIAGNOSTIC LOG] Garment Processed (Resume Item)")
            print(f"  Job ID: {job_id}")
            print(f"  Photo ID: {item_id}")
            print(f"  Garment Temp ID: {garment_item.get('id', 'unknown')}")
            print(f"  Category: {category}")
            print(f"  Crop Dimensions: {log_data.get('crop_dimensions')}")
            print(f"  Embedding Successfully Generated?: {'YES' if log_data.get('embedding_success') else 'NO'}")
            print(f"  Embedding Fallback Used?: {'YES' if log_data.get('fallback_used') else 'NO'}")
            if log_data.get('fallback_used'):
                print(f"  MULTIMODAL EMBEDDING FAILED")
            print(f"  Embedding Source Type: {log_data.get('embedding_source_type')}")
            
            if not embedding:
                print(f"\n[EMBEDDING FAILURE]")
                print(f"  Garment Temp ID: {garment_item.get('id', 'unknown')}")
                print(f"  Category: {category}")
                print(f"  Embedding Model: text-embedding-004")
                print(f"  Failure Reason: EMBEDDING_GENERATION_FAILED")
                print(f"  Retry Status: Marked item {item_id} as failed/retryable\n")
                
                supabase_job_service.update_job_item_status(item_id, "failed", error_message="EMBEDDING_GENERATION_FAILED")
                has_failure = True
                break
                
            matched_garment_id = None
            
            compatible_cats = get_compatible_categories(category)
            db_candidates = []
            for c_cat in compatible_cats:
                db_candidates.extend(supabase_job_service.match_garment_observation(user_id, c_cat, embedding, threshold=CONFIDENT_MATCH_DISTANCE_THRESHOLD))
                
            db_candidates.sort(key=lambda x: x["similarity"], reverse=True)
            
            if db_candidates:
                top_candidate = db_candidates[0]
                best_similarity = top_candidate["similarity"]
                best_distance = 1.0 - best_similarity
                best_id = top_candidate["garment_id"]
                
                print(f"\n[DUPLICATE MATCH]")
                print(f"User: {user_id}")
                print(f"Category: {category} (Compatible searched: {compatible_cats})")
                print(f"Candidate garment: {best_id}")
                print(f"Cosine distance: {best_distance:.4f}")
                print(f"Threshold: <= {CONFIDENT_MATCH_DISTANCE_THRESHOLD}")
                
                if best_distance <= CONFIDENT_MATCH_DISTANCE_THRESHOLD:
                    matched_garment_id = best_id
                    print("Decision: REUSE_EXISTING")
                else:
                    print("Decision: CREATE_NEW (Uncertain match defaulted to new garment to prevent false merges)")
            else:
                print(f"\n[DUPLICATE MATCH]")
                print(f"User: {user_id}")
                print(f"Category: {category}")
                print("Candidate garment: None")
                print("Decision: CREATE_NEW (No candidates found)")
            
            if matched_garment_id:
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': matched_garment_id,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern"),
                        'style': garment_item.get("style"),
                        'fit': garment_item.get("fit")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
            else:
                # Re-check job item status before expensive generation
                check_item = supabase_job_service.supabase.table("processing_job_items").select("status").eq("id", item_id).execute()
                if not check_item.data or check_item.data[0]["status"] not in ("analyzing", "generating"):
                    print(f"Skipping generation for {item_id}: status changed.")
                    has_failure = True
                    break

                img_bytes, generated_id = await asyncio.to_thread(
                    generate_garment_image, image_data, "image/jpeg", garment_item
                )
                
                transparent_bytes, bg_status = await asyncio.to_thread(
                    remove_background, img_bytes
                )
                
                # Double-Checked Vector Search (Concurrency Protection)
                re_candidates = []
                for c_cat in compatible_cats:
                    re_candidates.extend(supabase_job_service.match_garment_observation(user_id, c_cat, embedding, threshold=CONFIDENT_MATCH_DISTANCE_THRESHOLD))
                
                re_candidates.sort(key=lambda x: x["similarity"], reverse=True)
                if re_candidates and (1.0 - re_candidates[0]["similarity"]) <= CONFIDENT_MATCH_DISTANCE_THRESHOLD:
                    print(f"\n[DOUBLE-CHECKED LOCK] Caught concurrent insertion! Reusing {re_candidates[0]['garment_id']}")
                    matched_garment_id = re_candidates[0]["garment_id"]
                    
                    obs_uuid = str(uuid.uuid4())
                    obs_row = {
                        'id': obs_uuid,
                        'garment_id': matched_garment_id,
                        'source_image_path': source_path,
                        'embedding': embedding,
                        'detected_attributes': {
                            'category': category,
                            'subcategory': garment_item.get("subcategory"),
                            'primary_color': garment_item.get("primary_color"),
                            'secondary_color': garment_item.get("secondary_color"),
                            'pattern': garment_item.get("pattern"),
                            'style': garment_item.get("style"),
                            'fit': garment_item.get("fit")
                        }
                    }
                    supabase_job_service.insert_garment_observation(obs_row)
                    continue
                
                garment_uuid = str(uuid.uuid4())
                studio_image_path = f"{user_id}/garments/{garment_uuid}.png"
                thumb_image_path = f"{user_id}/garments/{garment_uuid}_thumb.webp"
                medium_image_path = f"{user_id}/garments/{garment_uuid}_medium.webp"
                
                from services.image_optimizer import generate_image_variants
                thumb_bytes, med_bytes = generate_image_variants(transparent_bytes)
                
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=studio_image_path,
                    file=transparent_bytes,
                    file_options={"content-type": "image/png"}
                )
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=thumb_image_path, file=thumb_bytes, file_options={"content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable"}
                )
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=medium_image_path, file=med_bytes, file_options={"content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable"}
                )
                
                db_row = {
                    'id': garment_uuid,
                    'user_id': user_id,
                    'name': garment_item.get("name", "Generated Garment"),
                    'category': category,
                    'subcategory': garment_item.get("subcategory"),
                    'primary_color': garment_item.get("primary_color"),
                    'secondary_color': garment_item.get("secondary_color"),
                    'pattern': garment_item.get("pattern"),
                    'style': garment_item.get("style"),
                    'fit': garment_item.get("fit"),
                    'studio_image_path': studio_image_path,
                    'source_image_path': source_path,
                    'embedding': embedding,
                }
                supabase_job_service.insert_garment(db_row)
                
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': garment_uuid,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
            
        if not has_failure:
            supabase_job_service.update_job_item_status(item_id, "completed", progress=1.0)
        
        # Check if job is fully completed now
        remaining_items = supabase_job_service.supabase.table("processing_job_items").select("*").eq("job_id", job_id).execute()
        all_done = True
        completed_count = 0
        failed_count = 0
        
        for i in remaining_items.data:
            if i["status"] == "completed":
                completed_count += 1
            elif i["status"] == "failed":
                failed_count += 1
            elif i["status"] not in ["completed", "failed", "cancelled"]:
                all_done = False
                
        if all_done:
            final_status = "completed" if failed_count < len(remaining_items.data) else "failed"
            supabase_job_service.update_job_status(
                job_id, 
                final_status,
                completed_items=completed_count,
                failed_items=failed_count
            )
            
    except Exception as e:
        print(f"Fatal error in resuming item {item_id}: {e}")
        supabase_job_service.update_job_item_status(item_id, "failed", error_message=str(e))




@app.post("/process-job/{job_id}")
async def process_job(
    job_id: str, 
    background_tasks: BackgroundTasks,
    user_id: str = Depends(process_job_limiter)
):
    """
    Trigger the backend to start processing an asynchronous job.
    Returns immediately to avoid blocking the client UI.
    """
    job = supabase_job_service.get_job(job_id)
    if not job or job.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")

    if job.get("status") in ["processing", "completed", "failed", "cancelled"]:
        raise HTTPException(status_code=400, detail="Job has already been processed or is currently processing")

    items = supabase_job_service.get_job_items(job_id)
    MAX_PHOTOS = int(os.getenv("MAX_PHOTOS_PER_BATCH", "10"))
    if items and len(items) > MAX_PHOTOS:
        supabase_job_service.update_job_status(job_id, "failed")
        raise HTTPException(status_code=400, detail=f"Maximum {MAX_PHOTOS} photos per batch allowed.")

    # Mark as processing synchronously to avoid concurrent triggers bypassing the check
    supabase_job_service.update_job_status(job_id, "processing")

    background_tasks.add_task(process_job_background, job_id)
    return {"status": "accepted", "job_id": job_id, "message": "Job is processing in the background."}

@app.post("/generate-suggestion")
async def generate_suggestion_endpoint(
    image: UploadFile = File(..., description="Photo of a person wearing an outfit"),
    item_json: str = Form(..., description="JSON string of the selected garment"),
    user_id: str = Depends(ai_limiter)
):
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported image type")

    image_bytes = await image.read()
    if len(image_bytes) > 20 * 1024 * 1024:  # 20MB limit
        raise HTTPException(status_code=400, detail="Image too large (max 20MB)")
        
    try:
        item = json.loads(item_json)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid item JSON")
        
    try:
        result = await generate_suggestion(user_id, image_bytes, image.content_type, item)
        return JSONResponse(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/process-job-item/{item_id}/resume")
async def resume_job_item(
    item_id: str, 
    person_id: str, 
    background_tasks: BackgroundTasks,
    user_id: str = Depends(process_job_limiter)
):
    """
    Resumes processing for a job item that was paused for person selection.
    """
    # Fetch job item to check ownership
    item_res = supabase_job_service.supabase.table("processing_job_items").select("*").eq("id", item_id).execute()
    if not item_res.data or item_res.data[0].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")

    background_tasks.add_task(resume_job_item_background, item_id, person_id)
    return {"status": "accepted", "message": "Item processing resumed."}
