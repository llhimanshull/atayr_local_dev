-- 05_automatic_wardrobe_sharing.sql
-- Migration to support automatic full wardrobe sharing for accepted friends

-- 1. Update Garments SELECT policy to ignore `is_shared_with_friends`
DROP POLICY IF EXISTS "Users can view own and friends shared garments" ON public.garments;
DROP POLICY IF EXISTS "Users can view their own and shared friends garments" ON public.garments;

CREATE POLICY "Users can view own and friends garments"
ON public.garments FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR
    public.is_accepted_friend(auth.uid(), user_id)
);

-- 2. Add Storage Policy to allow friends to view generated garments (but not source photos)
DROP POLICY IF EXISTS "Users can view friends generated wardrobe files" ON storage.objects;

CREATE POLICY "Users can view friends generated wardrobe files"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'wardrobe' 
    AND (storage.foldername(name))[2] = 'garments'
    AND public.is_accepted_friend(auth.uid(), (storage.foldername(name))[1]::uuid)
);
