import 'package:flutter/material.dart';
import '../models/study_spot.dart';
import '../services/haptic_service.dart';

class StudySpotDetailsSheet extends StatelessWidget {
  final StudySpot spot;

  const StudySpotDetailsSheet({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: spot.imageUrl != null
                ? Image.network(
                    spot.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!spot.isVerified)
                            Text(
                              _formatType(spot.type),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (spot.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stars, size: 16, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              "VERIFIED",
                              style: TextStyle(
                                  color: Colors.black,
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
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.public, size: 16, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              "PUBLIC",
                              style: TextStyle(
                                  color: Colors.white70,
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
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spot.incentive!,
                            style: const TextStyle(
                              color: Colors.amberAccent,
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
                        backgroundColor: Colors.white10,
                        labelStyle: const TextStyle(color: Colors.white70),
                        avatar: Icon(_getPerkIcon(perk),
                            size: 16, color: Colors.cyanAccent),
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
                        backgroundColor: Colors.white10,
                        labelStyle: const TextStyle(color: Colors.white70),
                        avatar: const Icon(Icons.door_front_door,
                            size: 16, color: Colors.white70),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      ),
                      Chip(
                        label: Text(_formatType(spot.type)),
                        backgroundColor: Colors.white10,
                        labelStyle: const TextStyle(color: Colors.white70),
                        avatar: Icon(_getTypeIcon(spot.type),
                            size: 16, color: Colors.white70),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // 4. Action Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      hapticService.mediumImpact();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Navigation started! (Simulation)")),
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text("Navigate Here"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.coffee, size: 64, color: Colors.white24),
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
