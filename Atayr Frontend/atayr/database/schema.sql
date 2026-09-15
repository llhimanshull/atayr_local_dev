-- ==============================================================================
-- Atayr Supabase Schema
-- ==============================================================================

-- 1. Create the `garments` table
CREATE TABLE public.garments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    subcategory TEXT,
    primary_color TEXT,
    secondary_color TEXT,
    pattern TEXT,
    style TEXT,
    fit TEXT,
    studio_image_path TEXT NOT NULL,
    source_image_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE public.garments ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for `garments`
-- Users can only select their own garments
CREATE POLICY "Users can view their own garments" 
ON public.garments FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

-- Users can only insert their own garments
CREATE POLICY "Users can insert their own garments" 
ON public.garments FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Users can only update their own garments
CREATE POLICY "Users can update their own garments" 
ON public.garments FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own garments
CREATE POLICY "Users can delete their own garments" 
ON public.garments FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- ==============================================================================
-- Storage: `wardrobe` bucket
-- ==============================================================================

-- 1. Create the `wardrobe` bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('wardrobe', 'wardrobe', false);

-- 2. Enable RLS on storage objects
-- (Usually enabled by default on storage.objects, but ensuring policies are strict)

-- Users can view their own files
CREATE POLICY "Users can view their own wardrobe files" 
ON storage.objects FOR SELECT 
TO authenticated 
USING (bucket_id = 'wardrobe' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Users can insert their own files
CREATE POLICY "Users can upload their own wardrobe files" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'wardrobe' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Users can update their own files
CREATE POLICY "Users can update their own wardrobe files" 
ON storage.objects FOR UPDATE 
TO authenticated 
USING (bucket_id = 'wardrobe' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'wardrobe' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Users can delete their own files
CREATE POLICY "Users can delete their own wardrobe files" 
ON storage.objects FOR DELETE 
TO authenticated 
USING (bucket_id = 'wardrobe' AND (storage.foldername(name))[1] = auth.uid()::text);
