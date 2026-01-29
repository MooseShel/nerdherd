-- Step 1.5: Add Missing Columns to Courses Table (if it exists)
-- Run this AFTER step1_add_columns.sql and BEFORE migrate_real_courses.sql

-- Check if courses table exists and add missing columns
DO $$
BEGIN
  -- Only proceed if courses table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'courses') THEN
    
    -- Add department_id column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'courses' AND column_name = 'department_id'
    ) THEN
      ALTER TABLE courses ADD COLUMN department_id UUID;
      RAISE NOTICE 'Added department_id column to courses table';
    END IF;
    
    -- Add course_code column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'courses' AND column_name = 'course_code'
    ) THEN
      ALTER TABLE courses ADD COLUMN course_code TEXT;
      RAISE NOTICE 'Added course_code column to courses table';
    END IF;
    
    -- Add course_number column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'courses' AND column_name = 'course_number'
    ) THEN
      ALTER TABLE courses ADD COLUMN course_number TEXT;
      RAISE NOTICE 'Added course_number column to courses table';
    END IF;
    
    -- Add description column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'courses' AND column_name = 'description'
    ) THEN
      ALTER TABLE courses ADD COLUMN description TEXT;
      RAISE NOTICE 'Added description column to courses table';
    END IF;
    
    -- Add credits column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'courses' AND column_name = 'credits'
    ) THEN
      ALTER TABLE courses ADD COLUMN credits INTEGER;
      RAISE NOTICE 'Added credits column to courses table';
    END IF;
    
    -- Add is_active column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'courses' AND column_name = 'is_active'
    ) THEN
      ALTER TABLE courses ADD COLUMN is_active BOOLEAN DEFAULT true;
      RAISE NOTICE 'Added is_active column to courses table';
    END IF;
    
  ELSE
    RAISE NOTICE 'Courses table does not exist yet - skip this script';
  END IF;
END $$;

-- Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'courses'
ORDER BY ordinal_position;
