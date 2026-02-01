-- Function to process sponsorship payment (Platform Fee)
CREATE OR REPLACE FUNCTION public.pay_sponsorship(
    p_user_id UUID,
    p_spot_id UUID,
    p_amount DECIMAL,
    p_description TEXT,
    p_auto_renew BOOLEAN DEFAULT false -- Added auto_renew preference
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs as admin to update wallet and spot
AS $$
DECLARE
    v_balance DECIMAL;
BEGIN
    -- 1. Check Balance
    SELECT wallet_balance INTO v_balance
    FROM public.profiles
    WHERE user_id = p_user_id;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds in wallet. Please top up.';
    END IF;

    -- 2. Deduct Balance
    UPDATE public.profiles
    SET wallet_balance = wallet_balance - p_amount
    WHERE user_id = p_user_id;

    -- 3. Log Transaction (Platform Revenue from User)
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (p_user_id, -p_amount, 'sponsorship_fee', p_description);

    -- 4. Log Platform Revenue (System Ledger)
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (NULL, p_amount, 'platform_revenue', 'Sponsorship fee from user ' || p_user_id || ' for spot ' || p_spot_id);

    -- 5. Update Study Spot (Activate Sponsorship)
    UPDATE public.study_spots
    SET 
        is_sponsored = true,
        sponsorship_expiry = NOW() + INTERVAL '30 days',
        auto_renew = p_auto_renew
    WHERE id = p_spot_id; 

    RETURN jsonb_build_object('success', true, 'new_balance', v_balance - p_amount);
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
