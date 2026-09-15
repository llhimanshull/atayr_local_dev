"""
Generator Service
Takes the full outfit JSON, fills the generation prompt template,
sends it to Vertex AI for image generation, validates the image, and saves it.
"""

import os
import io
import json
import uuid
import base64
import time
from datetime import datetime
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image, ImageChops


GENERATION_PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "generation_prompt.txt"


def _load_generation_prompt() -> str:
    """Load the generation prompt template from disk."""
    return GENERATION_PROMPT_PATH.read_text(encoding="utf-8")


def _build_prompt(outfit_json: dict) -> str:
    """
    Plug the full outfit JSON into the generation prompt template.
    """
    template = _load_generation_prompt()
    json_str = json.dumps(outfit_json, indent=2)
    template = template.replace("[PASTE_EXTRACTED_GARMENT_JSON_HERE]", json_str)
    return template


def _check_edge_touch(img: Image.Image, threshold_pixels: int = 5) -> bool:
    """
    Returns True if non-white content touches the edges of the canvas.
    """
    img_gray = img.convert("L")
    bg = Image.new("L", img_gray.size, 255)
    diff = ImageChops.difference(img_gray, bg)
    # Threshold out very light gray compression artifacts
    diff = diff.point(lambda p: 255 if p > 15 else 0)
    bbox = diff.getbbox()
    
    if not bbox:
        return False  # entirely white canvas
    
    left, top, right, bottom = bbox
    width, height = img.size
    
    if left < threshold_pixels or top < threshold_pixels:
        return True
    if right > width - threshold_pixels or bottom > height - threshold_pixels:
        return True
        
    return False


def generate_garment_image(
    original_image: bytes,
    mime_type: str,
    garment_metadata: dict,
    max_retries: int = 3
) -> tuple[str, str]:
    """
    Generate a single standalone product image for a specific garment.
    Includes validation to retry if garment touches the edge of the canvas.

    Args:
        original_image: Raw bytes of the reference image.
        mime_type: MIME type of the reference image.
        garment_metadata: The structured JSON for a single garment item.

    Returns:
        A tuple containing (raw PNG bytes of the generated image, garment ID).
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

    model = os.getenv("GEMINI_GENERATION_MODEL", "gemini-2.5-flash-image")
    
    prompt = _build_prompt(garment_metadata)
    garment_id = garment_metadata.get("id", "unknown_id")

    for attempt in range(1, max_retries + 1):
        print(f"  -> Generating standalone image for garment {garment_id} via {model} (Attempt {attempt})...")

        try:
            response = client.models.generate_content(
                model=model,
                contents=[
                    types.Part.from_bytes(data=original_image, mime_type=mime_type),
                    prompt,
                ],
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                ),
            )
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e).upper():
                sleep_time = attempt * 10
                print(f"  -> [Attempt {attempt}] Rate limit hit (429). Sleeping for {sleep_time} seconds before retrying...")
                time.sleep(sleep_time)
                continue
            
            if attempt == max_retries:
                raise
            print(f"  -> [Attempt {attempt}] API Error: {e}. Retrying...")
            time.sleep(2)
            continue

        if not response.candidates:
            if attempt == max_retries:
                raise ValueError("No candidates returned from Gemini.")
            continue

        # In gemini-2.5-flash-image, the image might be in inline_data
        for part in response.candidates[0].content.parts:
            if part.inline_data is not None and part.inline_data.mime_type.startswith("image/"):
                img = Image.open(io.BytesIO(part.inline_data.data))
                
                # Validation Hook: Edge-Touch Check
                if _check_edge_touch(img):
                    print(f"  -> Validation Failed: Image content touches the edge (Attempt {attempt}).")
                    break  # Break inner loop, trigger outer loop retry
                
                buffered = io.BytesIO()
                img.save(buffered, format="PNG")
                img_bytes = buffered.getvalue()
                
                print(f"  -> Successfully generated image for garment {garment_id}")
                return img_bytes, garment_id

    raise ValueError(f"Failed to generate a valid image for garment {garment_id} after {max_retries} attempts due to margin violations.")
