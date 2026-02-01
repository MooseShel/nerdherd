import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/university_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
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
    final myProfile = ref.watch(myProfileProvider).value;
    final useUniTheme = myProfile?.useUniversityTheme ?? true;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Select School",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor.withValues(alpha: 0.2),
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: "Search",
                prefixIcon: Icon(Icons.search,
                    color: theme.hintColor.withValues(alpha: 0.7)),
                filled: true,
                fillColor: theme.cardColor,
                // iOS style grey background usually, but cardColor works for adaptability
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                isDense: true,
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
                            color: theme.disabledColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? "No universities found"
                              : "No schools found",
                          style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                        if (_query.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: TextButton(
                                onPressed: () {},
                                child: Text("Request Addition",
                                    style: TextStyle(
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.w600))),
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
                    childAspectRatio: 0.8, // Slightly taller for better layout
                  ),
                  itemCount: universities.length,
                  itemBuilder: (context, index) {
                    final uni = universities[index];
                    // Calculate a subtle background color for the logo area
                    final primaryColor =
                        (useUniTheme && uni.primaryColorInt != null)
                            ? Color(uni.primaryColorInt!)
                            : theme.primaryColor;

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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo Area
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      primaryColor.withValues(alpha: 0.05),
                                      primaryColor.withValues(alpha: 0.15),
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: (uni.logoUrl != null ||
                                          uni.assetLogoPath.isNotEmpty)
                                      ? Hero(
                                          tag: 'uni_logo_${uni.id}',
                                          child: (uni.logoUrl
                                                      ?.startsWith('http') ??
                                                  false)
                                              ? CachedNetworkImage(
                                                  imageUrl: uni.logoUrl!,
                                                  fit: BoxFit.contain,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2)),
                                                  errorWidget: (context, url,
                                                          error) =>
                                                      Icon(Icons.school,
                                                          size: 40,
                                                          color: primaryColor
                                                              .withValues(
                                                                  alpha: 0.5)),
                                                )
                                              : Image.asset(
                                                  uni.logoUrl ??
                                                      uni.assetLogoPath,
                                                  fit: BoxFit.contain,
                                                ),
                                        )
                                      : Icon(Icons.school,
                                          size: 48,
                                          color: primaryColor.withValues(
                                              alpha: 0.5)),
                                ),
                              ),
                            ),
                            // Text Area
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: theme.cardColor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    uni.name,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (uni.location != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      uni.location!,
                                      style: TextStyle(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
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
