import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/university_service.dart';
import '../models/university.dart';
import '../models/course.dart';
import 'auth_provider.dart';

part 'university_provider.g.dart';

// 1. Service Provider
@Riverpod(keepAlive: true)
UniversityService universityService(UniversityServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return UniversityService(supabase);
}

// 2. Search Universities
@riverpod
Future<List<University>> searchUniversities(
    SearchUniversitiesRef ref, String query) async {
  if (query.isEmpty) return [];
  final service = ref.watch(universityServiceProvider);
  return service.searchUniversities(query);
}

// 3. Course Catalog (University-specific)
@riverpod
Future<List<Course>> courseCatalog(CourseCatalogRef ref,
    {required String universityId, String? query}) async {
  final service = ref.watch(universityServiceProvider);
  return service.getCourses(universityId, query: query);
}

// 4. My Enrollments
@riverpod
Future<List<Course>> myEnrollments(MyEnrollmentsRef ref) async {
  final service = ref.watch(universityServiceProvider);
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return service.getMyCourses(user.id);
}
