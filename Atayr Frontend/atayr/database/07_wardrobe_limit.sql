-- 07_wardrobe_limit.sql
-- Atomic insertion RPC to enforce a 30-garment limit per user safely.

CREATE OR REPLACE FUNCTION public.insert_garment_if_under_limit(
    garment_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_count INT;
    user_id_val UUID;
BEGIN
    user_id_val := (garment_data->>'user_id')::uuid;
    
    -- Use a transaction-level advisory lock to serialize insertions for this specific user
    -- We hash the user_id text to generate a 32-bit lock ID
    PERFORM pg_advisory_xact_lock(hashtext(user_id_val::text));
    
    -- Check current wardrobe count
    SELECT COUNT(*) INTO current_count FROM public.garments WHERE user_id = user_id_val;
    
    IF current_count >= 30 THEN
        RETURN jsonb_build_object('success', false, 'error', 'WARDROBE_LIMIT_REACHED', 'count', current_count);
    END IF;
    
    -- Insert the new garment
    INSERT INTO public.garments (
        id, user_id, name, category, subcategory, primary_color, secondary_color, pattern, style, fit, studio_image_path, source_image_path, embedding
    ) VALUES (
        (garment_data->>'id')::uuid,
        user_id_val,
        garment_data->>'name',
        garment_data->>'category',
        garment_data->>'subcategory',
        garment_data->>'primary_color',
        garment_data->>'secondary_color',
        garment_data->>'pattern',
        garment_data->>'style',
        garment_data->>'fit',
        garment_data->>'studio_image_path',
        garment_data->>'source_image_path',
        -- Convert JSON array to text, then cast to vector
        (garment_data->>'embedding')::vector
    );
    
    RETURN jsonb_build_object('success', true);
END;
$$;
