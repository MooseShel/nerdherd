import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

// Usage: dart run scripts/scrape_full_catalog.dart

class Course {
  final String university;
  final String deptCode;
  final String deptName;
  final String courseCode;
  final String courseNumber;
  final String title;
  final int credits;
  final String description;

  Course({
    required this.university,
    required this.deptCode,
    required this.deptName,
    required this.courseCode,
    required this.courseNumber,
    required this.title,
    required this.credits,
    required this.description,
  });
}

void main() async {
  final scraper = CatalogScraper();
  print('Starting scrape...');

  // Scrape UH
  await scraper.scrapeUH();

  // Save to SQL
  if (scraper.courses.isNotEmpty) {
    await scraper.saveToSql('database/import_all_majors.sql');
    print('Done! Generated database/import_all_majors.sql');
  } else {
    print('No courses found.');
  }
}

class CatalogScraper {
  final List<Course> courses = [];
  final String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  // ==========================================
  // UH Scraper (Acalog System)
  // ==========================================
  Future<void> scrapeUH() async {
    print("Scraping University of Houston (Acalog)...");
    const baseUrl = 'https://publications.uh.edu';

    // 1. Detect latest catalog ID (catoid)
    // We start by fetching the main catalog page and looking for the "Undergraduate Catalog" link or ID
    // Dynamic logic: hitting the preview URL usually redirects to content.php?catoid=X
    int? catoid;

    try {
      final initialRes = await http.get(
        Uri.parse('$baseUrl/preview/2025-2026/undergraduate-catalog'),
        headers: {'User-Agent': userAgent},
      );

      // If redirected, the new URL contains catoid
      // Dart http client follows redirects by default? Yes.
      // But we might need the *location* if it's a 302.
      // Wait, let's just regex the content of the page, usually links to itself exist.

      // Better strategy: Use the search endpoint which is robust.
      // Search URL: /ajax/preview_filter.php
      // But we need a valid catoid first.

      // Let's hardcode a fallback based on typical UH IDs if detection fails
      // 2024-2025 was 52. 2025-2026 likely 54 or similar.
      // Let's look for "catoid=" in the initialRes.body
      final catoidMatch = RegExp(r'catoid=(\d+)').firstMatch(initialRes.body);
      if (catoidMatch != null) {
        catoid = int.parse(catoidMatch.group(1)!);
        print("Detected UH Catoid: $catoid");
      } else {
        // Try checking the request URL if it redirected
        // Not easily accessible in simple http.get without more logic.
        print("Warning: Could not auto-detect catoid. Trying fallback (54).");
        catoid = 54;
      }

      // 2. Fetch all courses using the Filter Endpoint
      // This is the "All Courses" search trick for Acalog systems
      // URL: /ajax/preview_filter.php
      // Params: catoid=X, cpage=Y, location=3 (Courses), filter%5Bexact_match%5D=1 (optional)

      // Iterate pages
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        print("Fetching Page $page...");
        final pageUrl = Uri.parse(
            '$baseUrl/ajax/preview_filter.php?catoid=$catoid&cpage=$page&location=3');

        final res = await http.get(pageUrl, headers: {'User-Agent': userAgent});

        if (res.statusCode != 200) {
          print("Failed to fetch page $page: ${res.statusCode}");
          break;
        }

        final document = parse(res.body);

        // Acalog listing structure: <a href="preview_course_nopop.php?catoid=X&coid=Y" ...>Code Title</a>
        final links = document.querySelectorAll('a[href*="preview_course"]');

        if (links.isEmpty) {
          // Check if we hit the end
          print("No courses on page $page. Stopping.");
          break;
        }

        int newCourses = 0;

        for (final link in links) {
          final text = link.text.trim();
          // Expected format: "ACCT 2301 - Principles of financial accounting"
          // Regex: ^([A-Z]{3,4})\s(\d{4})\s-\s(.*)$

          final match = RegExp(r'^([A-Z]{3,4})\s(\d{4}[A-Za-z]?)\s-\s(.*)$')
              .firstMatch(text);
          if (match != null) {
            final deptCode = match.group(1)!;
            final courseNum = match.group(2)!;
            final title = match.group(3)!;

            // Get Credits?
            // Often "Credit Hours: 3.0" text is outside the link in the <li> or <p> or <td>
            // In AJAX view, it's often just a list of links.
            // We might default to 3 if unavailable, or attempt one level up.
            int credits = 3;

            // Try to find text "Credit Hours: X" in the parent element
            final parentText = link.parent?.text ?? "";
            final credMatch =
                RegExp(r'Credit Hours:?\s*([\d\.]+)').firstMatch(parentText);
            if (credMatch != null) {
              credits = double.parse(credMatch.group(1)!).round();
            }

            final desc = "$title - $deptCode course at University of Houston";

            courses.add(Course(
                university: 'UH',
                deptCode: deptCode,
                deptName: deptCode, // Placeholder, usually fine
                courseCode: "$deptCode $courseNum",
                courseNumber: courseNum,
                title: title,
                credits: credits,
                description: desc));
            newCourses++;
          }
        }

        print("  Found $newCourses courses on page $page");

        if (newCourses == 0) {
          hasMore = false;
        } else {
          // Safety limit
          if (page > 50) hasMore = false;
          page++;
          sleep(const Duration(milliseconds: 500)); // Be nice
        }
      }
    } catch (e) {
      print("Error scraping UH: $e");
    }
  }

  // ==========================================
  // SQL Generator
  // ==========================================
  Future<void> saveToSql(String filename) async {
    final file = File(filename);
    final sink = file.openWrite();

    sink.writeln("-- Full Catalog Import for All Majors");
    sink.writeln("-- Generated by scrape_full_catalog.dart");
    sink.writeln("DO \$\$");
    sink.writeln("DECLARE");
    sink.writeln("  uh_id UUID;");
    sink.writeln("  hcc_id UUID;");
    sink.writeln("  dept_id UUID;");
    sink.writeln("BEGIN");
    sink.writeln(
        "  SELECT id INTO uh_id FROM universities WHERE short_name = 'UH';");
    sink.writeln(
        "  SELECT id INTO hcc_id FROM universities WHERE short_name = 'HCCS';");
    sink.writeln("");

    // Group by Uni -> Dept
    final Map<String, Map<String, List<Course>>> tree = {};

    for (final c in courses) {
      tree.putIfAbsent(c.university, () => {});
      tree[c.university]!.putIfAbsent(c.deptCode, () => []);
      tree[c.university]![c.deptCode]!.add(c);
    }

    for (final uniKey in tree.keys) {
      final uniVar = (uniKey == 'UH') ? 'uh_id' : 'hcc_id';

      for (final deptKey in tree[uniKey]!.keys) {
        final deptCourses = tree[uniKey]![deptKey]!;

        // Clean strings
        final deptName = deptKey.replaceAll("'", "''");

        sink.writeln("  -- $uniKey: $deptKey");
        sink.writeln(
            "  INSERT INTO departments (university_id, name, code) VALUES ($uniVar, '$deptName', '$deptKey') ON CONFLICT (university_id, code) DO NOTHING;");
        sink.writeln(
            "  SELECT id INTO dept_id FROM departments WHERE university_id = $uniVar AND code = '$deptKey';");

        sink.writeln(
            "  INSERT INTO courses (university_id, department_id, course_code, course_number, title, credits, description) VALUES");

        final List<String> values = [];
        for (final c in deptCourses) {
          final cCode = c.courseCode.replaceAll("'", "''");
          final cNum = c.courseNumber.replaceAll("'", "''");
          final title = c.title.replaceAll("'", "''");
          final desc = c.description.replaceAll("'", "''");

          values.add(
              "    ($uniVar, dept_id, '$cCode', '$cNum', '$title', ${c.credits}, '$desc')");
        }

        sink.writeln(values.join(",\n"));
        sink.writeln(
            "  ON CONFLICT (university_id, course_code) DO UPDATE SET title = EXCLUDED.title, credits = EXCLUDED.credits, description = EXCLUDED.description;");
        sink.writeln("");
      }
    }

    sink.writeln("END \$\$;");
    await sink.close();
  }
}
