-- Seed Additional Universities and Courses

DO $$
DECLARE
  uni_gotham uuid;
  uni_metro uuid;
BEGIN
  -- 1. Create Gotham City University
  INSERT INTO public.universities (name, domain, logo_url)
  VALUES ('Gotham City University', 'gcu.edu', 'assets/images/gotham_logo.png')
  RETURNING id INTO uni_gotham;

  -- 2. Create Metropolis Institute of Tech
  INSERT INTO public.universities (name, domain, logo_url)
  VALUES ('Metropolis Institute of Tech', 'mit.edu', 'assets/images/metropolis_logo.png')
  RETURNING id INTO uni_metro;

  -- 3. Add Courses for Gotham City University
  IF uni_gotham IS NOT NULL THEN
    INSERT INTO public.courses (university_id, code, title, term)
    VALUES
      (uni_gotham, 'CRIM101', 'Criminology Basics', 'Fall 2025'),
      (uni_gotham, 'PSYCH202', 'Criminal Psychology', 'Fall 2025'),
      (uni_gotham, 'ENG101', 'Urban Engineering', 'Fall 2025'),
      (uni_gotham, 'CHEM301', 'Forensic Chemistry', 'Fall 2025'),
      (uni_gotham, 'LAW101', 'Introduction to Justice', 'Fall 2025');
  END IF;

  -- 4. Add Courses for Metropolis Institute of Tech
  IF uni_metro IS NOT NULL THEN
    INSERT INTO public.courses (university_id, code, title, term)
    VALUES
      (uni_metro, 'ROBOT101', 'Robotics Fundamentals', 'Fall 2025'),
      (uni_metro, 'JOURN101', 'Investigative Journalism', 'Fall 2025'),
      (uni_metro, 'PHYS404', 'Quantum Studies', 'Fall 2025'),
      (uni_metro, 'AERO201', 'Aerospace Engineering', 'Fall 2025'),
      (uni_metro, 'CS404', 'Advanced AI Systems', 'Fall 2025');
  END IF;

END $$;
