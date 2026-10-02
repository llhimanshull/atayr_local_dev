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
    embedding vector(768),
    is_shared_with_friends BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create HNSW index for duplicate matching
CREATE INDEX ON public.garments USING hnsw (embedding vector_cosine_ops);

-- 2. Enable Row Level Security
ALTER TABLE public.garments ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for `garments`
-- Users can view their own and shared friends garments
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

-- Add observation table schema to match actual DB
CREATE TABLE public.garment_observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    garment_id UUID REFERENCES public.garments(id) ON DELETE CASCADE,
    source_image_path TEXT,
    embedding vector(768),
    detected_attributes JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create HNSW index for duplicate matching
CREATE INDEX ON public.garment_observations USING hnsw (embedding vector_cosine_ops);

-- ==============================================================================
-- Friendships
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

-- ==============================================================================
-- Friend Invites & Server-Side Authorization
-- ==============================================================================

-- 1. Create the `friend_invites` table
CREATE TABLE public.friend_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invite_code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + interval '7 days'
);

-- 2. Enable RLS on `friend_invites`
ALTER TABLE public.friend_invites ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for `friend_invites`
CREATE POLICY "Users can view their own invites" 
ON public.friend_invites FOR SELECT 
TO authenticated 
USING (auth.uid() = inviter_id);

CREATE POLICY "Users can create their own invites" 
ON public.friend_invites FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = inviter_id);

-- 4. RPC: use_invite_code
CREATE OR REPLACE FUNCTION public.use_invite_code(code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invite_row RECORD;
BEGIN
    SELECT * INTO invite_row FROM public.friend_invites 
    WHERE invite_code = code AND expires_at > now();
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invite code';
    END IF;

    IF invite_row.inviter_id = auth.uid() THEN
        RAISE EXCEPTION 'You cannot use your own invite code';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.friendships 
        WHERE (user_a_id = auth.uid() AND user_b_id = invite_row.inviter_id)
           OR (user_a_id = invite_row.inviter_id AND user_b_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Friendship or pending request already exists';
    END IF;

    INSERT INTO public.friendships (user_a_id, user_b_id, status)
    VALUES (auth.uid(), invite_row.inviter_id, 'pending');

    RETURN json_build_object('success', true, 'message', 'Friend request sent');
END;
$$;

-- 5. RPC: accept_friend_request
CREATE OR REPLACE FUNCTION public.accept_friend_request(request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    req_row RECORD;
BEGIN
    SELECT * INTO req_row FROM public.friendships WHERE id = request_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Friend request not found';
    END IF;

    IF req_row.user_b_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized to accept this request';
    END IF;

    IF req_row.status != 'pending' THEN
        RAISE EXCEPTION 'Request is not pending';
    END IF;

    UPDATE public.friendships 
    SET status = 'accepted', updated_at = NOW()
    WHERE id = request_id;

    RETURN json_build_object('success', true, 'message', 'Friend request accepted');
END;
$$;

-- 6. RPC: decline_friend_request
CREATE OR REPLACE FUNCTION public.decline_friend_request(request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    req_row RECORD;
BEGIN
    SELECT * INTO req_row FROM public.friendships WHERE id = request_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Friend request not found';
    END IF;

    IF req_row.user_b_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized to decline this request';
    END IF;

    UPDATE public.friendships 
    SET status = 'declined', updated_at = NOW()
    WHERE id = request_id;

    RETURN json_build_object('success', true, 'message', 'Friend request declined');
END;
$$;
