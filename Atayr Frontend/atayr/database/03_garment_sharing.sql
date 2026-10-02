-- ==============================================================================
-- Migration: Garment Sharing Foundation
-- ==============================================================================

-- 1. Add `is_shared_with_friends` to garments
ALTER TABLE public.garments 
ADD COLUMN is_shared_with_friends BOOLEAN NOT NULL DEFAULT false;

-- 2. Drop the old RLS policy for garments SELECT
DROP POLICY IF EXISTS "Users can view their own garments" ON public.garments;

-- 3. Create the new RLS policy
-- A user can view a garment if:
--   a) They own it (auth.uid() = user_id) OR
--   b) It is shared (is_shared_with_friends = true) AND they have an accepted friendship with the owner
CREATE POLICY "Users can view their own and shared friends garments" 
ON public.garments FOR SELECT 
TO authenticated 
USING (
    auth.uid() = user_id 
    OR 
    (
        is_shared_with_friends = true 
        AND EXISTS (
            SELECT 1 FROM public.friendships 
            WHERE status = 'accepted' 
            AND (
                (user_a_id = auth.uid() AND user_b_id = garments.user_id) 
                OR 
                (user_a_id = garments.user_id AND user_b_id = auth.uid())
            )
        )
    )
);
