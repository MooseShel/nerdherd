-- Check for 'vector' extension
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Check columns in 'profiles' table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('study_style_social', 'study_style_temporal', 'bio_embedding');
