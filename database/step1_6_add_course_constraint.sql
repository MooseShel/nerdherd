-- Step 1.6: Add Unique Constraint to Courses Table
-- Run this BEFORE importing courses (part 1 and part 2)

-- Add unique constraint on (university_id, course_code)
DO $$
BEGIN
  -- Check if constraint already exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'courses_university_id_course_code_key'
  ) THEN
    -- Add the constraint
    ALTER TABLE courses 
    ADD CONSTRAINT courses_university_id_course_code_key 
    UNIQUE (university_id, course_code);
    
    RAISE NOTICE 'Added unique constraint on (university_id, course_code)';
  ELSE
    RAISE NOTICE 'Constraint already exists';
  END IF;
END $$;

-- Verify constraint was added
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'courses'::regclass;
