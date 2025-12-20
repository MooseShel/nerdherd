import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        title: const Text("Select any university below or search for one",
            style: TextStyle(fontSize: 16)), // Smaller font to fit
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
                            size: 64,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? "No universities found"
                              : "No schools found",
                          style: TextStyle(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5)),
                        ),
                        if (_query.isNotEmpty)
                          TextButton(
                              onPressed: () {},
                              child: const Text("Request School Addition"))
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: universities.length,
                  itemBuilder: (context, index) {
                    final uni = universities[index];
                    return InkWell(
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.scaffoldBackgroundColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor
                                        .withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: uni.logoUrl != null
                                  ? Image(
                                      image: uni.logoUrl!.startsWith('http')
                                          ? CachedNetworkImageProvider(
                                              uni.logoUrl!)
                                          : AssetImage(uni.logoUrl!)
                                              as ImageProvider,
                                      fit: BoxFit.contain,
                                    )
                                  : Icon(Icons.school,
                                      size: 50, color: theme.primaryColor),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                uni.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (uni.domain != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                uni.domain!,
                                style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
