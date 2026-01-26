import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_components.dart';
import '../models/study_spot.dart';
import '../providers/user_profile_provider.dart';
import '../providers/map_provider.dart';
import '../business/business_dashboard_page.dart';
import '../services/haptic_service.dart';

class StudySpotDetailsSheet extends ConsumerStatefulWidget {
  final StudySpot spot;

  const StudySpotDetailsSheet({super.key, required this.spot});

  @override
  ConsumerState<StudySpotDetailsSheet> createState() =>
      _StudySpotDetailsSheetState();
}

class _StudySpotDetailsSheetState extends ConsumerState<StudySpotDetailsSheet> {
  late StudySpot _currentSpot;
  bool _isProcessingAI = false;

  @override
  void initState() {
    super.initState();
    _currentSpot = widget.spot;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myProfile = ref.watch(myProfileProvider).value;

    return PointerInterceptor(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          blur: 20,
          opacity: isDark ? 0.9 : 1.0,
          color: theme.scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        child: _currentSpot.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _currentSpot.imageUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _buildPlaceholder(isDark),
                                errorWidget: (_, __, ___) =>
                                    _buildPlaceholder(isDark),
                              )
                            : _buildPlaceholder(isDark),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SPONSORED BANNER (If Sponsored)
                            if (_currentSpot.isSponsored)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500)
                                  ]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star,
                                        color: Colors.black, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _currentSpot.promotionalText
                                                    ?.isNotEmpty ==
                                                true
                                            ? _currentSpot.promotionalText!
                                            : "Special Offer Available!",
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 2. Title & Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentSpot.name,
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!_currentSpot.isVerified)
                                        Text(
                                          _formatType(_currentSpot.type),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme
                                                .textTheme.bodySmall?.color
                                                ?.withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_currentSpot.isSponsored) // GOLD BADGE
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: Colors.amber, // Gold
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.amber
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8)
                                        ]),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.workspace_premium,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 4),
                                        Text(
                                          "SPONSORED",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (_currentSpot.isVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.stars,
                                            size: 20,
                                            color:
                                                theme.colorScheme.onSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          "VERIFIED",
                                          style: TextStyle(
                                              color:
                                                  theme.colorScheme.onSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.disabledColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.public,
                                            size: 20,
                                            color: theme
                                                .textTheme.bodySmall?.color
                                                ?.withValues(alpha: 0.5)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "PUBLIC",
                                          style: TextStyle(
                                              color: theme
                                                  .textTheme.bodySmall?.color
                                                  ?.withValues(alpha: 0.5),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            if (_currentSpot.incentive != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_offer,
                                        color: theme.colorScheme.secondary,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _currentSpot.incentive!,
                                        style: TextStyle(
                                          color: theme.colorScheme.secondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // NEW: LIVE VIBE SECTION
                            _buildLiveVibeSection(context, _currentSpot),
                            const SizedBox(height: 24),

                            // 3. Perks (or Features)
                            if (_currentSpot.perks.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _currentSpot.perks.map((perk) {
                                  return Chip(
                                    label: Text(_formatPerk(perk)),
                                    backgroundColor: theme.canvasColor,
                                    labelStyle: theme.textTheme.bodySmall,
                                    avatar: Icon(_getPerkIcon(perk),
                                        size: 20, color: theme.primaryColor),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide.none,
                                  );
                                }).toList(),
                              )
                            else if (!_currentSpot.isVerified)
                              // For public spots without specific perks, show generic tags based on type
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: const Text("Public Access"),
                                    backgroundColor: theme.canvasColor,
                                    labelStyle: theme.textTheme.bodySmall,
                                    avatar: Icon(Icons.door_front_door,
                                        size: 20,
                                        color: theme.primaryColor
                                            .withValues(alpha: 0.7)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide.none,
                                  ),
                                  Chip(
                                    label: Text(_formatType(_currentSpot.type)),
                                    backgroundColor: theme.canvasColor,
                                    labelStyle: theme.textTheme.bodySmall,
                                    avatar: Icon(
                                        _getTypeIcon(_currentSpot.type),
                                        size: 20,
                                        color: theme.primaryColor
                                            .withValues(alpha: 0.7)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide.none,
                                  ),
                                ],
                              ),

                            const SizedBox(height: 24),

                            // 4. Action Button
                            PrimaryButton(
                              label: "Navigate Here",
                              icon: Icons.directions,
                              fullWidth: true,
                              onPressed: () {
                                hapticService.mediumImpact();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Navigation started! (Simulation)")),
                                );
                              },
                            ),

                            // 5. Business Owner Action: Sponsor Request
                            if (myProfile != null &&
                                myProfile.isBusinessOwner &&
                                !_currentSpot.isSponsored) ...[
                              const SizedBox(height: 12),
                              SecondaryButton(
                                label: "Claim & Sponsor This Spot",
                                icon: Icons.monetization_on,
                                fullWidth: true,
                                onPressed: () {
                                  hapticService.mediumImpact();
                                  Navigator.pop(context);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const BusinessDashboardPage()));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Go to your Dashboard to register this spot (Mock Flow)")),
                                  );
                                },
                              )
                            ],

                            const SizedBox(height: 12),
                            SecondaryButton(
                              label: "Rate this Spot",
                              icon: Icons.rate_review_outlined,
                              fullWidth: true,
                              onPressed: () =>
                                  _showSpotReviewDialog(context, _currentSpot),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      height: 200,
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
      child: Center(
        child: Icon(Icons.coffee,
            size: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1)),
      ),
    );
  }

  String _formatPerk(String perk) {
    return perk.replaceAll('_', ' ').toUpperCase();
  }

  IconData _getPerkIcon(String perk) {
    switch (perk.toLowerCase()) {
      case 'wifi':
      case 'fast_wifi':
      case 'free_wifi':
        return Icons.wifi;
      case 'outlets':
        return Icons.power;
      case 'quiet':
        return Icons.volume_off;
      case 'coffee':
      case 'expensive_coffee':
        return Icons.coffee;
      case '24_7':
        return Icons.access_time;
      case 'group_rooms':
        return Icons.meeting_room;
      case 'view':
        return Icons.landscape;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _formatType(String type) {
    if (type.isEmpty) return 'Public Spot';
    return type[0].toUpperCase() + type.substring(1).replaceAll('_', ' ');
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cafe':
        return Icons.coffee;
      case 'library':
        return Icons.local_library;
      case 'restaurant':
        return Icons.restaurant;
      case 'bar':
        return Icons.local_bar;
      default:
        return Icons.place;
    }
  }

  Widget _buildVibeIndicator(BuildContext context,
      {required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getNoiseLabel(int level) {
    switch (level) {
      case 1:
        return "SILENT";
      case 2:
        return "QUIET";
      case 3:
        return "MODERATE";
      case 4:
        return "LOUD";
      case 5:
        return "VERY LOUD";
      default:
        return "UNKNOWN";
    }
  }

  IconData _getNoiseIcon(int level) {
    if (level <= 2) return Icons.volume_off;
    if (level <= 3) return Icons.volume_down;
    return Icons.volume_up;
  }

  Color _getNoiseColor(int level) {
    if (level <= 2) return Colors.blue;
    if (level <= 3) return Colors.green;
    if (level <= 4) return Colors.orange;
    return Colors.red;
  }

  String _getOccupancyLabel(int percent) {
    if (percent < 20) return "EMPTY";
    if (percent < 50) return "AVAILABLE";
    if (percent < 80) return "BUSY";
    return "PACKED";
  }

  Color _getOccupancyColor(int percent) {
    if (percent < 50) return Colors.green;
    if (percent < 80) return Colors.orange;
    return Colors.red;
  }

  Widget _buildLiveVibeSection(BuildContext context, StudySpot spot) {
    final theme = Theme.of(context);
    final occupancy = spot.occupancyPercent;

    Color occupancyColor = Colors.green;
    if (occupancy > 70) {
      occupancyColor = Colors.red;
    } else if (occupancy > 40) {
      occupancyColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sensors, size: 18, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              "LIVE VIBE",
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            if (_isProcessingAI) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.purple,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.canvasColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Noise Level & Occupancy
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _buildVibeIndicator(
                    context,
                    label: _getNoiseLabel(spot.noiseLevel),
                    icon: _getNoiseIcon(spot.noiseLevel),
                    color: _getNoiseColor(spot.noiseLevel),
                  ),
                  _buildVibeIndicator(
                    context,
                    label: _getOccupancyLabel(spot.occupancyPercent),
                    icon: Icons.people,
                    color: _getOccupancyColor(spot.occupancyPercent),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Occupancy Meter
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Occupancy: $occupancy%",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: occupancy / 100,
                            backgroundColor:
                                occupancyColor.withValues(alpha: 0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(occupancyColor),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (spot.vibeSummary != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  spot.vibeSummary!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],

              if (spot.aiTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: spot.aiTags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: theme.primaryColor
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showSpotReviewDialog(BuildContext context, StudySpot spot) {
    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Rate ${spot.name}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => IconButton(
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () =>
                              setDialogState(() => rating = index + 1),
                        )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "What's the vibe? (e.g. Too cold, fast wifi...)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final userId = ref.read(myProfileProvider).value?.userId;
                if (userId == null) return;

                final supabase = Supabase.instance.client;
                await supabase.from('spot_reviews').insert({
                  'spot_id': spot.id,
                  'user_id': userId,
                  'rating': rating,
                  'comment': commentController.text,
                });

                if (context.mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);

                  // Use the PARENT State's setState, not the dialog's!
                  if (mounted) {
                    setState(() {
                      _isProcessingAI = true;
                    });
                  }

                  // Trigger AI summarization directly
                  try {
                    final response = await supabase.functions.invoke(
                      'summarize-spot-reviews',
                      body: {
                        'record': {'spot_id': spot.id}
                      },
                    );

                    if (response.status == 200 && response.data != null) {
                      final data = response.data;
                      if (data['success'] == true && mounted) {
                        setState(() {
                          _currentSpot = StudySpot(
                            id: _currentSpot.id,
                            name: _currentSpot.name,
                            latitude: _currentSpot.latitude,
                            longitude: _currentSpot.longitude,
                            imageUrl: _currentSpot.imageUrl,
                            perks: _currentSpot.perks,
                            incentive: _currentSpot.incentive,
                            isVerified: _currentSpot.isVerified,
                            source: _currentSpot.source,
                            type: _currentSpot.type,
                            ownerId: _currentSpot.ownerId,
                            isSponsored: _currentSpot.isSponsored,
                            promotionalText: _currentSpot.promotionalText,
                            occupancyPercent: _currentSpot.occupancyPercent,
                            noiseLevel:
                                data['noise_level'] ?? _currentSpot.noiseLevel,
                            vibeSummary: data['vibe_summary'],
                            aiTags: data['ai_tags'] != null
                                ? List<String>.from(data['ai_tags'])
                                : [],
                          );
                        });

                        // Sync with backend provider
                        ref.invalidate(studySpotsProvider);
                      }
                    }
                  } catch (e) {
                    debugPrint("AI Summary Trigger Error: $e");
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isProcessingAI = false;
                      });
                    }
                  }

                  // Use the captured messenger to show the snackbar safely
                  messenger.showSnackBar(
                    const SnackBar(
                        content:
                            Text("Review submitted! AI matching complete.")),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
