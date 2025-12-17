-- Seed Courses for Nerd Herd University
-- This script looks up the university by name and inserts common courses.

DO $$
DECLARE
  uni_id uuid;
BEGIN
  -- 1. Get the University ID
  SELECT id INTO uni_id FROM public.universities WHERE name = 'Nerd Herd University' LIMIT 1;

  -- 2. If University exists, insert courses
  IF uni_id IS NOT NULL THEN
    INSERT INTO public.courses (university_id, code, title, term)
    VALUES
      (uni_id, 'CS101', 'Intro to Computer Science', 'Fall 2025'),
      (uni_id, 'CS102', 'Data Structures & Algorithms', 'Fall 2025'),
      (uni_id, 'CS103', 'Database Systems', 'Fall 2025'),
      (uni_id, 'CS201', 'Web Development Fundamentals', 'Fall 2025'),
      (uni_id, 'CS202', 'Mobile App Development', 'Fall 2025'),
      (uni_id, 'CS301', 'Artificial Intelligence', 'Fall 2025'),
      (uni_id, 'MATH101', 'Calculus I', 'Fall 2025'),
      (uni_id, 'MATH102', 'Linear Algebra', 'Fall 2025'),
      (uni_id, 'MATH201', 'Statistics & Probability', 'Fall 2025'),
      (uni_id, 'PHYS101', 'General Physics I', 'Fall 2025'),
      (uni_id, 'CHEM101', 'General Chemistry', 'Fall 2025'),
      (uni_id, 'BIO101', 'Biology 101', 'Fall 2025'),
      (uni_id, 'ENG101', 'English Composition', 'Fall 2025'),
      (uni_id, 'LIT201', 'Modern Literature', 'Fall 2025'),
      (uni_id, 'HIST101', 'World History', 'Fall 2025'),
      (uni_id, 'PSYCH101', 'Intro to Psychology', 'Fall 2025'),
      (uni_id, 'ECON101', 'Microeconomics', 'Fall 2025'),
      (uni_id, 'BUS101', 'Principles of Management', 'Fall 2025'),
      (uni_id, 'ART101', 'Art History', 'Fall 2025'),
      (uni_id, 'DES101', 'Graphic Design Basics', 'Fall 2025');
  END IF;
END $$;
