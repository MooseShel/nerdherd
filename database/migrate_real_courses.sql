-- Migration: Real College Course Integration
-- Purpose: Replace fake university data with real UH and HCC courses

-- ============================================================================
-- STEP 1: Create New Tables (or update existing ones)
-- ============================================================================

-- Universities table
CREATE TABLE IF NOT EXISTS universities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  location TEXT,
  website_url TEXT,
  logo_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add short_name column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'universities' AND column_name = 'short_name'
  ) THEN
    ALTER TABLE universities ADD COLUMN short_name TEXT;
    -- Make it unique after adding
    ALTER TABLE universities ADD CONSTRAINT universities_short_name_key UNIQUE (short_name);
  END IF;
  
  -- Add location column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'universities' AND column_name = 'location'
  ) THEN
    ALTER TABLE universities ADD COLUMN location TEXT;
  END IF;
  
  -- Add website_url column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'universities' AND column_name = 'website_url'
  ) THEN
    ALTER TABLE universities ADD COLUMN website_url TEXT;
  END IF;
  
  -- Add logo_url column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'universities' AND column_name = 'logo_url'
  ) THEN
    ALTER TABLE universities ADD COLUMN logo_url TEXT;
  END IF;
  
  -- Add is_active column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'universities' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE universities ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;
END $$;

-- Departments table
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  university_id UUID REFERENCES universities(id) ON DELETE CASCADE,
  name TEXT NOT NULL, -- e.g., "Computer Science"
  code TEXT NOT NULL, -- e.g., "COSC"
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(university_id, code)
);

-- Courses table (replaces old "classes" table)
CREATE TABLE IF NOT EXISTS courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  university_id UUID REFERENCES universities(id) ON DELETE CASCADE,
  department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
  course_code TEXT NOT NULL, -- e.g., "COSC 1336"
  course_number TEXT NOT NULL, -- e.g., "1336"
  title TEXT NOT NULL,
  description TEXT,
  credits INTEGER,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(university_id, course_code)
);

-- User enrollments (link users to courses)
CREATE TABLE IF NOT EXISTS user_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  semester TEXT, -- e.g., "Spring 2026"
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, course_id, semester)
);

-- ============================================================================
-- STEP 2: Enable RLS
-- ============================================================================

ALTER TABLE universities ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_courses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Universities are viewable by everyone" ON universities;
DROP POLICY IF EXISTS "Departments are viewable by everyone" ON departments;
DROP POLICY IF EXISTS "Courses are viewable by everyone" ON courses;
DROP POLICY IF EXISTS "Users can view their own courses" ON user_courses;
DROP POLICY IF EXISTS "Users can insert their own courses" ON user_courses;
DROP POLICY IF EXISTS "Users can update their own courses" ON user_courses;
DROP POLICY IF EXISTS "Users can delete their own courses" ON user_courses;

-- Universities: Public read
CREATE POLICY "Universities are viewable by everyone"
  ON universities FOR SELECT
  USING (true);

-- Departments: Public read
CREATE POLICY "Departments are viewable by everyone"
  ON departments FOR SELECT
  USING (true);

-- Courses: Public read
CREATE POLICY "Courses are viewable by everyone"
  ON courses FOR SELECT
  USING (true);

-- User Courses: Users can manage their own enrollments
CREATE POLICY "Users can view their own courses"
  ON user_courses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own courses"
  ON user_courses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own courses"
  ON user_courses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own courses"
  ON user_courses FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- STEP 3: Insert Universities
-- ============================================================================

-- Insert or update universities with short_name
DO $$
BEGIN
  -- Update existing universities or insert new ones
  IF EXISTS (SELECT 1 FROM universities WHERE name = 'University of Houston') THEN
    UPDATE universities 
    SET short_name = 'UH', location = 'Houston, TX', website_url = 'https://www.uh.edu'
    WHERE name = 'University of Houston';
  ELSE
    INSERT INTO universities (name, short_name, location, website_url) 
    VALUES ('University of Houston', 'UH', 'Houston, TX', 'https://www.uh.edu');
  END IF;

  IF EXISTS (SELECT 1 FROM universities WHERE name = 'Houston Community College') THEN
    UPDATE universities 
    SET short_name = 'HCCS', location = 'Houston, TX', website_url = 'https://www.hccs.edu'
    WHERE name = 'Houston Community College';
  ELSE
    INSERT INTO universities (name, short_name, location, website_url) 
    VALUES ('Houston Community College', 'HCCS', 'Houston, TX', 'https://www.hccs.edu');
  END IF;
END $$;

-- ============================================================================
-- STEP 4: Insert Departments
-- ============================================================================

-- Get university IDs
DO $$
DECLARE
  uh_id UUID;
  hcc_id UUID;
BEGIN
  SELECT id INTO uh_id FROM universities WHERE short_name = 'UH';
  SELECT id INTO hcc_id FROM universities WHERE short_name = 'HCC';

  -- UH Departments
  INSERT INTO departments (university_id, name, code) VALUES
    (uh_id, 'Computer Science', 'COSC'),
    (uh_id, 'Mathematics', 'MATH'),
    (uh_id, 'English', 'ENGL'),
    (uh_id, 'History', 'HIST'),
    (uh_id, 'Biology', 'BIOL'),
    (uh_id, 'Chemistry', 'CHEM'),
    (uh_id, 'Physics', 'PHYS'),
    (uh_id, 'Psychology', 'PSYC'),
    (uh_id, 'Business', 'BUSI'),
    (uh_id, 'Accounting', 'ACCT'),
    (uh_id, 'Finance', 'FINA'),
    (uh_id, 'Management', 'MANA'),
    (uh_id, 'Marketing', 'MARK'),
    (uh_id, 'Economics', 'ECON')
  ON CONFLICT (university_id, code) DO NOTHING;

  -- HCC Departments
  INSERT INTO departments (university_id, name, code) VALUES
    (hcc_id, 'Computer Science', 'COSC'),
    (hcc_id, 'Mathematics', 'MATH'),
    (hcc_id, 'English', 'ENGL'),
    (hcc_id, 'Government', 'GOVT'),
    (hcc_id, 'History', 'HIST'),
    (hcc_id, 'Biology', 'BIOL'),
    (hcc_id, 'Chemistry', 'CHEM'),
    (hcc_id, 'Physics', 'PHYS'),
    (hcc_id, 'Psychology', 'PSYC'),
    (hcc_id, 'Sociology', 'SOCI'),
    (hcc_id, 'Speech', 'SPCH'),
    (hcc_id, 'Accounting', 'ACCT'),
    (hcc_id, 'Business', 'BUSI'),
    (hcc_id, 'Economics', 'ECON')
  ON CONFLICT (university_id, code) DO NOTHING;
END $$;

-- ============================================================================
-- STEP 5: Create Indexes for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_departments_university ON departments(university_id);
CREATE INDEX IF NOT EXISTS idx_courses_university ON courses(university_id);
CREATE INDEX IF NOT EXISTS idx_courses_department ON courses(department_id);
CREATE INDEX IF NOT EXISTS idx_courses_code ON courses(course_code);
CREATE INDEX IF NOT EXISTS idx_user_courses_user ON user_courses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_courses_course ON user_courses(course_id);

-- ============================================================================
-- STEP 6: Create Helper Functions
-- ============================================================================

-- Function to search courses by keyword
CREATE OR REPLACE FUNCTION search_courses(search_term TEXT, university_filter TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  university_name TEXT,
  department_name TEXT,
  course_code TEXT,
  title TEXT,
  credits INTEGER,
  description TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    u.name AS university_name,
    d.name AS department_name,
    c.course_code,
    c.title,
    c.credits,
    c.description
  FROM courses c
  JOIN universities u ON c.university_id = u.id
  JOIN departments d ON c.department_id = d.id
  WHERE 
    c.is_active = true
    AND (
      c.course_code ILIKE '%' || search_term || '%'
      OR c.title ILIKE '%' || search_term || '%'
      OR d.name ILIKE '%' || search_term || '%'
    )
    AND (university_filter IS NULL OR u.short_name = university_filter)
  ORDER BY c.course_code;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TABLE universities IS 'Real universities (UH, HCC, etc.)';
COMMENT ON TABLE departments IS 'Academic departments within universities';
COMMENT ON TABLE courses IS 'Real college courses from university catalogs';
COMMENT ON TABLE user_courses IS 'User enrollment in courses';
COMMENT ON FUNCTION search_courses IS 'Search courses by keyword with optional university filter';
