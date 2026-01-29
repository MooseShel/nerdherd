-- Update University Logo URLs to use local assets
-- Run this after the main migration

UPDATE universities 
SET logo_url = 'assets/images/UH_logo.png'
WHERE short_name = 'UH';

UPDATE universities 
SET logo_url = 'assets/images/HCCS_Logo.png'
WHERE short_name = 'HCC';

-- Verify
SELECT short_name, name, logo_url FROM universities;
