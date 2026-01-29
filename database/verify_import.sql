-- Verification Query: Check Course Import Success
-- Run this to verify all courses were imported correctly

-- 1. Count total courses
SELECT COUNT(*) as total_courses FROM courses;

-- 2. Breakdown by university
SELECT 
  u.short_name AS university,
  COUNT(*) AS course_count
FROM courses c
JOIN universities u ON c.university_id = u.id
GROUP BY u.short_name
ORDER BY u.short_name;

-- 3. Breakdown by university and department
SELECT 
  u.short_name AS university,
  d.name AS department,
  COUNT(*) AS course_count
FROM courses c
JOIN universities u ON c.university_id = u.id
JOIN departments d ON c.department_id = d.id
GROUP BY u.short_name, d.name
ORDER BY u.short_name, d.name;

-- 4. Sample courses from each university
SELECT 
  u.short_name,
  c.course_code,
  c.title,
  c.credits
FROM courses c
JOIN universities u ON c.university_id = u.id
ORDER BY u.short_name, c.course_code
LIMIT 20;

-- 5. Test search function
SELECT * FROM search_courses('programming');
SELECT * FROM search_courses('calculus', 'UH');
SELECT * FROM search_courses('biology', 'HCC');
