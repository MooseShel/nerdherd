# Database Migration - Step-by-Step Instructions

## Problem
The existing `universities` table is missing columns needed for the new course system.

## Solution: Run These Scripts in Order

### Step 1: Add Missing Columns to Universities
**File**: `step1_add_columns.sql`

This adds the missing columns to your existing `universities` table:
- `short_name`
- `location`
- `website_url`
- `logo_url`
- `is_active`

**Run this first!**

### Step 1.5: Add Missing Columns to Courses (if exists)
**File**: `step1_5_add_course_columns.sql`

If you have an existing `courses` table, this adds missing columns:
- `department_id`
- `course_code`
- `course_number`
- `description`
- `credits`
- `is_active`

**Run this second!**

### Step 1.6: Add Unique Constraint to Courses
**File**: `step1_6_add_course_constraint.sql`

Adds the unique constraint needed for course imports:
- UNIQUE (university_id, course_code)

**Run this third!**

### Step 2: Run Main Migration
**File**: `migrate_real_courses.sql`

This creates the new tables and sets up the schema:
- `departments`
- `courses`
- `user_courses`
- RLS policies
- Indexes
- Search function

### Step 3: Import UH Courses
**File**: `import_all_courses_part1.sql`

Imports 63 courses from University of Houston.

### Step 4: Import HCC Courses
**File**: `import_all_courses_part2.sql`

Imports 53 courses from Houston Community College.

## Verification

After running all scripts, verify with:

```sql
-- Check universities
SELECT * FROM universities;

-- Check course counts
SELECT 
  u.short_name,
  d.name AS department,
  COUNT(*) AS course_count
FROM courses c
JOIN universities u ON c.university_id = u.id
JOIN departments d ON c.department_id = d.id
GROUP BY u.short_name, d.name
ORDER BY u.short_name, d.name;
```

Expected result: 116 total courses (63 UH + 53 HCC)
