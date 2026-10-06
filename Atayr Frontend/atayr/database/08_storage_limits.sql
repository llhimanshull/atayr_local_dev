-- 08_storage_limits.sql
-- Migration to enforce file size and mime type limits at the storage bucket level

-- We use 20971520 (20MB) to match the FastAPI limit.
-- Allowed mime types include image formats and application/json (for suggestions_history.json)
UPDATE storage.buckets 
SET file_size_limit = 20971520,
    allowed_mime_types = ARRAY[
        'image/jpeg', 
        'image/png', 
        'image/webp', 
        'image/heic', 
        'image/heif',
        'application/json'
    ]
WHERE id = 'wardrobe';
