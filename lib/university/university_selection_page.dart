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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(searchUniversitiesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select School",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search your school...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (val) {
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
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: TextButton(
                                onPressed: () {},
                                child: const Text("Request School Addition")),
                          )
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
                    childAspectRatio: 0.85, // Taller cards
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
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Full background image
                            if (uni.logoUrl != null)
                              uni.logoUrl!.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: uni.logoUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: theme.disabledColor
                                            .withValues(alpha: 0.1),
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: theme.disabledColor
                                            .withValues(alpha: 0.1),
                                        child:
                                            const Icon(Icons.school, size: 40),
                                      ),
                                    )
                                  : Image.asset(
                                      uni.logoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: theme.disabledColor
                                            .withValues(alpha: 0.1),
                                        child:
                                            const Icon(Icons.school, size: 40),
                                      ),
                                    )
                            else
                              Container(
                                color:
                                    theme.primaryColor.withValues(alpha: 0.1),
                                child: Icon(Icons.school,
                                    size: 50, color: theme.primaryColor),
                              ),

                            // Gradient Overlay
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.0),
                                      Colors.black.withValues(alpha: 0.8),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Text Content at Bottom
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    uni.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (uni.domain != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        uni.domain!,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
