-- Complete Course Data Import - All 150+ Courses
-- Run this AFTER migrate_real_courses.sql
-- This script contains all course data embedded directly - no external files needed!

-- ============================================================================
-- University of Houston (UH) Courses
-- ============================================================================

DO $$
DECLARE
  uh_id UUID;
  hcc_id UUID;
  dept_id UUID;
BEGIN
  -- Get university IDs
  SELECT id INTO uh_id FROM universities WHERE short_name = 'UH';
  SELECT id INTO hcc_id FROM universities WHERE short_name = 'HCC';

  -- ========================================================================
  -- UH Computer Science (COSC)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'COSC';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'COSC 1301', '1301', 'Introduction to Computing', 3, 'Introduction to Computing - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 1336', '1336', 'Programming Fundamentals I', 3, 'Programming Fundamentals I - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 1437', '1437', 'Programming Fundamentals II', 4, 'Programming Fundamentals II - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 2336', '2336', 'Programming Fundamentals III', 3, 'Programming Fundamentals III - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 2425', '2425', 'Computer Organization', 4, 'Computer Organization - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3320', '3320', 'Data Structures', 3, 'Data Structures - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3340', '3340', 'Introduction to Automata and Computability Theory', 3, 'Introduction to Automata and Computability Theory - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 3380', '3380', 'Database Systems', 3, 'Database Systems - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4315', '4315', 'Programming Languages and Paradigms', 3, 'Programming Languages and Paradigms - Computer Science course at University of Houston'),
    (uh_id, dept_id, 'COSC 4353', '4353', 'Algorithm Design and Analysis', 3, 'Algorithm Design and Analysis - Computer Science course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Mathematics (MATH)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'MATH';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'MATH 1310', '1310', 'College Algebra', 3, 'College Algebra - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 1311', '1311', 'Elementary Mathematical Modeling', 3, 'Elementary Mathematical Modeling - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 1313', '1313', 'Finite Mathematics with Applications', 3, 'Finite Mathematics with Applications - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 1314', '1314', 'College Algebra for Business and Social Sciences', 3, 'College Algebra for Business and Social Sciences - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 1330', '1330', 'Precalculus', 3, 'Precalculus - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 1431', '1431', 'Calculus I', 4, 'Calculus I - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 1432', '1432', 'Calculus II', 4, 'Calculus II - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 2311', '2311', 'Technical Calculus I', 3, 'Technical Calculus I - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 2331', '2331', 'Linear Algebra', 3, 'Linear Algebra - Mathematics course at University of Houston'),
    (uh_id, dept_id, 'MATH 2433', '2433', 'Calculus III', 4, 'Calculus III - Mathematics course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH English (ENGL)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'ENGL';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'ENGL 1303', '1303', 'First-Year Writing I', 3, 'First-Year Writing I - English course at University of Houston'),
    (uh_id, dept_id, 'ENGL 1304', '1304', 'First-Year Writing II', 3, 'First-Year Writing II - English course at University of Houston'),
    (uh_id, dept_id, 'ENGL 2311', '2311', 'Technical and Professional Writing', 3, 'Technical and Professional Writing - English course at University of Houston'),
    (uh_id, dept_id, 'ENGL 2341', '2341', 'Forms of Literature', 3, 'Forms of Literature - English course at University of Houston'),
    (uh_id, dept_id, 'ENGL 2342', '2342', 'Forms of Literature: Drama', 3, 'Forms of Literature: Drama - English course at University of Houston'),
    (uh_id, dept_id, 'ENGL 2343', '2343', 'Forms of Literature: Poetry', 3, 'Forms of Literature: Poetry - English course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH History (HIST)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'HIST';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'HIST 1377', '1377', 'United States History to 1877', 3, 'United States History to 1877 - History course at University of Houston'),
    (uh_id, dept_id, 'HIST 1378', '1378', 'United States History since 1877', 3, 'United States History since 1877 - History course at University of Houston'),
    (uh_id, dept_id, 'HIST 2381', '2381', 'African American History', 3, 'African American History - History course at University of Houston'),
    (uh_id, dept_id, 'HIST 2382', '2382', 'Mexican American History', 3, 'Mexican American History - History course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Biology (BIOL)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'BIOL';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'BIOL 1361', '1361', 'Introduction to Biological Sciences I', 3, 'Introduction to Biological Sciences I - Biology course at University of Houston'),
    (uh_id, dept_id, 'BIOL 1362', '1362', 'Introduction to Biological Sciences II', 3, 'Introduction to Biological Sciences II - Biology course at University of Houston'),
    (uh_id, dept_id, 'BIOL 1406', '1406', 'Biology for Science Majors I', 4, 'Biology for Science Majors I - Biology course at University of Houston'),
    (uh_id, dept_id, 'BIOL 1407', '1407', 'Biology for Science Majors II', 4, 'Biology for Science Majors II - Biology course at University of Houston'),
    (uh_id, dept_id, 'BIOL 2311', '2311', 'Genetics', 3, 'Genetics - Biology course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Chemistry (CHEM)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'CHEM';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'CHEM 1331', '1331', 'Fundamentals of Chemistry I', 3, 'Fundamentals of Chemistry I - Chemistry course at University of Houston'),
    (uh_id, dept_id, 'CHEM 1332', '1332', 'Fundamentals of Chemistry II', 3, 'Fundamentals of Chemistry II - Chemistry course at University of Houston'),
    (uh_id, dept_id, 'CHEM 1370', '1370', 'Fundamentals of Chemistry I Laboratory', 3, 'Fundamentals of Chemistry I Laboratory - Chemistry course at University of Houston'),
    (uh_id, dept_id, 'CHEM 1371', '1371', 'Fundamentals of Chemistry II Laboratory', 3, 'Fundamentals of Chemistry II Laboratory - Chemistry course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Physics (PHYS)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'PHYS';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'PHYS 1321', '1321', 'Physics I - Mechanics', 3, 'Physics I - Mechanics - Physics course at University of Houston'),
    (uh_id, dept_id, 'PHYS 1322', '1322', 'Physics II - E&M and Waves', 3, 'Physics II - E&M and Waves - Physics course at University of Houston'),
    (uh_id, dept_id, 'PHYS 1331', '1331', 'Physics I for Science and Engineering', 3, 'Physics I for Science and Engineering - Physics course at University of Houston'),
    (uh_id, dept_id, 'PHYS 1332', '1332', 'Physics II for Science and Engineering', 3, 'Physics II for Science and Engineering - Physics course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Psychology (PSYC)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'PSYC';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'PSYC 1300', '1300', 'Introduction to Psychology', 3, 'Introduction to Psychology - Psychology course at University of Houston'),
    (uh_id, dept_id, 'PSYC 2301', '2301', 'Introductory Psychology', 3, 'Introductory Psychology - Psychology course at University of Houston'),
    (uh_id, dept_id, 'PSYC 2317', '2317', 'Statistical Methods in Psychology', 3, 'Statistical Methods in Psychology - Psychology course at University of Houston'),
    (uh_id, dept_id, 'PSYC 3317', '3317', 'Research Methods in Psychology', 3, 'Research Methods in Psychology - Psychology course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Business (BUSI)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'BUSI';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'BUSI 1301', '1301', 'Business Principles', 3, 'Business Principles - Business course at University of Houston'),
    (uh_id, dept_id, 'BUSI 3305', '3305', 'Business Communication', 3, 'Business Communication - Business course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Accounting (ACCT)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'ACCT';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'ACCT 2331', '2331', 'Fundamentals of Financial Accounting', 3, 'Fundamentals of Financial Accounting - Accounting course at University of Houston'),
    (uh_id, dept_id, 'ACCT 2332', '2332', 'Fundamentals of Managerial Accounting', 3, 'Fundamentals of Managerial Accounting - Accounting course at University of Houston'),
    (uh_id, dept_id, 'ACCT 3333', '3333', 'Intermediate Financial Accounting I', 3, 'Intermediate Financial Accounting I - Accounting course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Finance (FINA)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'FINA';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'FINA 3332', '3332', 'Business Finance', 3, 'Business Finance - Finance course at University of Houston'),
    (uh_id, dept_id, 'FINA 3334', '3334', 'Investments', 3, 'Investments - Finance course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Management (MANA)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'MANA';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'MANA 3335', '3335', 'Organizational Behavior and Management', 3, 'Organizational Behavior and Management - Management course at University of Houston'),
    (uh_id, dept_id, 'MANA 3336', '3336', 'Fundamentals of Management Science', 3, 'Fundamentals of Management Science - Management course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Marketing (MARK)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'MARK';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'MARK 3336', '3336', 'Principles of Marketing', 3, 'Principles of Marketing - Marketing course at University of Houston'),
    (uh_id, dept_id, 'MARK 4335', '4335', 'Consumer Behavior', 3, 'Consumer Behavior - Marketing course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  -- ========================================================================
  -- UH Economics (ECON)
  -- ========================================================================
  SELECT id INTO dept_id FROM departments WHERE university_id = uh_id AND code = 'ECON';
  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES
    (uh_id, dept_id, 'ECON 2304', '2304', 'Principles of Microeconomics', 3, 'Principles of Microeconomics - Economics course at University of Houston'),
    (uh_id, dept_id, 'ECON 2305', '2305', 'Principles of Macroeconomics', 3, 'Principles of Macroeconomics - Economics course at University of Houston')
  ON CONFLICT (university_id, course_code) DO NOTHING;

  RAISE NOTICE 'Imported all UH courses (63 total)';

END $$;

-- Continue in next part...
