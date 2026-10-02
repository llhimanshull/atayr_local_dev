"""
Analyzer Service
Sends the reference image + analysis prompt to Gemini Flash.
Returns a structured JSON description of every garment in the image.
"""

import os
from pathlib import Path
from google import genai
from google.genai import types

from schemas import AnalysisResponse


ANALYSIS_PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "analysis_prompt.txt"


def _load_analysis_prompt() -> str:
    """Load the analysis prompt template from disk."""
    return ANALYSIS_PROMPT_PATH.read_text(encoding="utf-8")


def analyze_outfit(image_bytes: bytes, mime_type: str) -> dict:
    """
    Analyze a reference image and return a structured JSON description
    of every visible garment.

    Args:
        image_bytes: Raw bytes of the reference image.
        mime_type: MIME type of the image (e.g. "image/jpeg").

    Returns:
        A dict containing the outfit analysis (items array).
    """
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
    api_key = os.getenv("GEMINI_API_KEY")

    if project_id:
        client = genai.Client(vertexai=True, project=project_id, location=location)
    elif api_key:
        client = genai.Client(api_key=api_key)
    else:
        raise ValueError("Must set either GOOGLE_CLOUD_PROJECT or GEMINI_API_KEY in environment")

    model = os.getenv("GEMINI_ANALYSIS_MODEL", "gemini-2.5-flash")

    prompt = _load_analysis_prompt()
    
    max_retries = 3

    for attempt in range(max_retries + 1):
        print(f"  -> Sending image ({len(image_bytes)} bytes) to {model} for analysis (Attempt {attempt + 1})...")
        
        try:
            response = client.models.generate_content(
                model=model,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                    prompt,
                ],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=AnalysisResponse,
                    temperature=0.1,
                )
            )

            if not response.parsed:
                if attempt < max_retries:
                    print("  -> Empty or unparsed response, retrying...")
                    time.sleep(2)
                    continue
                raise ValueError("Gemini returned an empty or unparsed response for analysis")

            # response.parsed contains the Pydantic object
            return response.parsed.model_dump()
            
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e).upper():
                sleep_time = (attempt + 1) * 10
                print(f"  -> [Attempt {attempt + 1}] Rate limit hit (429). Sleeping for {sleep_time} seconds before retrying...")
                import time
                time.sleep(sleep_time)
                continue
                
            if attempt < max_retries:
                print(f"  -> Generation failed. Retrying... Error: {e}")
                import time
                time.sleep(2 ** attempt)
                continue
            else:
                raise ValueError(
                    f"Failed to analyze outfit after retries.\n"
                    f"Error: {e}"
                )

    raise ValueError("Failed to analyze outfit after retries.")

def embed_garment(garment_item: dict, image_bytes: bytes) -> tuple[list[float], dict]:
    """
    Generate a multimodal embedding for a garment based on its visual crop and metadata.
    Returns (embedding, log_data).
    """
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
    api_key = os.getenv("GEMINI_API_KEY")

    if project_id:
        client = genai.Client(vertexai=True, project=project_id, location=location)
    elif api_key:
        client = genai.Client(api_key=api_key)
    else:
        raise ValueError("Must set either GOOGLE_CLOUD_PROJECT or GEMINI_API_KEY")

    # 1. Crop the garment from the source image
    box = garment_item.get("bounding_box")
    crop_bytes = None
    crop_dimensions = None
    
    if box and image_bytes:
        try:
            import io
            from PIL import Image
            
            img = Image.open(io.BytesIO(image_bytes))
            width, height = img.size
            x_min = int(box.get("x_min", 0.0) * width)
            y_min = int(box.get("y_min", 0.0) * height)
            x_max = int(box.get("x_max", 1.0) * width)
            y_max = int(box.get("y_max", 1.0) * height)
            
            category = garment_item.get("category", "").lower()
            
            box_width = x_max - x_min
            box_height = y_max - y_min
            
            # 1. Raw crop
            raw_crop = img.crop((x_min, y_min, x_max, y_max))
            
            # 2. Determine square size with padding
            # 20% margin based on the largest dimension
            max_dim = max(box_width, box_height)
            padded_size = int(max_dim * 1.2)
            
            # 3. Create square canvas (white background for consistent padding)
            square_img = Image.new("RGB", (padded_size, padded_size), (255, 255, 255))
            
            # 4. Paste raw crop in the center
            paste_x = (padded_size - box_width) // 2
            paste_y = (padded_size - box_height) // 2
            
            if raw_crop.mode in ("RGBA", "P"):
                raw_crop = raw_crop.convert("RGB")
                
            square_img.paste(raw_crop, (paste_x, paste_y))
            crop = square_img
            crop_dimensions = crop.size
            
            # Diagnostic Logging
            print("\n[EMBEDDING CROP]")
            print(f"Category: {category}")
            print(f"Original bbox: x({x_min}-{x_max}) y({y_min}-{y_max})")
            print(f"Original dimensions: {box_width}x{box_height}")
            print(f"Padded square dimensions: {padded_size}x{padded_size}")
            print(f"Padding: 20% margin added")
            print(f"Aspect ratio before: {box_width / box_height:.2f}" if box_height else "Aspect ratio before: N/A")
            print(f"Aspect ratio after: 1.00\n")
            
            # Save to bytes
            out_io = io.BytesIO()
            crop.save(out_io, format="JPEG")
            crop_bytes = out_io.getvalue()
        except Exception as e:
            print(f"Warning: Failed to crop garment for embedding: {e}")

    # 2. Create a rich description of the garment's visual properties
    desc = (
        f"Category: {garment_item.get('category', 'Unknown')}\n"
        f"Subcategory: {garment_item.get('subcategory', 'Unknown')}\n"
        f"Primary Color: {garment_item.get('primary_color', 'Unknown')}\n"
        f"Secondary Color: {garment_item.get('secondary_color', 'None')}\n"
        f"Pattern: {garment_item.get('pattern', 'Unknown')}\n"
        f"Style: {garment_item.get('style', 'Unknown')}\n"
        f"Fit: {garment_item.get('fit', 'Unknown')}"
    )

    contents = []
    if crop_bytes:
        contents.append(types.Part.from_bytes(data=crop_bytes, mime_type="image/jpeg"))
    contents.append(desc)

    log_data = {
        "crop_dimensions": crop_dimensions if box and image_bytes else None,
        "embedding_success": False,
        "fallback_used": False,
        "embedding_source_type": None,
    }

    try:
        # Try text-embedding-004 first
        response = client.models.embed_content(
            model='text-embedding-004',
            contents=contents
        )
        log_data["embedding_success"] = True
        embedding_list = [float(x) for x in response.embeddings[0].values]
        return embedding_list, log_data
    except Exception as e:
        print(f"Warning: text-embedding-004 failed with multimodal input: {e}")
        # Fallback to text-only if multimodal fails on this API key/project
        try:
            response = client.models.embed_content(
                model='text-embedding-004',
                contents=[desc]
            )
            log_data['embedding_success'] = True
            log_data['fallback_used'] = True
            log_data['embedding_source_type'] = 'text-only metadata'
            embedding_list = [float(x) for x in response.embeddings[0].values]
            return embedding_list, log_data
        except Exception as fallback_e:
            print(f'Failed to generate embedding (fallback): {fallback_e}')
            return None, log_data
