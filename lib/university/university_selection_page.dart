import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/university_provider.dart';
import '../providers/auth_provider.dart';
import 'course_import_page.dart';
import '../services/haptic_service.dart';

class UniversitySelectionPage extends ConsumerStatefulWidget {
  const UniversitySelectionPage({super.key});

  @override
  ConsumerState<UniversitySelectionPage> createState() =>
      _UniversitySelectionPageState();
}

class _UniversitySelectionPageState
    extends ConsumerState<UniversitySelectionPage> {
  final _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    // Auto-seed for MVP if needed (hacky but effective for demo)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(universityServiceProvider).seedSimulationData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(searchUniversitiesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select University"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search your school (e.g. Nerd Herd U)",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                // Debounce could be added here
                setState(() => _query = val);
              },
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (universities) {
                if (universities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? "Search for your school"
                              : "No schools found",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_query.isNotEmpty)
                          TextButton(
                              onPressed: () {},
                              child: const Text("Request School Addition"))
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: universities.length,
                  itemBuilder: (context, index) {
                    final uni = universities[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: uni.logoUrl != null
                            ? AssetImage(uni.logoUrl!)
                            : null,
                        child: uni.logoUrl == null
                            ? const Icon(Icons.school, color: Colors.black)
                            : null,
                      ),
                      title: Text(uni.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(uni.domain ?? "Verified Institution"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        hapticService.mediumImpact();
                        // Set university in profile
                        final userId = ref
                            .read(supabaseClientProvider)
                            .auth
                            .currentUser
                            ?.id;
                        if (userId != null) {
                          await ref
                              .read(universityServiceProvider)
                              .setUniversity(userId, uni.id);
                        }

                        if (context.mounted) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CourseImportPage(university: uni)));
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
