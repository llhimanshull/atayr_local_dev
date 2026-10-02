-- ==============================================================================
-- Migration: Friend Invites & Server-Side Authorization
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

-- Note: We do NOT allow UPDATE or DELETE. 
-- Old invites can naturally expire.

-- 4. RPC: use_invite_code
-- This runs as SECURITY DEFINER so it bypasses RLS and can read the invite code
-- and securely insert the friendship request without exposing all invite codes to everyone.
CREATE OR REPLACE FUNCTION public.use_invite_code(code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invite_row RECORD;
BEGIN
    -- Validate code exists and hasn't expired
    SELECT * INTO invite_row FROM public.friend_invites 
    WHERE invite_code = code AND expires_at > now();
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invite code';
    END IF;

    -- Check if trying to add oneself
    IF invite_row.inviter_id = auth.uid() THEN
        RAISE EXCEPTION 'You cannot use your own invite code';
    END IF;

    -- Check if friendship or pending request already exists
    IF EXISTS (
        SELECT 1 FROM public.friendships 
        WHERE (user_a_id = auth.uid() AND user_b_id = invite_row.inviter_id)
           OR (user_a_id = invite_row.inviter_id AND user_b_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Friendship or pending request already exists';
    END IF;

    -- Insert the pending friendship request (auth.uid() is the requester)
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

    -- Ensure the current user is the recipient (user_b_id)
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

    -- Ensure the current user is the recipient (user_b_id)
    IF req_row.user_b_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized to decline this request';
    END IF;

    UPDATE public.friendships 
    SET status = 'declined', updated_at = NOW()
    WHERE id = request_id;

    RETURN json_build_object('success', true, 'message', 'Friend request declined');
END;
$$;
