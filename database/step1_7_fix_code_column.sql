-- Step 1.7: Fix Courses Table Schema Issues
-- Run this BEFORE importing courses

-- Remove NOT NULL constraint from 'code' column if it exists
DO $$
BEGIN
  -- Check if 'code' column exists and has NOT NULL constraint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'courses' AND column_name = 'code'
  ) THEN
    -- Drop NOT NULL constraint
    ALTER TABLE courses ALTER COLUMN code DROP NOT NULL;
    RAISE NOTICE 'Removed NOT NULL constraint from code column';
  END IF;
END $$;

-- Alternatively, populate 'code' from 'course_code' if both exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'courses' AND column_name = 'code'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'courses' AND column_name = 'course_code'
  ) THEN
    -- Update existing rows to copy course_code to code
    UPDATE courses SET code = course_code WHERE code IS NULL;
    RAISE NOTICE 'Updated code column from course_code';
  END IF;
END $$;

-- Verify schema
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'courses'
ORDER BY ordinal_position;
