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
                      child: Text(
                        spot.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (spot.incentive != null)
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
                              "DEAL",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                if (spot.incentive != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    spot.incentive!,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 3. Perks
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
}
