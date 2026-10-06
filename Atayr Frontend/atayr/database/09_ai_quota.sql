-- 09_ai_quota.sql
-- Migration to support atomic AI suggestion quotas

CREATE TABLE public.ai_suggestion_usage (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    successful_count INT NOT NULL DEFAULT 0,
    reserved_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, usage_date)
);

-- Enable RLS (though mostly manipulated via RPCs and backend service role)
ALTER TABLE public.ai_suggestion_usage ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own usage
CREATE POLICY "Users can view their own AI usage"
ON public.ai_suggestion_usage FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Atomic reservation RPC
CREATE OR REPLACE FUNCTION reserve_ai_suggestion(p_user_id UUID, p_date DATE)
RETURNS BOOLEAN AS $$
DECLARE
    v_successful INT;
    v_reserved INT;
BEGIN
    -- Use advisory lock to serialize requests per user
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text || 'ai_suggestion'));
    
    -- Ensure record exists
    INSERT INTO public.ai_suggestion_usage (user_id, usage_date, successful_count, reserved_count)
    VALUES (p_user_id, p_date, 0, 0)
    ON CONFLICT (user_id, usage_date) DO NOTHING;
    
    -- Read current state
    SELECT successful_count, reserved_count INTO v_successful, v_reserved
    FROM public.ai_suggestion_usage
    WHERE user_id = p_user_id AND usage_date = p_date;
    
    IF v_successful + v_reserved < 2 THEN
        UPDATE public.ai_suggestion_usage
        SET reserved_count = reserved_count + 1,
            updated_at = NOW()
        WHERE user_id = p_user_id AND usage_date = p_date;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Finalize/release RPC
CREATE OR REPLACE FUNCTION finalize_ai_suggestion(p_user_id UUID, p_date DATE, p_success BOOLEAN)
RETURNS VOID AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text || 'ai_suggestion'));
    
    IF p_success THEN
        UPDATE public.ai_suggestion_usage
        SET successful_count = successful_count + 1,
            reserved_count = GREATEST(0, reserved_count - 1),
            updated_at = NOW()
        WHERE user_id = p_user_id AND usage_date = p_date;
    ELSE
        UPDATE public.ai_suggestion_usage
        SET reserved_count = GREATEST(0, reserved_count - 1),
            updated_at = NOW()
        WHERE user_id = p_user_id AND usage_date = p_date;
    END IF;
END;
$$ LANGUAGE plpgsql;
