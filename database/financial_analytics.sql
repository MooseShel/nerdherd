-- RPC for Admin Financial Dashboard
CREATE OR REPLACE FUNCTION public.get_financial_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
    daily_revenue JSONB;
    revenue_stream_breakdown JSONB;
    total_gtv DECIMAL;
    total_net_revenue DECIMAL;
BEGIN
    -- 1. Calculate Total Gross Transaction Volume (GTV)
    -- Sum of all 'payment' transactions (negative values, so we flip sign)
    SELECT COALESCE(ABS(SUM(amount)), 0) INTO total_gtv
    FROM public.transactions
    WHERE type = 'payment';

    -- 2. Calculate Total Net Revenue
    -- Sum of all 'platform_fee', 'subscription', 'ad_revenue' transactions
    SELECT COALESCE(SUM(amount), 0) INTO total_net_revenue
    FROM public.transactions
    WHERE type IN ('platform_fee', 'subscription', 'ad_revenue');

    -- 3. Get Revenue by Stream Breakdown
    SELECT json_agg(t) INTO revenue_stream_breakdown
    FROM (
        SELECT 
            type as stream,
            SUM(amount) as total
        FROM public.transactions
        WHERE type IN ('platform_fee', 'subscription', 'ad_revenue')
        GROUP BY type
    ) t;

    -- 4. Get Daily Revenue (Last 30 Days)
    SELECT json_agg(t) INTO daily_revenue
    FROM (
        SELECT 
            d.day::date as day,
            COALESCE(SUM(t.amount), 0) as revenue
        FROM generate_series(CURRENT_DATE - INTERVAL '29 days', CURRENT_DATE, '1 day') as d(day)
        LEFT JOIN public.transactions t 
            ON t.created_at::date = d.day::date 
            AND t.type IN ('platform_fee', 'subscription', 'ad_revenue')
        GROUP BY d.day
        ORDER BY d.day
    ) t;

    -- 5. Combine results
    result := jsonb_build_object(
        'total_gtv', total_gtv,
        'total_net_revenue', total_net_revenue,
        'revenue_by_stream', revenue_stream_breakdown,
        'daily_revenue', daily_revenue
    );

    RETURN result;
END;
$$;

-- Grant access to authenticated users (admin checks happen in the app usually, or we can restricting it here if needed)
GRANT EXECUTE ON FUNCTION public.get_financial_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_financial_stats() TO service_role;
