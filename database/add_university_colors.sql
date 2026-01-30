-- Migration: Add University Branding Colors
-- Purpose: Support custom branding for UH and HCCS

ALTER TABLE universities ADD COLUMN IF NOT EXISTS primary_color TEXT;
ALTER TABLE universities ADD COLUMN IF NOT EXISTS secondary_color TEXT;
ALTER TABLE universities ADD COLUMN IF NOT EXISTS domain TEXT;

-- Update UH
UPDATE universities 
SET primary_color = '#C8102E', secondary_color = '#FFFFFF', domain = 'uh.edu'
WHERE short_name = 'UH';

-- Update HCC
UPDATE universities 
SET primary_color = '#FFB81C', secondary_color = '#000000', domain = 'hccs.edu'
WHERE short_name = 'HCC';
