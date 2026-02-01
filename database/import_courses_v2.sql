
-- Complete Course Data Import v2 - Corrected and Expanded
-- Run this AFTER migrate_real_courses.sql
-- This script contains the updated course data based on 2026 catalog verification.

DO $$
DECLARE
  uh_id UUID;
  hcc_id UUID;
  dept_id UUID;
BEGIN
  -- ========================================================================
  -- Ensure Universities Exist
  -- ========================================================================
  
  -- Upsert UH
  IF EXISTS (SELECT 1 FROM universities WHERE short_name = 'UH') THEN
    UPDATE universities 
    SET name = 'University of Houston', 
        location = 'Houston, TX', 
        website_url = 'https://www.uh.edu',
        primary_color = '#C8102E',
        secondary_color = '#FFFFFF'
    WHERE short_name = 'UH';
  ELSE
    INSERT INTO universities (name, short_name, location, website_url, primary_color, secondary_color) 
    VALUES ('University of Houston', 'UH', 'Houston, TX', 'https://www.uh.edu', '#C8102E', '#FFFFFF');
  END IF;

  -- Upsert HCC
  IF EXISTS (SELECT 1 FROM universities WHERE short_name = 'HCCS') THEN
    UPDATE universities 
    SET name = 'Houston Community College', 
        location = 'Houston, TX', 
        website_url = 'https://www.hccs.edu',
        primary_color = '#FFB81C',
        secondary_color = '#000000'
    WHERE short_name = 'HCCS';
  ELSE
    INSERT INTO universities (name, short_name, location, website_url, primary_color, secondary_color) 
    VALUES ('Houston Community College', 'HCCS', 'Houston, TX', 'https://www.hccs.edu', '#FFB81C', '#000000');
  END IF;

  -- Get university IDs
  SELECT id INTO uh_id FROM universities WHERE short_name = 'UH';
  SELECT id INTO hcc_id FROM universities WHERE short_name = 'HCCS';

  -- ========================================================================
  -- Ensure Departments Exist
  -- ========================================================================
  INSERT INTO departments (university_id, name, code) VALUES
    (uh_id, 'Computer Science', 'COSC'),
    (hcc_id, 'Computer Science', 'COSC')
  ON CONFLICT (university_id, code) DO NOTHING;

  -- ========================================================================
  -- UH Computer Science (COSC) - UPDATED
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'COSC';
  
  -- Insert/Upsert UH COSC
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'COSC 1306', '1306', 'Computer Science and Programming', 3, 'Computer Science and Programming - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 1336', '1336', 'Programming Fundamentals I', 3, 'Programming Fundamentals I - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 1437', '1437', 'Introduction to Programming', 4, 'Introduction to Programming - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 2436', '2436', 'Programming and Data Structures', 4, 'Programming and Data Structures - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 2425', '2425', 'Computer Organization', 4, 'Computer Organization - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3320', '3320', 'Algorithms and Data Structures', 3, 'Algorithms and Data Structures - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3340', '3340', 'Introduction to Automata and Computability Theory', 3, 'Introduction to Automata and Computability Theory - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3360', '3360', 'Fundamentals of Operating Systems', 3, 'Fundamentals of Operating Systems - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3380', '3380', 'Database Systems', 3, 'Database Systems - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4351', '4351', 'Fundamentals of Software Engineering', 3, 'Fundamentals of Software Engineering - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4353', '4353', 'Software Design', 3, 'Software Design - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4354', '4354', 'Software Development Practices', 3, 'Software Development Practices - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4355', '4355', 'Introduction to Ubiquitous Computing', 3, 'Introduction to Ubiquitous Computing - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3337', '3337', 'Data Science I', 3, 'Data Science I - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4337', '4337', 'Data Science II', 3, 'Data Science II - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4358', '4358', 'Introduction to Interactive Game Development', 3, 'Introduction to Interactive Game Development - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4359', '4359', 'Intermediate Interactive Game Development', 3, 'Intermediate Interactive Game Development - Computer Science course at University of Houston')
  ON CONFLICT (university_id, course_code) 
  DO UPDATE SET 
    title = EXCLUDED.title, 
    credits = EXCLUDED.credits, 
    course_number = EXCLUDED.course_number;

  -- ========================================================================
  -- HCC Computer Science (COSC) - UPDATED
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'COSC';
  
  -- Insert/Upsert HCC COSC
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'COSC 1301', '1301', 'Introduction to Computing', 3, 'Introduction to Computing - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 1420', '1420', 'C Programming', 4, 'C Programming - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 1436', '1436', 'Programming Fundamentals I', 4, 'Programming Fundamentals I - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 1437', '1437', 'Programming Fundamentals II', 4, 'Programming Fundamentals II - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 2425', '2425', 'Computer Organization', 4, 'Computer Organization - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 2436', '2436', 'Programming Fundamentals III', 4, 'Programming Fundamentals III - Computer Science course at Houston Community College')
  ON CONFLICT (university_id, course_code) 
  DO UPDATE SET 
    title = EXCLUDED.title, 
    credits = EXCLUDED.credits, 
    course_number = EXCLUDED.course_number;

  RAISE NOTICE '✅ UPDATED Course Data for UH and HCC Computer Science';
END $$;
