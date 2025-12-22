import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/university.dart';
import '../models/course.dart';
import 'logger_service.dart';

class UniversityService {
  final SupabaseClient _supabase;

  UniversityService(this._supabase);

  // --- Fetching ---

  Future<List<University>> searchUniversities(String query) async {
    try {
      var queryBuilder = _supabase.from('universities').select();

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('name', '%$query%');
      }

      final data = await queryBuilder.order('name', ascending: true).limit(50);
      return (data as List).map((e) => University.fromJson(e)).toList();
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        logger.error(
            "🚨 Missing 'universities' table! Please run the SQL migration script (20251217000000_university_schema.sql).");
      } else {
        logger.error("Error searching universities", error: e);
      }
      return [];
    }
  }

  Future<University?> getUniversityById(String id) async {
    try {
      final data =
          await _supabase.from('universities').select().eq('id', id).single();
      return University.fromJson(data);
    } catch (e) {
      logger.error("Error fetching university by ID", error: e);
      return null;
    }
  }

  Future<List<Course>> getCourses(String universityId, {String? query}) async {
    try {
      var queryBuilder =
          _supabase.from('courses').select().eq('university_id', universityId);

      if (query != null && query.isNotEmpty) {
        // Search by code OR title
        queryBuilder =
            queryBuilder.or('code.ilike.%$query%,title.ilike.%$query%');
      }

      final data = await queryBuilder.order('code', ascending: true).limit(50);
      return (data as List).map((e) => Course.fromJson(e)).toList();
    } catch (e) {
      logger.error("Error fetching courses", error: e);
      return [];
    }
  }

  Future<List<Course>> getMyCourses(String userId) async {
    try {
      // Join enrollments with courses
      final data = await _supabase.from('enrollments').select('''
            course_id,
            courses:course_id (*)
          ''').eq('user_id', userId);

      return (data as List).map((e) => Course.fromJson(e['courses'])).toList();
    } catch (e) {
      logger.error("Error fetching my courses", error: e);
      return [];
    }
  }

  // --- Actions ---

  Future<void> setUniversity(String userId, String universityId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'university_id': universityId}).eq('user_id', userId);
    } catch (e) {
      logger.error("Error setting university", error: e);
      rethrow;
    }
  }

  Future<void> enroll(String userId, String courseId) async {
    try {
      // Use INSERT to avoid triggering UPDATE RLS policies.
      try {
        await _supabase.from('enrollments').insert({
          'user_id': userId,
          'course_id': courseId,
        });
      } catch (e) {
        // Ignore duplicate key error (already enrolled)
        if (e is PostgrestException && e.code == '23505') {
          // Already enrolled, do nothing
        } else {
          rethrow;
        }
      }
      // Also update the profile's "current_classes" array for backward compatibility/quick display
      // Ideally, we migrate away from that, but for now we sync it.
      await _syncProfileClasses(userId);
    } catch (e) {
      logger.error("Error enrolling in course", error: e);
      rethrow;
    }
  }

  Future<void> unenroll(String userId, String courseId) async {
    try {
      await _supabase
          .from('enrollments')
          .delete()
          .eq('user_id', userId)
          .eq('course_id', courseId);
      await _syncProfileClasses(userId);
    } catch (e) {
      logger.error("Error unenrolling from course", error: e);
      rethrow;
    }
  }

  // Syncs the relation-based enrollments to the profile's text-array 'current_classes'
  Future<void> _syncProfileClasses(String userId) async {
    try {
      final courses = await getMyCourses(userId);
      final classLabels = courses.map((c) => c.code).toList();
      await _supabase
          .from('profiles')
          .update({'current_classes': classLabels}).eq('user_id', userId);
    } catch (e) {
      logger.warning("Failed to sync profile classes", error: e);
    }
  }

  // --- Simulation / Seeding ---

  Future<void> seedSimulationData() async {
    try {
      // 1. Seed Nerd Herd University (Default)
      final nerdCheck = await _supabase
          .from('universities')
          .select()
          .eq('name', 'Nerd Herd University')
          .limit(1);

      if ((nerdCheck as List).isEmpty) {
        logger.info("🌱 Seeding Nerd Herd University...");
        final uniRes = await _supabase
            .from('universities')
            .insert({
              'name': 'Nerd Herd University',
              'domain': 'nerdherd.edu',
              'logo_url':
                  'https://img.freepik.com/free-vector/gradient-high-school-logo-design_23-2149626932.jpg'
            })
            .select()
            .single();

        final uniId = uniRes['id'];

        // Create Courses for Nerd Herd U
        final courses = [
          {
            'code': 'CS101',
            'title': 'Intro to Computer Science',
            'term': 'Fall 2024'
          },
          {'code': 'CS201', 'title': 'Data Structures', 'term': 'Fall 2024'},
          {'code': 'MATH101', 'title': 'Calculus I', 'term': 'Fall 2024'},
          {'code': 'PHYS101', 'title': 'Physics I', 'term': 'Fall 2024'},
          {
            'code': 'ENG101',
            'title': 'English Composition',
            'term': 'Fall 2024'
          },
          {'code': 'ART101', 'title': 'Art History', 'term': 'Fall 2024'},
        ];

        for (var c in courses) {
          await _supabase.from('courses').insert({
            'university_id': uniId,
            ...c,
          });
        }
        logger.info("🌱 Nerd Herd University Seeded!");
      }

      // 2. Seed Hogwarts (Requested Feature)
      final hogwartsCheck = await _supabase
          .from('universities')
          .select()
          .eq('name', 'Hogwarts School of Witchcraft and Wizardry')
          .limit(1);

      if ((hogwartsCheck as List).isEmpty) {
        logger.info("🧙‍♂️ Seeding Hogwarts...");
        final hogRes = await _supabase
            .from('universities')
            .insert({
              'name': 'Hogwarts School of Witchcraft and Wizardry',
              'domain': 'hogwarts.edu',
              'logo_url': 'assets/images/hogwarts_icon.jpg'
            })
            .select()
            .single();

        final hogId = hogRes['id'];
        final hogCourses = [
          {'code': 'POTIONS101', 'title': 'Potions', 'term': 'Year 1'},
          {
            'code': 'DADA101',
            'title': 'Defense Against the Dark Arts',
            'term': 'Year 1'
          },
          {'code': 'CHARMS101', 'title': 'Charms', 'term': 'Year 1'},
          {'code': 'TRANS101', 'title': 'Transfiguration', 'term': 'Year 1'},
          {'code': 'HERB101', 'title': 'Herbology', 'term': 'Year 1'},
          {'code': 'ASTRO101', 'title': 'Astronomy', 'term': 'Year 1'},
          {'code': 'HISTM101', 'title': 'History of Magic', 'term': 'Year 1'},
          {'code': 'FLY101', 'title': 'Flying', 'term': 'Year 1'},
        ];

        for (var c in hogCourses) {
          await _supabase.from('courses').insert({
            'university_id': hogId,
            ...c,
          });
        }
        logger.info("🧙‍♂️ Hogwarts Seeded!");
      }
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        logger.error(
            "🚨 Missing 'universities' table! Cannot seed data. Please run the SQL migration script.");
      } else {
        logger.error("Seeding failed", error: e);
      }
    }
  }
}
