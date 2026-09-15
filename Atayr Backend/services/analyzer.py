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
    
    max_retries = 1

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
                    continue
                raise ValueError("Gemini returned an empty or unparsed response for analysis")

            # response.parsed contains the Pydantic object
            return response.parsed.model_dump()
            
        except Exception as e:
            if attempt < max_retries:
                print(f"  -> Generation failed. Retrying... Error: {e}")
                continue
            else:
                raise ValueError(
                    f"Failed to analyze outfit after retries.\n"
                    f"Error: {e}"
                )

    raise ValueError("Failed to analyze outfit after retries.")
