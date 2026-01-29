-- Complete Course Data Import - Part 2: HCC Courses
-- Run this AFTER import_all_courses_part1.sql

-- ============================================================================
-- Houston Community College (HCC) Courses
-- ============================================================================

DO $$
DECLARE
  hcc_id UUID;
  dept_id UUID;
BEGIN
  -- Get HCC university ID
  SELECT id INTO hcc_id FROM universities WHERE short_name = 'HCC';

  -- ========================================================================
  -- HCC Computer Science (COSC)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'COSC';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'COSC 1301', '1301', 'Introduction to Computing', 3, 'Introduction to Computing - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 1336', '1336', 'Programming Fundamentals I', 3, 'Programming Fundamentals I - Computer Science course at Houston Community College'),
    (hcc_id, dept_id, 'COSC 1437', '1437', 'Programming Fundamentals II', 4, 'Programming Fundamentals II - Computer Science course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Mathematics (MATH)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'MATH';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'MATH 0308', '0308', 'Foundations of Mathematics', 3, 'Foundations of Mathematics - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1314', '1314', 'College Algebra', 3, 'College Algebra - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1316', '1316', 'Trigonometry', 3, 'Trigonometry - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1324', '1324', 'Mathematics for Business and Social Sciences I', 3, 'Mathematics for Business and Social Sciences I - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1325', '1325', 'Calculus for Business and Social Sciences', 3, 'Calculus for Business and Social Sciences - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1342', '1342', 'Elementary Statistical Methods', 3, 'Elementary Statistical Methods - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1350', '1350', 'Fundamentals of Mathematics I', 3, 'Fundamentals of Mathematics I - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 1351', '1351', 'Fundamentals of Mathematics II', 3, 'Fundamentals of Mathematics II - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 2412', '2412', 'Pre-Calculus', 4, 'Pre-Calculus - Mathematics course at Houston Community College'),
    (hcc_id, dept_id, 'MATH 2413', '2413', 'Calculus I', 4, 'Calculus I - Mathematics course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC English (ENGL)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'ENGL';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'ENGL 1301', '1301', 'Composition I', 3, 'Composition I - English course at Houston Community College'),
    (hcc_id, dept_id, 'ENGL 1302', '1302', 'Composition II', 3, 'Composition II - English course at Houston Community College'),
    (hcc_id, dept_id, 'ENGL 2311', '2311', 'Technical and Business Writing', 3, 'Technical and Business Writing - English course at Houston Community College'),
    (hcc_id, dept_id, 'ENGL 2322', '2322', 'British Literature I', 3, 'British Literature I - English course at Houston Community College'),
    (hcc_id, dept_id, 'ENGL 2323', '2323', 'British Literature II', 3, 'British Literature II - English course at Houston Community College'),
    (hcc_id, dept_id, 'ENGL 2327', '2327', 'American Literature I', 3, 'American Literature I - English course at Houston Community College'),
    (hcc_id, dept_id, 'ENGL 2328', '2328', 'American Literature II', 3, 'American Literature II - English course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Government (GOVT)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'GOVT';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'GOVT 2305', '2305', 'Federal Government', 3, 'Federal Government - Government course at Houston Community College'),
    (hcc_id, dept_id, 'GOVT 2306', '2306', 'Texas Government', 3, 'Texas Government - Government course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC History (HIST)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'HIST';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'HIST 1301', '1301', 'United States History I', 3, 'United States History I - History course at Houston Community College'),
    (hcc_id, dept_id, 'HIST 1302', '1302', 'United States History II', 3, 'United States History II - History course at Houston Community College'),
    (hcc_id, dept_id, 'HIST 2321', '2321', 'World Civilizations I', 3, 'World Civilizations I - History course at Houston Community College'),
    (hcc_id, dept_id, 'HIST 2322', '2322', 'World Civilizations II', 3, 'World Civilizations II - History course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Biology (BIOL)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'BIOL';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'BIOL 1406', '1406', 'Biology for Science Majors I', 4, 'Biology for Science Majors I - Biology course at Houston Community College'),
    (hcc_id, dept_id, 'BIOL 1407', '1407', 'Biology for Science Majors II', 4, 'Biology for Science Majors II - Biology course at Houston Community College'),
    (hcc_id, dept_id, 'BIOL 1408', '1408', 'Biology for Non-Science Majors I', 4, 'Biology for Non-Science Majors I - Biology course at Houston Community College'),
    (hcc_id, dept_id, 'BIOL 1409', '1409', 'Biology for Non-Science Majors II', 4, 'Biology for Non-Science Majors II - Biology course at Houston Community College'),
    (hcc_id, dept_id, 'BIOL 2401', '2401', 'Anatomy and Physiology I', 4, 'Anatomy and Physiology I - Biology course at Houston Community College'),
    (hcc_id, dept_id, 'BIOL 2402', '2402', 'Anatomy and Physiology II', 4, 'Anatomy and Physiology II - Biology course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Chemistry (CHEM)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'CHEM';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'CHEM 1405', '1405', 'Introductory Chemistry I', 4, 'Introductory Chemistry I - Chemistry course at Houston Community College'),
    (hcc_id, dept_id, 'CHEM 1406', '1406', 'Introductory Chemistry II', 4, 'Introductory Chemistry II - Chemistry course at Houston Community College'),
    (hcc_id, dept_id, 'CHEM 1411', '1411', 'General Chemistry I', 4, 'General Chemistry I - Chemistry course at Houston Community College'),
    (hcc_id, dept_id, 'CHEM 1412', '1412', 'General Chemistry II', 4, 'General Chemistry II - Chemistry course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Physics (PHYS)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'PHYS';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'PHYS 1401', '1401', 'College Physics I', 4, 'College Physics I - Physics course at Houston Community College'),
    (hcc_id, dept_id, 'PHYS 1402', '1402', 'College Physics II', 4, 'College Physics II - Physics course at Houston Community College'),
    (hcc_id, dept_id, 'PHYS 2425', '2425', 'University Physics I', 4, 'University Physics I - Physics course at Houston Community College'),
    (hcc_id, dept_id, 'PHYS 2426', '2426', 'University Physics II', 4, 'University Physics II - Physics course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Psychology (PSYC)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'PSYC';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'PSYC 2301', '2301', 'General Psychology', 3, 'General Psychology - Psychology course at Houston Community College'),
    (hcc_id, dept_id, 'PSYC 2314', '2314', 'Lifespan Growth and Development', 3, 'Lifespan Growth and Development - Psychology course at Houston Community College'),
    (hcc_id, dept_id, 'PSYC 2316', '2316', 'Psychology of Personality', 3, 'Psychology of Personality - Psychology course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Sociology (SOCI)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'SOCI';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'SOCI 1301', '1301', 'Introduction to Sociology', 3, 'Introduction to Sociology - Sociology course at Houston Community College'),
    (hcc_id, dept_id, 'SOCI 1306', '1306', 'Social Problems', 3, 'Social Problems - Sociology course at Houston Community College'),
    (hcc_id, dept_id, 'SOCI 2301', '2301', 'Marriage and the Family', 3, 'Marriage and the Family - Sociology course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Speech (SPCH)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'SPCH';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'SPCH 1311', '1311', 'Introduction to Speech Communication', 3, 'Introduction to Speech Communication - Speech course at Houston Community College'),
    (hcc_id, dept_id, 'SPCH 1315', '1315', 'Public Speaking', 3, 'Public Speaking - Speech course at Houston Community College'),
    (hcc_id, dept_id, 'SPCH 1318', '1318', 'Interpersonal Communication', 3, 'Interpersonal Communication - Speech course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Accounting (ACCT)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'ACCT';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'ACCT 2301', '2301', 'Principles of Financial Accounting', 3, 'Principles of Financial Accounting - Accounting course at Houston Community College'),
    (hcc_id, dept_id, 'ACCT 2302', '2302', 'Principles of Managerial Accounting', 3, 'Principles of Managerial Accounting - Accounting course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Business (BUSI)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'BUSI';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'BUSI 1301', '1301', 'Business Principles', 3, 'Business Principles - Business course at Houston Community College'),
    (hcc_id, dept_id, 'BUSI 2301', '2301', 'Business Law', 3, 'Business Law - Business course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- HCC Economics (ECON)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = hcc_id AND code = 'ECON';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (hcc_id, dept_id, 'ECON 2301', '2301', 'Principles of Macroeconomics', 3, 'Principles of Macroeconomics - Economics course at Houston Community College'),
    (hcc_id, dept_id, 'ECON 2302', '2302', 'Principles of Microeconomics', 3, 'Principles of Microeconomics - Economics course at Houston Community College')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  RAISE NOTICE 'Imported all HCC courses (53 total)';
  RAISE NOTICE '✅ COMPLETE: Imported 116 total courses (63 UH + 53 HCC)';

END $$;

-- ============================================================================
-- Verification Query
-- ============================================================================

SELECT 
  u.short_name AS university,
  d.name AS department,
  COUNT(*) AS course_count
FROM courses c
JOIN universities u ON c.university_id = u.id
JOIN departments d ON c.department_id = d.id
GROUP BY u.short_name, d.name
ORDER BY u.short_name, d.name;

-- Test search function
SELECT * FROM search_courses('programming');
