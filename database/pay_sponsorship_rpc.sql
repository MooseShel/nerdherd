-- Function to process sponsorship payment (Platform Fee)
CREATE OR REPLACE FUNCTION public.pay_sponsorship(
    p_user_id UUID,
    p_amount DECIMAL,
    p_description TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs as admin to update wallet
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
        RAISE EXCEPTION 'Insufficient funds';
    END IF;

    -- 2. Deduct Balance
    UPDATE public.profiles
    SET wallet_balance = wallet_balance - p_amount
    WHERE user_id = p_user_id;

    -- 3. Log Transaction (Platform Revenue)
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (p_user_id, -p_amount, 'sponsorship_fee', p_description);

    -- 4. Log Platform Revenue (System Ledger - No User ID)
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (NULL, p_amount, 'platform_revenue', 'Sponsorship fee from user ' || p_user_id);

    RETURN jsonb_build_object('success', true, 'new_balance', v_balance - p_amount);
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
