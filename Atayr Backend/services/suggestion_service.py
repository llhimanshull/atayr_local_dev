import io
import json
import uuid
import asyncio
from datetime import datetime
from PIL import Image

from services.generator import generate_garment_image
from services.background_remover import remove_background
from services.supabase_job_service import SupabaseJobService

def _composite_outfit(garments_bytes: list[bytes]) -> bytes:
    """
    Composite multiple garment images into a single outfit image.
    garments_bytes is a list of PNG image bytes.
    Returns composite image bytes.
    """
    # Simply stack them vertically for now
    images = []
    for b in garments_bytes:
        try:
            img = Image.open(io.BytesIO(b)).convert("RGBA")
            images.append(img)
        except Exception as e:
            print(f"Failed to open image for composite: {e}")
            
    if not images:
        # Return a blank image if nothing to composite
        blank = Image.new("RGBA", (500, 500), (255, 255, 255, 255))
        out = io.BytesIO()
        blank.save(out, format="PNG")
        return out.getvalue()
        
    import math
    num_images = len(images)
    cols = 2 if num_images > 1 else 1
    rows = math.ceil(num_images / cols)
    
    # Target size for each cell
    cell_size = 800
    
    # Create canvas
    canvas = Image.new("RGBA", (cols * cell_size, rows * cell_size), (255, 255, 255, 255))
    
    for idx, img in enumerate(images):
        # Resize image to fit within cell, maintaining aspect ratio
        img.thumbnail((cell_size, cell_size), Image.Resampling.LANCZOS)
        
        # Calculate position to center image in cell
        row = idx // cols
        col = idx % cols
        
        paste_x = col * cell_size + (cell_size - img.width) // 2
        paste_y = row * cell_size + (cell_size - img.height) // 2
        
        canvas.paste(img, (paste_x, paste_y), mask=img)
        
    out = io.BytesIO()
    canvas.save(out, format="PNG")
    return out.getvalue()

import hashlib
from services.cache_service import CacheService

async def generate_suggestion(user_id: str, image_bytes: bytes, mime_type: str, item: dict):
    job_service = SupabaseJobService()
    
    # 1. Get user's existing wardrobe
    res = job_service.supabase.table("garments").select("*").eq("user_id", user_id).execute()
    wardrobe = res.data if res.data else []
    
    # Calculate stable wardrobe hash (acting as wardrobe_version)
    wardrobe_ids_str = ",".join(sorted(g['id'] for g in wardrobe))
    wardrobe_hash = hashlib.md5(wardrobe_ids_str.encode()).hexdigest()
    
    # Calculate stable item hash
    item_hash = hashlib.md5(json.dumps(item, sort_keys=True).encode()).hexdigest()
    
    cache_key = f"suggestion:{user_id}:{item_hash}:{wardrobe_hash}"
    cached_result = CacheService.get(cache_key)
    if cached_result:
        return cached_result
    
    # Generate standalone image of the store garment (Expensive API call)
    img_bytes, generated_id = await asyncio.to_thread(
        generate_garment_image, image_bytes, mime_type, item
    )
    transparent_bytes, bg_status = await asyncio.to_thread(
        remove_background, img_bytes
    )
    
    store_garment_id = str(uuid.uuid4())
    store_image_path = f"{user_id}/suggestions/{store_garment_id}.png"
    
    # Upload store garment PNG
    job_service.supabase.storage.from_("wardrobe").upload(
        path=store_image_path,
        file=transparent_bytes,
        file_options={"content-type": "image/png"}
    )
    
    # Upload store garment variants
    thumb_image_path = f"{user_id}/suggestions/{store_garment_id}_thumb.webp"
    medium_image_path = f"{user_id}/suggestions/{store_garment_id}_medium.webp"
    from services.image_optimizer import generate_image_variants
    thumb_bytes, med_bytes = generate_image_variants(transparent_bytes)
    
    job_service.supabase.storage.from_("wardrobe").upload(
        path=thumb_image_path, file=thumb_bytes, file_options={"content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable"}
    )
    job_service.supabase.storage.from_("wardrobe").upload(
        path=medium_image_path, file=med_bytes, file_options={"content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable"}
    )
    
    # Categorize wardrobe
    wardrobe_by_cat = {}
    for g in wardrobe:
        cat = g.get('category', '').lower()
        
    store_cat = item.get('category', '').lower()
    
    # 3. Create Outfit combinations using RecommendationEngine
    from services.recommendation_engine import OutfitRecommendationEngine
    
    engine = OutfitRecommendationEngine()
    rec_result = engine.generate_recommendations(item, wardrobe, num_recommendations=5)
    combinations = rec_result.get("combinations", [])
    missing_message = rec_result.get("missing_message", None)
    
    # If we couldn't form outfits because wardrobe is empty or incompatible, return early
    if not combinations:
        return {
            "success": False,
            "error": "Not enough compatible items in wardrobe to form an outfit.",
            "store_image_path": store_image_path
        }
        
    # 4. Composite images and upload
    final_combinations = []
    
    for combo in combinations:
        # Download images for composite
        # We need store item (transparent_bytes) + wardrobe items
        images_to_composite = []
        
        # Order: Top -> Bottom -> Footwear -> Outerwear -> Accessories
        # We'll just sort them by a fixed order
        order = {"top": 1, "upper": 1, "outerwear": 2, "bottom": 3, "bottoms": 3, "footwear": 4, "shoes": 4, "accessories": 5}
        
        all_combo_items = [{"is_store": True, "cat": store_cat, "bytes": transparent_bytes, "id": store_garment_id}]
        for w_item in combo["wardrobe_items"]:
            try:
                img_path = w_item.get("studio_image_path")
                if img_path:
                    w_bytes = job_service.supabase.storage.from_("wardrobe").download(img_path)
                    all_combo_items.append({"is_store": False, "cat": w_item.get("category", "").lower(), "bytes": w_bytes, "id": w_item["id"]})
            except Exception as e:
                print(f"Failed to download {img_path}: {e}")
                
        # Sort items
        all_combo_items.sort(key=lambda x: order.get(x["cat"], 99))
        
        composite_bytes = _composite_outfit([x["bytes"] for x in all_combo_items])
        
        combo_id = str(uuid.uuid4())
        combo_image_path = f"{user_id}/suggestions/combo_{combo_id}.png"
        
        job_service.supabase.storage.from_("wardrobe").upload(
            path=combo_image_path,
            file=composite_bytes,
            file_options={"content-type": "image/png"}
        )
        
        final_combinations.append({
            "outfit_composition_image_path": combo_image_path,
            "item_ids": [x["id"] for x in all_combo_items if not x["is_store"]],
            "wardrobe_items": [w for w in combo["wardrobe_items"]], # including metadata
            "style_direction": combo.get("style_direction", "CASUAL"),
            "explanation": combo.get("explanation", "")
        })
        
    # 5. Append to history.json
    history_path = f"{user_id}/suggestions_history.json"
    history_data = []
    try:
        existing_history_bytes = job_service.supabase.storage.from_("wardrobe").download(history_path)
        history_data = json.loads(existing_history_bytes.decode('utf-8'))
    except Exception:
        # File might not exist
        history_data = []
        
    suggestion_record = {
        "id": str(uuid.uuid4()),
        "created_at": datetime.utcnow().isoformat() + "Z",
        "store_garment_image_path": store_image_path,
        "store_garment_metadata": item,
        "combinations": final_combinations,
        "missing_message": missing_message
    }
    
    history_data.insert(0, suggestion_record) # prepend
    
    # Keep only last 50
    history_data = history_data[:50]
    
    # Upload history
    try:
        job_service.supabase.storage.from_("wardrobe").upload(
            path=history_path,
            file=json.dumps(history_data).encode('utf-8'),
            file_options={"content-type": "application/json", "upsert": "true"}
        )
    except Exception as e:
        print(f"Failed to save history: {e}")
        # if upsert fails, try update
        try:
            job_service.supabase.storage.from_("wardrobe").update(
                path=history_path,
                file=json.dumps(history_data).encode('utf-8'),
                file_options={"content-type": "application/json"}
            )
        except Exception as e2:
            print(f"Failed to update history: {e2}")

    result = {
        "success": True,
        "suggestion": suggestion_record
    }
    
    # Cache result for an hour
    CacheService.set(cache_key, result, ttl=3600)
    
    return result
