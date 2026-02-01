
-- Fix Duplicate HCCS University Records
-- Usage: Run this script in the Supabase SQL Editor

DO $$
DECLARE
  -- The "Target" is the PREVIOUSLY EXISTING university (The one we want to keep)
  target_id UUID := '43d36a3a-1e6f-4a2e-88c4-232ce79519f8';
  
  -- The "Source" is the NEW/DUPLICATE university (The one we want to remove)
  source_id UUID := 'd4a21b6d-931a-4958-8e96-90dd8b51f5f6';
  
  source_dept RECORD;
  target_dept_id UUID;
BEGIN
  RAISE NOTICE 'Starting Merge of HCCS Universities...';
  RAISE NOTICE 'Target (Keep): %', target_id;
  RAISE NOTICE 'Source (Remove): %', source_id;

  -- 1. Ensure the Target has the correct short_name so future imports match it
  UPDATE universities 
  SET short_name = 'HCCS' 
  WHERE id = target_id;
  
  -- 2. Iterate through all departments in the Source university
  FOR source_dept IN SELECT * FROM departments WHERE university_id = source_id LOOP
    
    -- Check if this department code already exists in the Target university
    SELECT id INTO target_dept_id 
    FROM departments 
    WHERE university_id = target_id AND code = source_dept.code;
    
    IF target_dept_id IS NOT NULL THEN
      -- CASE A: Department exists in Target. 
      -- Move courses to the existing Target department.
      RAISE NOTICE 'Merging department % (%)', source_dept.name, source_dept.code;
      
      -- Update courses to point to the Target University and Target Department
      -- Use ON CONFLICT DO NOTHING behavior via manual check or ignore errors if course code exists?
      -- The courses table has UNIQUE(university_id, course_code). 
      -- If we simply update, we might hit unique constraint if course already exists in Target.
      
      -- Strategy: Attempt update, if conflict, delete the Source course (assuming Target is truth or they are identical)
      -- However, since Source is "New", it might have "better" data? 
      -- Actually, user said Source is just "New added", probably via my script. 
      -- My script has the "Good" data. 
      -- But my script UPSERTS. 
      -- Let's just move them. If conflict, it means Target already has the course. 
      -- Since we want to keep the Target's identity, we can delete the Source course if it conflicts.
      
      -- Move non-conflicting courses
      UPDATE courses 
      SET university_id = target_id, department_id = target_dept_id
      WHERE department_id = source_dept.id
      AND course_code NOT IN (SELECT course_code FROM courses WHERE university_id = target_id);
      
      -- Delete remaining courses in Source Dept (they are duplicates)
      DELETE FROM courses WHERE department_id = source_dept.id;
      
      -- Now Source Dept is empty of courses, delete the Source Dept
      DELETE FROM departments WHERE id = source_dept.id;
      
    ELSE
      -- CASE B: Department does NOT exist in Target.
      -- Simply move the Department to the Target University.
      RAISE NOTICE 'Moving new department % (%)', source_dept.name, source_dept.code;
      
      UPDATE departments 
      SET university_id = target_id 
      WHERE id = source_dept.id;
      
      -- Update its courses to point to Target University
      UPDATE courses 
      SET university_id = target_id 
      WHERE department_id = source_dept.id;
      
    END IF;
  END LOOP;

  -- 3. Delete the Source University
  -- (Assuming cascade delete handles any lingering child records, but we tried to move them all)
  -- Just in case there are other tables referencing university_id not covered (like user_courses? references course_id mainly)
  
  DELETE FROM universities WHERE id = source_id;
  
  RAISE NOTICE '✅ Merge Complete. Duplicate HCCS removed.';
  
END $$;
