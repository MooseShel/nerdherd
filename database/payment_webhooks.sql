-- Function to handle successful top-ups from Stripe Webhooks
-- This is called by the stripe-payment Edge Function using the Service Role Key
CREATE OR REPLACE FUNCTION public.handle_successful_payment(
    p_user_id UUID,
    p_amount DECIMAL,
    p_stripe_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with admin privileges to update wallet
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- 1. Idempotency Check: Ensure we don't process the same Stripe ID twice
    SELECT COUNT(*) INTO v_count
    FROM public.transactions
    WHERE description LIKE '%' || p_stripe_id || '%';

    IF v_count > 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'Payment already processed');
    END IF;

    -- 2. Update Wallet Balance
    UPDATE public.profiles
    SET wallet_balance = wallet_balance + p_amount
    WHERE user_id = p_user_id;

    -- 3. Log Transaction
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (p_user_id, p_amount, 'deposit', 'Stripe Top-up (ID: ' || p_stripe_id || ')');

    RETURN jsonb_build_object('success', true);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in handle_successful_payment: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
