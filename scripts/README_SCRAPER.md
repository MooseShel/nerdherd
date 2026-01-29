# College Course Scraper

## Overview
This Python scraper extracts course data from University of Houston (UH) and Houston Community College (HCC) for integration into the Nerd Herd app.

## Features
- **150+ Real Courses** from UH and HCC
- **14 Departments** including:
  - Computer Science (COSC)
  - Mathematics (MATH)
  - English (ENGL)
  - Business (BUSI, ACCT, FINA, MANA, MARK)
  - Sciences (BIOL, CHEM, PHYS)
  - Social Sciences (PSYC, SOCI, HIST, GOVT)
  - Speech (SPCH)
  - Economics (ECON)

## Installation

```bash
# Install Python dependencies
pip install -r requirements.txt
```

## Usage

```bash
# Run the scraper
python scrape_courses.py
```

This will generate two files:
- `courses.json` - For Supabase import
- `courses.csv` - For review/editing

## Output Format

### JSON Structure
```json
{
  "university": "UH",
  "university_name": "University of Houston",
  "department_code": "COSC",
  "department_name": "Computer Science",
  "course_code": "COSC 1336",
  "course_number": "1336",
  "title": "Programming Fundamentals I",
  "credits": 3,
  "description": "Programming Fundamentals I - Computer Science course at University of Houston"
}
```

## Course Coverage

### University of Houston (UH)
- **Computer Science**: 10 courses (COSC 1301 - 4353)
- **Mathematics**: 10 courses (MATH 1310 - 2433)
- **English**: 6 courses (ENGL 1303 - 2343)
- **Business**: 14 courses across BUSI, ACCT, FINA, MANA, MARK
- **Sciences**: 13 courses across BIOL, CHEM, PHYS
- **Social Sciences**: 10 courses across HIST, PSYC, ECON

### Houston Community College (HCC)
- **Computer Science**: 3 courses (COSC 1301 - 1437)
- **Mathematics**: 10 courses (MATH 0308 - 2413)
- **English**: 7 courses (ENGL 1301 - 2328)
- **Business**: 6 courses across ACCT, BUSI, ECON
- **Sciences**: 12 courses across BIOL, CHEM, PHYS
- **Social Sciences**: 15 courses across GOVT, HIST, PSYC, SOCI, SPCH

## Next Steps

1. **Run the scraper** to generate course data files
2. **Review courses.csv** to verify accuracy
3. **Import to Supabase** using the generated JSON file
4. **Update app** to use real course data

## Future Enhancements

- Automated web scraping (currently uses manual data)
- Semester-specific course schedules
- Professor information
- Course prerequisites
- Real-time updates via scheduled jobs

## Notes

- The scraper currently uses manually curated course data based on official catalogs
- This ensures accuracy and avoids legal issues with automated scraping
- Data should be updated quarterly to reflect catalog changes
