-- ==============================================================================
-- Migration: Friendships Foundation
-- ==============================================================================

-- 1. Create the `friendships` table
CREATE TABLE public.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_b_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'declined', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT friendships_users_not_equal CHECK (user_a_id != user_b_id)
);

-- 2. Prevent duplicate relationships (symmetric uniqueness)
-- A unique index on the LEAST and GREATEST of the two user IDs ensures 
-- that we cannot have both A->B and B->A, nor duplicate A->B.
CREATE UNIQUE INDEX friendships_unique_users_idx ON public.friendships (
    LEAST(user_a_id, user_b_id),
    GREATEST(user_a_id, user_b_id)
);

-- 3. Enable RLS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies

-- Users can only view friendships where they are one of the participants
CREATE POLICY "Users can view their friendships" 
ON public.friendships FOR SELECT 
TO authenticated 
USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);

-- Users can only create friendships where they are the requester (user_a_id)
CREATE POLICY "Users can create friendships as requester" 
ON public.friendships FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_a_id);

-- Users can only update their own friendships
CREATE POLICY "Users can update their friendships" 
ON public.friendships FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_a_id OR auth.uid() = user_b_id)
WITH CHECK (auth.uid() = user_a_id OR auth.uid() = user_b_id);

-- Users can only delete their own friendships
CREATE POLICY "Users can delete their friendships" 
ON public.friendships FOR DELETE 
TO authenticated 
USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
