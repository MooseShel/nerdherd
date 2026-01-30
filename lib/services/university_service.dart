import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/university.dart';
import '../models/course.dart';
import 'logger_service.dart';

class UniversityService {
  final SupabaseClient _supabase;

  UniversityService(this._supabase);

  // --- Fetching ---

  Future<University?> findUniversityByEmail(String email) async {
    try {
      final domain = email.split('@').last.toLowerCase();
      final data = await _supabase
          .from('universities')
          .select()
          .eq('domain', domain)
          .maybeSingle();

      if (data == null) return null;
      return University.fromJson(data);
    } catch (e) {
      logger.error("Error finding university by email", error: e);
      return null;
    }
  }

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
      var queryBuilder = _supabase
          .from('courses')
          .select()
          .eq('university_id', universityId)
          .eq('is_active', true);

      if (query != null && query.isNotEmpty) {
        // Search by course_code OR title
        queryBuilder =
            queryBuilder.or('course_code.ilike.%$query%,title.ilike.%$query%');
      }

      final data =
          await queryBuilder.order('course_code', ascending: true).limit(100);
      return (data as List).map((e) => Course.fromJson(e)).toList();
    } catch (e) {
      logger.error("Error fetching courses", error: e);
      return [];
    }
  }

  Future<List<Course>> getMyCourses(String userId) async {
    try {
      // Join user_courses with courses
      final data = await _supabase.from('user_courses').select('''
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
        await _supabase.from('user_courses').insert({
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
          .from('user_courses')
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
      final classLabels = courses.map((c) => c.courseCode).toList();
      await _supabase
          .from('profiles')
          .update({'current_classes': classLabels}).eq('user_id', userId);
    } catch (e) {
      logger.warning("Failed to sync profile classes", error: e);
    }
  }

  // --- Simulation / Seeding ---
  // REMOVED: Fake university seeding (Hogwarts, Nerd Herd U)
  // Real universities (UH, HCC) are now seeded via SQL migration scripts

  Future<void> seedSimulationData() async {
    // No-op: Real data is managed via database migrations
    logger.info("✅ Using real university data from database migration.");
  }
}
