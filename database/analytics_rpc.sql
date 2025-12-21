-- RPC to get aggregated platform statistics for the Admin Dashboard
CREATE OR REPLACE FUNCTION public.get_platform_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
    user_growth JSONB;
    appointment_activity JSONB;
    total_users INT;
    total_appointments INT;
    total_revenue DECIMAL;
BEGIN
    -- 1. Get Basic Totals
    SELECT COUNT(*) INTO total_users FROM public.profiles;
    SELECT COUNT(*) INTO total_appointments FROM public.appointments;
    SELECT COALESCE(SUM(amount), 0) INTO total_revenue FROM public.transactions WHERE status = 'completed';

    -- 2. Get User Growth (Last 7 Days)
    SELECT json_agg(t) INTO user_growth
    FROM (
        SELECT 
            d::date as day,
            COUNT(p.user_id) as count
        FROM generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day') d
        LEFT JOIN public.profiles p ON p.created_at::date <= d::date
        GROUP BY d.day
        ORDER BY d.day
    ) t;

    -- 3. Get Appointment Activity (Last 7 Days)
    SELECT json_agg(t) INTO appointment_activity
    FROM (
        SELECT 
            d::date as day,
            COUNT(a.id) as count
        FROM generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day') d
        LEFT JOIN public.appointments a ON a.created_at::date = d::date
        GROUP BY d.day
        ORDER BY d.day
    ) t;

    -- 4. Combine into single JSON object
    result := jsonb_build_object(
        'total_users', total_users,
        'total_appointments', total_appointments,
        'total_revenue', total_revenue,
        'user_growth', user_growth,
        'appointment_activity', appointment_activity
    );

    RETURN result;
END;
$$;

-- Grant access to authenticated users (RLS on profiles will still apply if called from client, but SECURITY DEFINER handles it)
GRANT EXECUTE ON FUNCTION public.get_platform_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_platform_stats() TO service_role;
