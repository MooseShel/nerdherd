import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/university.dart';

import '../providers/university_provider.dart';
import '../providers/auth_provider.dart';
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
  final Set<String> _pendingEnrollments = {};

  void _toggleCourse(String courseId) {
    hapticService.selectionClick();
    setState(() {
      if (_pendingEnrollments.contains(courseId)) {
        _pendingEnrollments.remove(courseId);
      } else {
        _pendingEnrollments.add(courseId);
      }
    });
  }

  Future<void> _processEnrollments() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    if (_pendingEnrollments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one course")));
      return;
    }

    try {
      final service = ref.read(universityServiceProvider);
      int count = 0;
      for (final cid in _pendingEnrollments) {
        await service.enroll(user.id, cid);
        count++;
      }

      if (mounted) {
        hapticService.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Success! Added $count courses."),
          backgroundColor: Colors.green,
        ));
        // Refresh profile classes
        ref.invalidate(myEnrollmentsProvider);
        Navigator.pop(context); // Back to university selection
        Navigator.pop(context); // Back to profile
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogAsync = ref.watch(courseCatalogProvider(
        universityId: widget.university.id, query: _query));
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

          return catalogAsync.when(
            data: (courses) {
              if (courses.isEmpty) {
                return const Center(
                    child: Text("No courses found matching your search."));
              }
              return ListView.builder(
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  final isAlreadyEnrolled = enrolledIds.contains(course.id);
                  final isSelected = _pendingEnrollments.contains(course.id);

                  return ListTile(
                    title: Text(course.code,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(course.title),
                    trailing: isAlreadyEnrolled
                        ? const Chip(
                            label: Text("Enrolled"),
                            visualDensity: VisualDensity.compact)
                        : isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : const Icon(Icons.circle_outlined),
                    onTap: isAlreadyEnrolled
                        ? null // Prevent re-selecting enrolled courses
                        : () => _toggleCourse(course.id),
                    enabled: !isAlreadyEnrolled,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text("Error: $err")),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text("Error loading enrollments: $err")),
      ),
      floatingActionButton: _pendingEnrollments.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _processEnrollments,
              label: Text("Import (${_pendingEnrollments.length})"),
              icon: const Icon(Icons.save_alt),
            )
          : null,
    );
  }
}
