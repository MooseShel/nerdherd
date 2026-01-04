-- Initial Database Schema for Nerd Herd V2 (Serendipity Engine)
-- Copied from V2 codebase for migration to V1

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================
-- SERENDIPITY ENGINE TABLES
-- ============================================

-- Struggle Signals: Track when users need help
CREATE TABLE IF NOT EXISTS struggle_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  topic TEXT,
  confidence_level INT CHECK (confidence_level BETWEEN 1 AND 5),
  location GEOGRAPHY(POINT),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '2 hours',
  
  -- Index for proximity queries
  CONSTRAINT valid_location CHECK (location IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_struggle_signals_location ON struggle_signals USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_struggle_signals_expires ON struggle_signals(expires_at);
CREATE INDEX IF NOT EXISTS idx_struggle_signals_user ON struggle_signals(user_id);

-- Compatibility Scores: Pre-computed user matches
CREATE TABLE IF NOT EXISTS compatibility_scores (
  user_a UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  user_b UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  score FLOAT CHECK (score BETWEEN 0 AND 1),
  factors JSONB, -- {"skill_complement": 0.9, "temporal_overlap": 0.8}
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  
  PRIMARY KEY (user_a, user_b),
  CONSTRAINT different_users CHECK (user_a != user_b)
);

CREATE INDEX IF NOT EXISTS idx_compatibility_scores_user_a ON compatibility_scores(user_a);
CREATE INDEX IF NOT EXISTS idx_compatibility_scores_score ON compatibility_scores(score DESC);

-- Serendipity Matches: Successful alerts
CREATE TABLE IF NOT EXISTS serendipity_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  user_b UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  match_type TEXT CHECK (match_type IN ('proximity', 'constellation', 'temporal')),
  accepted BOOLEAN DEFAULT FALSE,
  rating INT CHECK (rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_serendipity_matches_user_a ON serendipity_matches(user_a);
CREATE INDEX IF NOT EXISTS idx_serendipity_matches_user_b ON serendipity_matches(user_b);

-- Activity Logs: Track user behavior patterns
CREATE TABLE IF NOT EXISTS activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'app_open', 'study_session_start', etc.
  metadata JSONB,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp);

-- User Skills: Derived from interactions
CREATE TABLE IF NOT EXISTS user_skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  skill_tag TEXT NOT NULL,
  competence_score FLOAT CHECK (competence_score BETWEEN 0 AND 1),
  endorsement_count INT DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, skill_tag)
);

CREATE INDEX IF NOT EXISTS idx_user_skills_user ON user_skills(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skills_tag ON user_skills(skill_tag);

-- ============================================
-- PROFILE EXTENSIONS
-- ============================================

-- Add new columns to existing profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS serendipity_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS serendipity_radius_meters INT DEFAULT 100;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS productivity_hours JSONB; -- [18, 19, 20] = 6-8 PM

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Struggle Signals
ALTER TABLE struggle_signals ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'struggle_signals' AND policyname = 'Users can view own struggle signals') THEN
    CREATE POLICY "Users can view own struggle signals" ON struggle_signals FOR SELECT USING (auth.uid() = user_id);
  END IF;
  
  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'struggle_signals' AND policyname = 'Users can insert own struggle signals') THEN
    CREATE POLICY "Users can insert own struggle signals" ON struggle_signals FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'struggle_signals' AND policyname = 'Users can delete own struggle signals') THEN
    CREATE POLICY "Users can delete own struggle signals" ON struggle_signals FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- Compatibility Scores
ALTER TABLE compatibility_scores ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'compatibility_scores' AND policyname = 'Users can view their compatibility scores') THEN
    CREATE POLICY "Users can view their compatibility scores" ON compatibility_scores FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);
  END IF;
END $$;

-- Serendipity Matches
ALTER TABLE serendipity_matches ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'serendipity_matches' AND policyname = 'Users can view their matches') THEN
    CREATE POLICY "Users can view their matches" ON serendipity_matches FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);
  END IF;

  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'serendipity_matches' AND policyname = 'Users can update their matches') THEN
    CREATE POLICY "Users can update their matches" ON serendipity_matches FOR UPDATE USING (auth.uid() = user_a OR auth.uid() = user_b);
  END IF;
END $$;

-- Activity Logs
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'activity_logs' AND policyname = 'Users can view own activity logs') THEN
    CREATE POLICY "Users can view own activity logs" ON activity_logs FOR SELECT USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'activity_logs' AND policyname = 'Users can insert own activity logs') THEN
    CREATE POLICY "Users can insert own activity logs" ON activity_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- User Skills
ALTER TABLE user_skills ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_policies WHERE tablename = 'user_skills' AND policyname = 'Anyone can view user skills') THEN
    CREATE POLICY "Anyone can view user skills" ON user_skills FOR SELECT USING (true);
  END IF;
END $$;

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Get nearby struggle signals
CREATE OR REPLACE FUNCTION get_nearby_struggles(
  user_location GEOGRAPHY,
  radius_meters INT DEFAULT 100
)
RETURNS TABLE (
  signal_id UUID,
  user_id UUID,
  subject TEXT,
  topic TEXT,
  confidence_level INT,
  distance_meters FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.user_id,
    s.subject,
    s.topic,
    s.confidence_level,
    ST_Distance(s.location, user_location) as distance_meters
  FROM struggle_signals s
  WHERE s.expires_at > NOW()
    AND ST_DWithin(s.location, user_location, radius_meters)
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Clean up expired struggle signals (run via cron)
CREATE OR REPLACE FUNCTION cleanup_expired_struggles()
RETURNS void AS $$
BEGIN
  DELETE FROM struggle_signals
  WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
