import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/university.dart';

import '../providers/university_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart'; // NEW
import '../services/haptic_service.dart';

class CourseImportPage extends ConsumerStatefulWidget {
  final University university;

  const CourseImportPage({super.key, required this.university});

  @override
  ConsumerState<CourseImportPage> createState() => _CourseImportPageState();
}

class _CourseImportPageState extends ConsumerState<CourseImportPage> {
  final _searchController = TextEditingController();
  String _query = "";
  // Track changes locally before saving
  final Set<String> _pendingAdd = {};
  final Set<String> _pendingRemove = {};

  void _toggleCourse(String courseId, bool isAlreadyEnrolled) {
    hapticService.selectionClick();
    setState(() {
      if (isAlreadyEnrolled) {
        // Handling removal of an existing course
        if (_pendingRemove.contains(courseId)) {
          _pendingRemove.remove(courseId); // Undo removal
        } else {
          _pendingRemove.add(courseId); // Mark for removal
        }
      } else {
        // Handling addition of a new course
        if (_pendingAdd.contains(courseId)) {
          _pendingAdd.remove(courseId); // Undo addition
        } else {
          _pendingAdd.add(courseId); // Mark for addition
        }
      }
    });
  }

  Future<void> _processChanges() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    if (_pendingAdd.isEmpty && _pendingRemove.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No changes selected")));
      return;
    }

    try {
      final service = ref.read(universityServiceProvider);
      int added = 0;
      int removed = 0;

      // Process Removals
      for (final cid in _pendingRemove) {
        await service.unenroll(user.id, cid);
        removed++;
      }

      // Process Additions
      for (final cid in _pendingAdd) {
        await service.enroll(user.id, cid);
        added++;
      }

      if (mounted) {
        hapticService.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Updated: +$added added, -$removed removed."),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ));
        // Refresh profile classes
        ref.invalidate(myEnrollmentsProvider);
        ref.invalidate(myProfileProvider);

        // Navigation: Pop back to settings or map
        // If we came from Settings, one pop might be enough?
        // Let's just pop once to return to where we came from
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near bottom
      final params = (universityId: widget.university.id, query: _query);
      ref.read(paginatedCourseProvider(params).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = (universityId: widget.university.id, query: _query);
    final paginatedState = ref.watch(paginatedCourseProvider(params));

    final myEnrollmentsAsync = ref.watch(myEnrollmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.university.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search courses (e.g. CS101)",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
        ),
      ),
      body: myEnrollmentsAsync.when(
        data: (myCourses) {
          final enrolledIds = myCourses.map((c) => c.id).toSet();
          final courses = paginatedState.courses;

          if (courses.isEmpty && paginatedState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (courses.isEmpty && !paginatedState.isLoading) {
            return const Center(
                child: Text("No courses found matching your search."));
          }

          if (paginatedState.error != null && courses.isEmpty) {
            return Center(child: Text("Error: ${paginatedState.error}"));
          }

          return ListView.builder(
            controller: _scrollController,
            itemCount: courses.length + (paginatedState.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == courses.length) {
                // Bottom loading indicator
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final course = courses[index];
              final isOriginallyEnrolled = enrolledIds.contains(course.id);

              // Determine current state based on pending actions
              bool showEnrolled = isOriginallyEnrolled;
              if (isOriginallyEnrolled && _pendingRemove.contains(course.id)) {
                showEnrolled = false; // Marked for removal
              }
              if (!isOriginallyEnrolled && _pendingAdd.contains(course.id)) {
                showEnrolled = true; // Marked for addition
              }

              return ListTile(
                title: Text(course.courseCode,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(course.title),
                trailing: _buildStatusIcon(isOriginallyEnrolled, showEnrolled),
                onTap: () => _toggleCourse(course.id, isOriginallyEnrolled),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text("Error loading enrollments: $err")),
      ),
      floatingActionButton:
          (_pendingAdd.isNotEmpty || _pendingRemove.isNotEmpty)
              ? FloatingActionButton.extended(
                  onPressed: _processChanges,
                  label: const Text("Save Changes"),
                  icon: const Icon(Icons.save),
                )
              : null,
    );
  }

  Widget _buildStatusIcon(bool original, bool current) {
    if (original && !current) {
      // Marked for removal
      return Icon(Icons.remove_circle_outline,
          color: Theme.of(context).colorScheme.error);
    } else if (!original && current) {
      // Marked for addition
      return Icon(Icons.add_circle,
          color: Theme.of(context).colorScheme.tertiary);
    } else if (original && current) {
      // Enrolled and staying enrolled
      return Icon(Icons.check_circle,
          color: Theme.of(context).colorScheme.secondary);
    } else {
      // Not enrolled
      return const Icon(Icons.circle_outlined);
    }
  }
}
