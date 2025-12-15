-- Function to process payment atomically and bypass RLS for the receiver's transaction
CREATE OR REPLACE FUNCTION public.process_payment(
    p_sender_id UUID,
    p_receiver_id UUID,
    p_amount DECIMAL,
    p_description TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres/admin), bypassing RLS
AS $$
DECLARE
    v_sender_balance DECIMAL;
    v_receiver_balance DECIMAL;
BEGIN
    -- 1. Check Sender Balance
    SELECT wallet_balance INTO v_sender_balance
    FROM public.profiles
    WHERE user_id = p_sender_id;

    IF v_sender_balance IS NULL THEN
        RAISE EXCEPTION 'Sender not found';
    END IF;

    IF v_sender_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds';
    END IF;

    -- 2. Deduct from Sender
    UPDATE public.profiles
    SET wallet_balance = wallet_balance - p_amount
    WHERE user_id = p_sender_id;

    -- 3. Add to Receiver
    UPDATE public.profiles
    SET wallet_balance = wallet_balance + p_amount
    WHERE user_id = p_receiver_id;

    -- 4. Log Transaction for Sender
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (p_sender_id, -p_amount, 'payment', 'Paid to Tutor: ' || p_description);

    -- 5. Log Transaction for Receiver
    INSERT INTO public.transactions (user_id, amount, type, description)
    VALUES (p_receiver_id, p_amount, 'earnings', 'Received from Student: ' || p_description);

    -- Return success
    RETURN jsonb_build_object('success', true);
EXCEPTION
    WHEN OTHERS THEN
        RAISE; -- Propagate error
END;
$$;
