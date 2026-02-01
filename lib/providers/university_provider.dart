import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/university_service.dart';
import '../models/university.dart';
import '../models/course.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

part 'university_provider.g.dart';

// 1. Service Provider
@Riverpod(keepAlive: true)
UniversityService universityService(Ref ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return UniversityService(supabase);
}

// 2. Search Universities
@riverpod
Future<List<University>> searchUniversities(Ref ref, String query) async {
  // if (query.isEmpty) return []; // Removed to allow listing all
  final service = ref.watch(universityServiceProvider);
  return service.searchUniversities(query);
}

// 3. Course Catalog (University-specific)
@riverpod
Future<List<Course>> courseCatalog(Ref ref,
    {required String universityId, String? query}) async {
  final service = ref.watch(universityServiceProvider);
  return service.getCourses(universityId, query: query);
}

// 4. My Enrollments
@riverpod
Future<List<Course>> myEnrollments(Ref ref) async {
  final service = ref.watch(universityServiceProvider);
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return service.getMyCourses(user.id);
}

// 5. Available Subjects
final availableSubjectsProvider = FutureProvider<List<String>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase.rpc('get_available_subjects');
  final List<dynamic> data = response as List<dynamic>;
  return data.map((e) => e['subject'] as String).toList();
});

// 6. Get University by ID
@riverpod
Future<University?> universityById(Ref ref, String id) async {
  final service = ref.watch(universityServiceProvider);
  return service.getUniversityById(id);
}

// 7. My Selected University (Reactive)
@riverpod
Future<University?> myUniversity(Ref ref) async {
  final profile = ref.watch(myProfileProvider).value;
  if (profile?.universityId == null) return null;

  // Directly use the service to get the latest data
  final service = ref.watch(universityServiceProvider);
  return service.getUniversityById(profile!.universityId!);
}

// 8. Paginated Course Catalog (Manual StateNotifier for Infinite Scroll)
class PaginatedCourseState {
  final List<Course> courses;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  PaginatedCourseState({
    this.courses = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  PaginatedCourseState copyWith({
    List<Course>? courses,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return PaginatedCourseState(
      courses: courses ?? this.courses,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class PaginatedCourseNotifier extends StateNotifier<PaginatedCourseState> {
  final UniversityService _service;
  final String universityId;
  final String query;

  static const int _limit = 50;

  PaginatedCourseNotifier(this._service,
      {required this.universityId, required this.query})
      : super(PaginatedCourseState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newCourses = await _service.getCourses(
        universityId,
        query: query,
        limit: _limit,
        offset: 0,
      );
      state = state.copyWith(
        courses: newCourses,
        isLoading: false,
        hasMore: newCourses.length >= _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    try {
      final currentLength = state.courses.length;
      final newCourses = await _service.getCourses(
        universityId,
        query: query,
        limit: _limit,
        offset: currentLength,
      );

      state = state.copyWith(
        courses: [...state.courses, ...newCourses],
        isLoading: false,
        hasMore: newCourses.length >= _limit,
      );
    } catch (e) {
      // On error, just stop loading, keep old data
      state = state.copyWith(isLoading: false);
    }
  }
}

final paginatedCourseProvider = StateNotifierProvider.family.autoDispose<
    PaginatedCourseNotifier,
    PaginatedCourseState,
    ({String universityId, String query})>(
  (ref, params) {
    final service = ref.watch(universityServiceProvider);
    return PaginatedCourseNotifier(service,
        universityId: params.universityId, query: params.query);
  },
);
