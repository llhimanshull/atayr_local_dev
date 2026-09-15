import traceback
from rembg import remove, new_session

# Initialize the model session once globally
# Using 'u2net' which is highly accurate and preserves edges well.
_session = None

def _get_session():
    global _session
    if _session is None:
        _session = new_session("u2net")
    return _session

def remove_background(image_bytes: bytes) -> tuple[bytes, str]:
    """
    Removes the background from the given image bytes using rembg.
    Returns a tuple of (output_bytes, status_string).
    If it fails, returns the original image_bytes and "failed".
    """
    try:
        session = _get_session()
        # rembg remove can take bytes and return bytes
        output_bytes = remove(image_bytes, session=session)
        return output_bytes, "success"
    except Exception as e:
        print(f"Background removal failed: {str(e)}")
        traceback.print_exc()
        return image_bytes, "failed"
