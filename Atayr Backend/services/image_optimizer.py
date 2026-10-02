import io
from PIL import Image

def generate_image_variants(image_bytes: bytes) -> tuple[bytes, bytes]:
    """
    Takes original transparent PNG bytes.
    Returns (thumbnail_bytes_webp, medium_bytes_webp).
    Thumbnail: ~400px
    Medium: ~800px
    """
    img = Image.open(io.BytesIO(image_bytes))
    
    # Generate Thumbnail
    thumb = img.copy()
    thumb.thumbnail((400, 400), Image.Resampling.LANCZOS)
    thumb_io = io.BytesIO()
    thumb.save(thumb_io, format="WEBP", quality=85)
    
    # Generate Medium
    med = img.copy()
    med.thumbnail((800, 800), Image.Resampling.LANCZOS)
    med_io = io.BytesIO()
    med.save(med_io, format="WEBP", quality=85)
    
    return thumb_io.getvalue(), med_io.getvalue()
