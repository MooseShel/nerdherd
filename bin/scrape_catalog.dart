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
    final client = http.Client();

    // 0. Initialize Headers
    Map<String, String> headers = {
      'User-Agent': userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    };

    // 1. Get Home Page to find Catoid
    String? catoid;
    String? navoid;

    try {
      print("Connecting to $baseUrl...");
      final res = await client.get(Uri.parse(baseUrl), headers: headers);
      if (res.statusCode != 200) {
        print("Root URL failed: ${res.statusCode}");
        return;
      }

      final doc = parse(res.body);

      // Smart Detection: Look for link text specific to current catalog
      // "2025-2026 Undergraduate Catalog"
      // <a href="index.php?catoid=54">2025-2026 Undergraduate Catalog</a>
      final catalogLinks = doc.querySelectorAll('a');
      for (final link in catalogLinks) {
        if (link.text.contains("2025-2026") &&
            link.text.contains("Undergraduate")) {
          final href = link.attributes['href'];
          if (href != null && href.contains('catoid=')) {
            final val = RegExp(r'catoid=(\d+)').firstMatch(href)?.group(1);
            if (val != null) {
              catoid = val;
              print("Identified 2025-2026 Catalog ID: $catoid");
              break;
            }
          }
        }
      }

      if (catoid == null) {
        // Fallback: Use known good IDs.
        // 52 = 2024-2025
        catoid = "52";
        print(
            "Using Fallback Catoid: $catoid (Could not find specific 2025-2026 link)");
      } else if (catoid == "19") {
        // Known bad old archive
        catoid = "52";
        print("Overriding detected old catalog (19) with fallback (52).");
      }

      // 2. Find "Course Descriptions" Navoid
      // We need to hit index.php?catoid=X to find the sidebar links
      print("Looking for Course Descriptions in Catalog $catoid...");
      final indexUrl = Uri.parse('$baseUrl/index.php?catoid=$catoid');

      final indexRes = await client.get(indexUrl, headers: headers);
      final indexDoc = parse(indexRes.body);

      // DEBUG: Print all links that might be relevant
      final allLinks = indexDoc.querySelectorAll('a');
      print("Scanning ${allLinks.length} links on catalog homepage...");
      bool foundAny = false;
      for (final link in allLinks) {
        if (link.text.contains("Course")) {
          print(
              " - [Potential Match] Text: '${link.text.trim()}' Href: '${link.attributes['href']}'");
          foundAny = true;
        }
      }
      if (!foundAny) {
        print("WARNING: No links containing 'Course' found on homepage!");
      }

      // Find link with text "Course Descriptions"
      final validLinks = indexDoc.querySelectorAll('a');
      for (final link in validLinks) {
        // Relaxed matching: "Course Descriptions" or just "Courses"
        if (link.text.contains("Course Descriptions") ||
            link.text == "Courses") {
          final href = link.attributes['href'];
          if (href != null && href.contains('navoid=')) {
            final navMatch = RegExp(r'navoid=(\d+)').firstMatch(href);
            if (navMatch != null) {
              navoid = navMatch.group(1);
              print("Found Navoid: $navoid (from '${link.text.trim()}')");
              break;
            }
          }
        }
      }

      // If we still don't have navoid, try a known navoid for catoid 52?
      if (navoid == null && catoid == "52") {
        navoid = "19036";
        print(
            "Using Fallback Navoid: $navoid (Known for Catoid 52 - MIGHT BE WRONG)");
      }

      if (navoid == null) {
        print("Could not find 'Course Descriptions' link. Cannot crawl.");
        return;
      }
    } catch (e) {
      print("Connection error: $e");
      return;
    }

    // 3. Crawl Content Pages (content.php)
    // content.php?catoid=X&navoid=Y&cpage=Z
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      print("Fetching Page $page...");
      final pageUrl = Uri.parse(
          '$baseUrl/content.php?catoid=$catoid&navoid=$navoid&cpage=$page');
      print("URL: $pageUrl");

      final res = await client.get(pageUrl, headers: headers);
      if (res.statusCode != 200) {
        print("Failed to fetch page $page: ${res.statusCode}");
        break;
      }

      final doc = parse(res.body);

      // Find course links
      final courseLinks = doc.querySelectorAll('a[href*="preview_course"]');

      if (courseLinks.isEmpty) {
        print("No courses on page $page.");

        // DEBUG: Dump body snippet
        final htmlSample = res.body.length > 500
            ? res.body.substring(0, 500)
            : res.body; // First 500 chars
        print("--- HTML SAMPLE ---");
        // Remove newlines for cleaner log
        print(htmlSample.replaceAll('\n', ' ').replaceAll('\r', ' '));
        print("--- END SAMPLE ---");

        if (page > 1) {
          hasMore = false;
        } else {
          break;
        }
      }

      int newCourses = 0;
      for (final link in courseLinks) {
        final text = link.text.trim();
        // Regex: ^([A-Z]{3,4})\s(\d{4}[A-Za-z]?)\s-\s(.*)$
        final match = RegExp(r'^([A-Z]{3,4})\s(\d{4}[A-Za-z]?)\s-\s(.*)$')
            .firstMatch(text);

        if (match != null) {
          final deptCode = match.group(1)!;
          final courseNum = match.group(2)!;
          final title = match.group(3)!;

          final desc = "$title - $deptCode course at University of Houston";

          // Get Credits from parent text if possible (often immediately following the link)
          int credits = 3;
          // In content.php, structure is often:
          // <td class="width"> <a...>COURSE</a> <br> Description... </td>
          // We can try to grab the parent's text.
          final parentText = link.parent?.text ?? "";
          final credMatch =
              RegExp(r'Credit Hours:?\s*([\d\.]+)').firstMatch(parentText);
          if (credMatch != null) {
            credits = double.parse(credMatch.group(1)!).round();
          }

          courses.add(Course(
              university: 'UH',
              deptCode: deptCode,
              deptName: deptCode,
              courseCode: "$deptCode $courseNum",
              courseNumber: courseNum,
              title: title,
              credits: credits,
              description: desc));
          newCourses++;
        }
      }

      print("  Found $newCourses courses on page $page");

      if (newCourses == 0 && page > 5) {
        hasMore = false;
      } else {
        // Check for "Next" link or max pages
        // Simple heuristic: just increment until empty
        if (page > 100) hasMore = false;
        page++;
        sleep(const Duration(milliseconds: 200));
      }
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
