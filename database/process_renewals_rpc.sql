-- Function to process daily sponsorship renewals
CREATE OR REPLACE FUNCTION public.process_sponsorship_renewals()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
    v_sponsorship_cost DECIMAL := 20.00;
    v_balance DECIMAL;
BEGIN
    -- Loop through spots expiring in the next 24 hours that have auto_renew enabled
    FOR r IN 
        SELECT s.id, s.owner_id, s.name, p.wallet_balance
        FROM public.study_spots s
        JOIN public.profiles p ON s.owner_id = p.user_id
        WHERE s.is_sponsored = true 
          AND s.auto_renew = true
          AND s.sponsorship_expiry <= (NOW() + INTERVAL '1 day')
          -- Avoid renewing if already renewed effectively (e.g. expiry is far future)
          -- Actually the logic above 'expiry <= 1 day' is safe enough if strict
    LOOP
        -- Check funds
        IF r.wallet_balance >= v_sponsorship_cost THEN
            -- Deduct from Wallet
            UPDATE public.profiles
            SET wallet_balance = wallet_balance - v_sponsorship_cost
            WHERE user_id = r.owner_id;

            -- Log Transactions
            INSERT INTO public.transactions (user_id, amount, type, description)
            VALUES (r.owner_id, -v_sponsorship_cost, 'sponsorship_renewal', 'Auto-renewal for ' || r.name);
            
            INSERT INTO public.transactions (user_id, amount, type, description)
            VALUES (NULL, v_sponsorship_cost, 'platform_revenue', 'Auto-renewal for spot ' || r.id);

            -- Extend Sponsorship
            UPDATE public.study_spots
            SET sponsorship_expiry = sponsorship_expiry + INTERVAL '30 days'
            WHERE id = r.id;
            
            RAISE NOTICE 'Renewed sponsorship for spot %', r.id;
        ELSE
            -- Insufficient funds: 
            -- Option A: Do nothing, let it expire.
            -- Option B: Disable auto_renew so we don't keep trying? 
            -- For now, let's disable auto_renew and Log a "Failed Renewal" note if possible?
            -- We'll just let it expire naturally.
            RAISE NOTICE 'Insufficient funds for spot %, owner %', r.id, r.owner_id;
        END IF;
    END LOOP;
END;
$$;
