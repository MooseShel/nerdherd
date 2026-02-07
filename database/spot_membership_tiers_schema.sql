-- ============================================================
-- STUDY SPOT MEMBERSHIP TIERS SCHEMA
-- Extends existing study_spots and profiles tables to support
-- tiered memberships for study spot owners.
-- ============================================================

-- 1. Create Membership Tier Enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'spot_membership_tier') THEN
        CREATE TYPE spot_membership_tier AS ENUM ('free', 'verified', 'boosted', 'premium');
    END IF;
END $$;

-- 2. Create Spot Memberships Table (Subscription Management)
CREATE TABLE IF NOT EXISTS public.spot_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    tier spot_membership_tier DEFAULT 'free',
    
    -- Pricing & Billing
    monthly_price DECIMAL(10,2) DEFAULT 0,
    stripe_subscription_id TEXT, -- Stripe subscription reference
    stripe_customer_id TEXT,     -- Stripe customer ID for owner
    
    -- Subscription Status
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled', 'past_due')),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    current_period_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    current_period_end TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    auto_renew BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(spot_id) -- One membership per spot
);

-- 3. Create Spot Analytics Table (Tracking Impressions & Engagement)
CREATE TABLE IF NOT EXISTS public.spot_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Impressions & Engagement
    map_views INTEGER DEFAULT 0,           -- Times spot appeared on map
    detail_views INTEGER DEFAULT 0,        -- Times spot detail was opened
    directions_tapped INTEGER DEFAULT 0,   -- Times user requested directions
    deal_views INTEGER DEFAULT 0,          -- Times deal was viewed
    deal_redemptions INTEGER DEFAULT 0,    -- Times deal was redeemed
    
    -- Push Notification Metrics (for Boosted+)
    notifications_sent INTEGER DEFAULT 0,
    notifications_clicked INTEGER DEFAULT 0,
    
    -- Demographics (aggregated, privacy-safe)
    unique_student_viewers INTEGER DEFAULT 0,
    top_university_id TEXT,                -- Most common university
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(spot_id, date) -- One row per spot per day
);

-- 4. Create Spot Deals Table (Promotions for Boosted+)
CREATE TABLE IF NOT EXISTS public.spot_deals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    
    title TEXT NOT NULL,                   -- e.g., "20% off Coffee"
    description TEXT,                      -- e.g., "Show your Nerd Herd app"
    deal_type TEXT DEFAULT 'discount' CHECK (deal_type IN ('discount', 'freebie', 'bundle', 'event')),
    
    -- Validity
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ends_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    
    -- Targeting (optional)
    target_universities TEXT[],            -- Limit to specific universities
    target_classes TEXT[],                 -- Limit to specific classes
    
    -- Redemption
    max_redemptions INTEGER,               -- NULL = unlimited
    current_redemptions INTEGER DEFAULT 0,
    redemption_code TEXT,                  -- Optional code for verification
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create Spot Events Table (for Boosted+)
CREATE TABLE IF NOT EXISTS public.spot_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    
    title TEXT NOT NULL,                   -- e.g., "Finals Week: Open 24hrs"
    description TEXT,
    event_type TEXT DEFAULT 'general' CHECK (event_type IN ('general', 'extended_hours', 'study_group', 'special')),
    
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at TIMESTAMP WITH TIME ZONE,
    
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Create Spot Reservations Table (for Premium)
CREATE TABLE IF NOT EXISTS public.spot_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    
    reservation_type TEXT DEFAULT 'table' CHECK (reservation_type IN ('table', 'room', 'booth')),
    party_size INTEGER DEFAULT 1,
    
    reserved_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER DEFAULT 120,  -- 2 hours default
    
    status TEXT DEFAULT 'confirmed' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed', 'no_show')),
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Add membership tier column to study_spots for quick access
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS membership_tier spot_membership_tier DEFAULT 'free';

-- 8. Add badge/verification columns to study_spots
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_tutor_friendly BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS accepts_reservations BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS accepts_wallet_payments BOOLEAN DEFAULT false;

-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

-- Enable RLS on new tables
ALTER TABLE public.spot_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spot_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spot_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spot_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spot_reservations ENABLE ROW LEVEL SECURITY;

-- Spot Memberships: Owners can view/update their own
CREATE POLICY "Owners can view their memberships"
ON public.spot_memberships FOR SELECT
USING (auth.uid() = owner_id);

CREATE POLICY "Owners can update their memberships"
ON public.spot_memberships FOR UPDATE
USING (auth.uid() = owner_id);

-- Spot Analytics: Owners can view their own
CREATE POLICY "Owners can view their analytics"
ON public.spot_analytics FOR SELECT
USING (
    spot_id IN (SELECT id FROM public.study_spots WHERE owner_id = auth.uid())
);

-- Spot Deals: Everyone can view active deals, owners can manage
CREATE POLICY "Everyone can view active deals"
ON public.spot_deals FOR SELECT
USING (is_active = true);

CREATE POLICY "Owners can manage their deals"
ON public.spot_deals FOR ALL
USING (
    spot_id IN (SELECT id FROM public.study_spots WHERE owner_id = auth.uid())
);

-- Spot Events: Everyone can view active events, owners can manage
CREATE POLICY "Everyone can view active events"
ON public.spot_events FOR SELECT
USING (is_active = true);

CREATE POLICY "Owners can manage their events"
ON public.spot_events FOR ALL
USING (
    spot_id IN (SELECT id FROM public.study_spots WHERE owner_id = auth.uid())
);

-- Spot Reservations: Users can view/manage their own, owners can view all for their spots
CREATE POLICY "Users can view own reservations"
ON public.spot_reservations FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can create reservations"
ON public.spot_reservations FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reservations"
ON public.spot_reservations FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Owners can view reservations for their spots"
ON public.spot_reservations FOR SELECT
USING (
    spot_id IN (SELECT id FROM public.study_spots WHERE owner_id = auth.uid())
);

CREATE POLICY "Owners can update reservations for their spots"
ON public.spot_reservations FOR UPDATE
USING (
    spot_id IN (SELECT id FROM public.study_spots WHERE owner_id = auth.uid())
);

-- ============================================================
-- RPC FUNCTIONS
-- ============================================================

-- Function to upgrade spot membership
CREATE OR REPLACE FUNCTION public.upgrade_spot_membership(
    p_spot_id UUID,
    p_new_tier spot_membership_tier,
    p_stripe_subscription_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner_id UUID;
    v_monthly_price DECIMAL;
BEGIN
    -- Verify ownership
    SELECT owner_id INTO v_owner_id FROM public.study_spots WHERE id = p_spot_id;
    IF v_owner_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to manage this spot';
    END IF;
    
    -- Set pricing based on tier
    v_monthly_price := CASE p_new_tier
        WHEN 'free' THEN 0
        WHEN 'verified' THEN 49.00
        WHEN 'boosted' THEN 99.00
        WHEN 'premium' THEN 199.00
    END;
    
    -- Upsert membership
    INSERT INTO public.spot_memberships (spot_id, owner_id, tier, monthly_price, stripe_subscription_id, current_period_end)
    VALUES (
        p_spot_id, 
        v_owner_id, 
        p_new_tier, 
        v_monthly_price, 
        p_stripe_subscription_id,
        NOW() + INTERVAL '30 days'
    )
    ON CONFLICT (spot_id) DO UPDATE SET
        tier = p_new_tier,
        monthly_price = v_monthly_price,
        stripe_subscription_id = COALESCE(p_stripe_subscription_id, spot_memberships.stripe_subscription_id),
        current_period_start = NOW(),
        current_period_end = NOW() + INTERVAL '30 days',
        updated_at = NOW();
    
    -- Update study_spots quick-access column
    UPDATE public.study_spots 
    SET membership_tier = p_new_tier
    WHERE id = p_spot_id;
    
    RETURN jsonb_build_object('success', true, 'tier', p_new_tier, 'price', v_monthly_price);
END;
$$;

-- Function to record spot analytics
CREATE OR REPLACE FUNCTION public.record_spot_view(
    p_spot_id UUID,
    p_view_type TEXT DEFAULT 'map' -- 'map', 'detail', 'directions', 'deal'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.spot_analytics (spot_id, date, map_views, detail_views, directions_tapped, deal_views)
    VALUES (
        p_spot_id,
        CURRENT_DATE,
        CASE WHEN p_view_type = 'map' THEN 1 ELSE 0 END,
        CASE WHEN p_view_type = 'detail' THEN 1 ELSE 0 END,
        CASE WHEN p_view_type = 'directions' THEN 1 ELSE 0 END,
        CASE WHEN p_view_type = 'deal' THEN 1 ELSE 0 END
    )
    ON CONFLICT (spot_id, date) DO UPDATE SET
        map_views = spot_analytics.map_views + CASE WHEN p_view_type = 'map' THEN 1 ELSE 0 END,
        detail_views = spot_analytics.detail_views + CASE WHEN p_view_type = 'detail' THEN 1 ELSE 0 END,
        directions_tapped = spot_analytics.directions_tapped + CASE WHEN p_view_type = 'directions' THEN 1 ELSE 0 END,
        deal_views = spot_analytics.deal_views + CASE WHEN p_view_type = 'deal' THEN 1 ELSE 0 END;
END;
$$;

-- Function to get spot analytics summary
CREATE OR REPLACE FUNCTION public.get_spot_analytics(
    p_spot_id UUID,
    p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner_id UUID;
    v_result JSONB;
BEGIN
    -- Verify ownership
    SELECT owner_id INTO v_owner_id FROM public.study_spots WHERE id = p_spot_id;
    IF v_owner_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to view analytics for this spot';
    END IF;
    
    SELECT jsonb_build_object(
        'total_map_views', COALESCE(SUM(map_views), 0),
        'total_detail_views', COALESCE(SUM(detail_views), 0),
        'total_directions_tapped', COALESCE(SUM(directions_tapped), 0),
        'total_deal_views', COALESCE(SUM(deal_views), 0),
        'avg_daily_views', ROUND(COALESCE(AVG(map_views + detail_views), 0)::numeric, 1),
        'period_days', p_days
    ) INTO v_result
    FROM public.spot_analytics
    WHERE spot_id = p_spot_id
    AND date >= CURRENT_DATE - (p_days || ' days')::INTERVAL;
    
    RETURN v_result;
END;
$$;

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_spot_memberships_owner ON public.spot_memberships(owner_id);
CREATE INDEX IF NOT EXISTS idx_spot_memberships_tier ON public.spot_memberships(tier);
CREATE INDEX IF NOT EXISTS idx_spot_analytics_spot_date ON public.spot_analytics(spot_id, date);
CREATE INDEX IF NOT EXISTS idx_spot_deals_spot_active ON public.spot_deals(spot_id, is_active);
CREATE INDEX IF NOT EXISTS idx_spot_events_spot_active ON public.spot_events(spot_id, is_active);
CREATE INDEX IF NOT EXISTS idx_spot_reservations_spot ON public.spot_reservations(spot_id, reserved_at);
CREATE INDEX IF NOT EXISTS idx_spot_reservations_user ON public.spot_reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_study_spots_tier ON public.study_spots(membership_tier);

-- Notify
DO $$
BEGIN
    RAISE NOTICE 'Study Spot Membership Tiers schema created successfully!';
END $$;
