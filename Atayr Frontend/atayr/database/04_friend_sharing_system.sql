-- 04_friend_sharing_system.sql
-- Migration to support friend wardrobe sharing

-- 1. Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read any profile (needed for friend display)
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles are viewable by authenticated users"
ON public.profiles FOR SELECT
TO authenticated
USING (true);

-- Users can only insert their own profile
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Users can only update their own profile
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 2. Trigger for auto-populating profiles on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data ->> 'full_name',
            NEW.raw_user_meta_data ->> 'name',
            split_part(NEW.email, '@', 1)
        )
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Backfill existing users (Optional - requires superuser or manual run if auth.users is protected)
-- Note: It's common to run this manually in the Supabase SQL editor.
-- INSERT INTO public.profiles (id, display_name)
-- SELECT id, COALESCE(
--     raw_user_meta_data ->> 'full_name',
--     raw_user_meta_data ->> 'name',
--     split_part(email, '@', 1)
-- ) FROM auth.users
-- ON CONFLICT (id) DO NOTHING;

-- 4. Helper function for friend checking
CREATE OR REPLACE FUNCTION public.is_accepted_friend(user_1 UUID, user_2 UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.friendships
        WHERE status = 'accepted'
        AND (
            (user_a_id = user_1 AND user_b_id = user_2)
            OR
            (user_a_id = user_2 AND user_b_id = user_1)
        )
    );
$$;

-- 5. Update Garments SELECT policy
DROP POLICY IF EXISTS "Users can view their own and shared friends garments" ON public.garments;

CREATE POLICY "Users can view own and friends shared garments"
ON public.garments FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR
    (
        is_shared_with_friends = true
        AND public.is_accepted_friend(auth.uid(), user_id)
    )
);

-- 6. Change default sharing status for new garments
ALTER TABLE public.garments
ALTER COLUMN is_shared_with_friends SET DEFAULT true;

-- 7. Add indexes
CREATE INDEX IF NOT EXISTS idx_friendships_user_a_status
ON public.friendships (user_a_id, status);

CREATE INDEX IF NOT EXISTS idx_friendships_user_b_status
ON public.friendships (user_b_id, status);

CREATE INDEX IF NOT EXISTS idx_garments_user_shared
ON public.garments (user_id, is_shared_with_friends)
WHERE is_shared_with_friends = true;
