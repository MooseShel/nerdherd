import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NEW
import '../models/study_spot.dart';
import '../services/haptic_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'ui_components.dart';
import '../providers/user_profile_provider.dart'; // NEW
import '../business/business_dashboard_page.dart'; // NEW for navigation

class StudySpotDetailsSheet extends ConsumerWidget {
  // Changed to ConsumerWidget
  final StudySpot spot;

  const StudySpotDetailsSheet({super.key, required this.spot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Added ref
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myProfile = ref.watch(myProfileProvider).value; // Watch profile

    return GlassContainer(
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

          // 1. Header Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: spot.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: spot.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildPlaceholder(isDark),
                    errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
                  )
                : _buildPlaceholder(isDark),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SPONSORED BANNER (If Sponsored)
                if (spot.isSponsored)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spot.promotionalText?.isNotEmpty == true
                                ? spot.promotionalText!
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!spot.isVerified)
                            Text(
                              _formatType(spot.type),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (spot.isSponsored) // GOLD BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.amber, // Gold
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 8)
                            ]),
                        child: const Row(
                          children: [
                            Icon(Icons.workspace_premium,
                                size: 16, color: Colors.black),
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
                    else if (spot.isVerified)
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
                                size: 16, color: theme.colorScheme.onSecondary),
                            const SizedBox(width: 4),
                            Text(
                              "VERIFIED",
                              style: TextStyle(
                                  color: theme.colorScheme.onSecondary,
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
                          color: theme.disabledColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.public,
                                size: 16,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              "PUBLIC",
                              style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color
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

                if (spot.incentive != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer,
                            color: theme.colorScheme.secondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spot.incentive!,
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

                // 3. Perks (or Features)
                if (spot.perks.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: spot.perks.map((perk) {
                      return Chip(
                        label: Text(_formatPerk(perk)),
                        backgroundColor: theme.canvasColor,
                        labelStyle: theme.textTheme.bodySmall,
                        avatar: Icon(_getPerkIcon(perk),
                            size: 16, color: theme.primaryColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  )
                else if (!spot.isVerified)
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
                            size: 16,
                            color: theme.primaryColor.withValues(alpha: 0.7)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      ),
                      Chip(
                        label: Text(_formatType(spot.type)),
                        backgroundColor: theme.canvasColor,
                        labelStyle: theme.textTheme.bodySmall,
                        avatar: Icon(_getTypeIcon(spot.type),
                            size: 16,
                            color: theme.primaryColor.withValues(alpha: 0.7)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
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
                          content: Text("Navigation started! (Simulation)")),
                    );
                  },
                ),

                // 5. Business Owner Action: Sponsor Request
                if (myProfile != null &&
                    myProfile.isBusinessOwner &&
                    !spot.isSponsored) ...[
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
                ]
              ],
            ),
          ),
        ],
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
}
