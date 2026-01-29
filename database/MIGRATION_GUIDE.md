# Real College Course Integration - Migration Guide

## Overview
This guide walks you through migrating from fake "Hogwarts" data to real University of Houston and Houston Community College courses.

## Prerequisites
- Supabase project with admin access
- Python 3.x installed (for running the scraper)
- Backup of current database (recommended)

## Step-by-Step Migration

### Step 1: Generate Course Data
```bash
cd scripts
pip install -r requirements.txt
python scrape_courses.py
```

This creates:
- `courses.json` - For Supabase import
- `courses.csv` - For review

**Output**: 150+ real courses from UH and HCC

### Step 2: Run Database Migration
1. Open Supabase SQL Editor
2. Run `database/migrate_real_courses.sql`
3. Verify tables created:
   - `universities`
   - `departments`
   - `courses`
   - `user_courses`

### Step 3: Import Course Data

**Option A: CSV Import (Recommended)**
1. Go to Supabase Dashboard > Table Editor
2. Select `courses` table
3. Click "Insert" > "Import data from CSV"
4. Upload `scripts/courses.csv`
5. Map columns and import

**Option B: SQL Import**
1. Use `database/import_courses.sql` as a template
2. Modify for your specific courses
3. Run in SQL Editor

### Step 4: Verify Data
Run this query in SQL Editor:
```sql
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

Expected output: ~150 courses across 14 departments

### Step 5: Update Flutter App
The app code changes will be handled separately. This includes:
- Updating `UniversityService.dart`
- Creating `CourseSelector` widget
- Updating onboarding flow
- Adding course search functionality

### Step 6: User Migration
For existing users with "Hogwarts" courses:
1. Show migration prompt on app launch
2. Guide through new course selection
3. Archive old data
4. Update user profiles

## Rollback Plan
If something goes wrong:
```sql
-- Drop new tables
DROP TABLE IF EXISTS user_courses CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS universities CASCADE;

-- Restore from backup
-- (Use your backup restoration method)
```

## Testing Checklist
- [ ] Universities table has 2 entries (UH, HCC)
- [ ] Departments table has ~28 entries
- [ ] Courses table has 150+ entries
- [ ] Search function works: `SELECT * FROM search_courses('programming')`
- [ ] RLS policies allow public read access
- [ ] User course enrollment works

## Troubleshooting

### Issue: CSV import fails
**Solution**: Check column mapping, ensure UUIDs are generated correctly

### Issue: Foreign key violations
**Solution**: Ensure universities and departments are inserted before courses

### Issue: Duplicate course codes
**Solution**: Check for conflicts in course_code, use ON CONFLICT DO NOTHING

## Next Steps
After successful migration:
1. Update Flutter app code
2. Deploy new app version
3. Monitor user migration progress
4. Gather feedback on course selection UX

## Support
For issues, check:
- Supabase logs for SQL errors
- App logs for Flutter errors
- User feedback for UX issues
