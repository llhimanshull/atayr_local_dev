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

from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, HTMLResponse

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

# FastAPI app
app = FastAPI(
    title="Atayr Ghost Mannequin Generator - Analysis API",
    description=(
        "Upload a photo of someone wearing an outfit → "
        "Get structured metadata of visible garments."
    ),
    version="0.2.0",
)

app.mount("/static", StaticFiles(directory="static"), name="static")

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


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


@app.get("/test", response_class=HTMLResponse)
def test_ui():
    """Serve the test UI."""
    return (STATIC_DIR / "test.html").read_text(encoding="utf-8")


@app.post("/analyze-only")
async def analyze_only(
    image: UploadFile = File(..., description="Photo of a person wearing an outfit"),
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
            "items": outfit_json.get("items", [])
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@app.post("/generate")
async def generate(
    image: UploadFile = File(..., description="Photo of a person wearing an outfit"),
    analysis_result: str = Form(..., description="JSON string of the complete analysis result containing the items array")
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
from services.supabase_job_service import SupabaseJobService

supabase_job_service = SupabaseJobService()

async def process_job_background(job_id: str):
    """
    Background worker that fetches job items, downloads source images,
    runs the AI generation, and uploads results to Supabase.
    """
    try:
        # Mark job as processing
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
        
        for item in items:
            if item.get("status") != "queued":
                if item.get("status") == "completed":
                    completed_count += 1
                else:
                    failed_count += 1
                continue
                
            item_id = item["id"]
            source_path = item["source_image_path"]
            
            try:
                supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.1)
                
                # 1. Download image from Supabase
                image_data = supabase_job_service.supabase.storage.from_("wardrobe").download(source_path)
                supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.3)
                
                # 2. Analyze
                outfit_json = analyze_outfit(image_data, "image/jpeg")
                garments_found = outfit_json.get("items", [])
                
                if not garments_found:
                    supabase_job_service.update_job_item_status(
                        item_id, "failed", error_message="No garments found in image."
                    )
                    failed_count += 1
                    continue
                    
                supabase_job_service.update_job_item_status(item_id, "generating", progress=0.5)
                
                # 3. Process each found garment
                # (For batch mode, we extract all found garments from the single source image)
                for garment_item in garments_found:
                    img_bytes, generated_id = await asyncio.to_thread(
                        generate_garment_image, image_data, "image/jpeg", garment_item
                    )
                    
                    transparent_bytes, bg_status = await asyncio.to_thread(
                        remove_background, img_bytes
                    )
                    
                    # 4. Upload garment to Supabase
                    garment_uuid = str(uuid.uuid4())
                    studio_image_path = f"{user_id}/garments/{garment_uuid}.png"
                    
                    supabase_job_service.supabase.storage.from_("wardrobe").upload(
                        path=studio_image_path,
                        file=transparent_bytes,
                        file_options={"content-type": "image/png"}
                    )
                    
                    # 5. Insert into Database
                    db_row = {
                        'id': garment_uuid,
                        'user_id': user_id,
                        'name': garment_item.get("name", "Generated Garment"),
                        'category': garment_item.get("category", "Unknown"),
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern"),
                        'style': garment_item.get("style"),
                        'fit': garment_item.get("fit"),
                        'studio_image_path': studio_image_path,
                        'source_image_path': source_path,
                    }
                    supabase_job_service.supabase.table("garments").insert(db_row).execute()
                    
                supabase_job_service.update_job_item_status(item_id, "completed", progress=1.0)
                completed_count += 1
                
            except Exception as e:
                print(f"Error processing item {item_id}: {e}")
                supabase_job_service.update_job_item_status(item_id, "failed", error_message=str(e))
                failed_count += 1

        # Finalize Job Status
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


@app.post("/process-job/{job_id}")
async def process_job(job_id: str, background_tasks: BackgroundTasks):
    """
    Trigger the backend to start processing an asynchronous job.
    Returns immediately to avoid blocking the client UI.
    """
    background_tasks.add_task(process_job_background, job_id)
    return {"status": "accepted", "job_id": job_id, "message": "Job is processing in the background."}

