-- Migration: Add University Theme Preference
-- Purpose: Allow users to toggle university-specific branding

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS use_university_theme BOOLEAN DEFAULT TRUE;
