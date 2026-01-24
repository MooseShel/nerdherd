import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

class MapFilters {
  final bool showTutors;
  final bool showStudents;
  final bool showClassmates;
  final bool showSponsoredSpots;
  final bool showRegularSpots;
  final double minRating;

  MapFilters({
    this.showTutors = true,
    this.showStudents = true,
    this.showClassmates = false,
    this.showSponsoredSpots = true,
    this.showRegularSpots = true,
    this.minRating = 0.0,
  });

  MapFilters copyWith({
    bool? showTutors,
    bool? showStudents,
    bool? showClassmates,
    bool? showSponsoredSpots,
    bool? showRegularSpots,
    double? minRating,
  }) {
    return MapFilters(
      showTutors: showTutors ?? this.showTutors,
      showStudents: showStudents ?? this.showStudents,
      showClassmates: showClassmates ?? this.showClassmates,
      showSponsoredSpots: showSponsoredSpots ?? this.showSponsoredSpots,
      showRegularSpots: showRegularSpots ?? this.showRegularSpots,
      minRating: minRating ?? this.minRating,
    );
  }
}

class MapFilterWidget extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final MapFilters currentFilters;
  final Function(MapFilters) onFilterChanged;

  const MapFilterWidget({
    super.key,
    required this.currentFilters,
    required this.onFilterChanged,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<MapFilterWidget> createState() => _MapFilterWidgetState();
}

class _MapFilterWidgetState extends State<MapFilterWidget>
    with SingleTickerProviderStateMixin {
  void _updateFilters(MapFilters newFilters) {
    widget.onFilterChanged(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Button
        FloatingActionButton.small(
          heroTag: "filter_toggle",
          onPressed: widget.onToggle,
          backgroundColor:
              widget.isExpanded ? theme.primaryColor : theme.cardColor,
          foregroundColor: widget.isExpanded
              ? theme.colorScheme.onPrimary
              : theme.primaryColor,
          child: Icon(widget.isExpanded ? Icons.close : Icons.filter_list),
        ),

        const SizedBox(height: 12),

        // Expanded Panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: widget.isExpanded ? 210 : 0, // Increased from 160 to 210
          decoration: BoxDecoration(
            color: theme.cardTheme.color?.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: widget.isExpanded
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16), // Adjusted padding
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "FILTERS",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.textTheme.labelSmall?.color
                                    ?.withValues(alpha: 0.5),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Type Icons & Toggles
                            _buildCompactToggle(
                              icon: Icons.school,
                              label: "Tutors",
                              activeColor: Colors.purpleAccent,
                              value: widget.currentFilters.showTutors,
                              onChanged: (val) => _updateFilters(widget
                                  .currentFilters
                                  .copyWith(showTutors: val)),
                            ),
                            _buildCompactToggle(
                              icon: Icons.person,
                              label: "Students",
                              activeColor: Colors.greenAccent,
                              value: widget.currentFilters.showStudents,
                              onChanged: (val) => _updateFilters(widget
                                  .currentFilters
                                  .copyWith(showStudents: val)),
                            ),
                            _buildCompactToggle(
                              icon: Icons.group,
                              label: "Classmates",
                              activeColor: theme.colorScheme.secondary,
                              value: widget.currentFilters.showClassmates,
                              onChanged: (val) => _updateFilters(widget
                                  .currentFilters
                                  .copyWith(showClassmates: val)),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.1),
                                indent: 8,
                                endIndent: 8,
                              ),
                            ),

                            _buildCompactToggle(
                              icon: Icons.star,
                              label: "Sponsored",
                              activeColor: const Color(0xFFFFD700),
                              value: widget.currentFilters.showSponsoredSpots,
                              onChanged: (val) => _updateFilters(widget
                                  .currentFilters
                                  .copyWith(showSponsoredSpots: val)),
                            ),
                            _buildCompactToggle(
                              icon: Icons.place,
                              label: "Public Spots",
                              activeColor: const Color(0xFF6200EE),
                              value: widget.currentFilters.showRegularSpots,
                              onChanged: (val) => _updateFilters(widget
                                  .currentFilters
                                  .copyWith(showRegularSpots: val)),
                            ),

                            const SizedBox(height: 12),

                            // Rating Slider (Small)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_outline,
                                    size: 10,
                                    color: Colors.amber.withValues(alpha: 0.5)),
                                const SizedBox(width: 4),
                                Text(
                                  widget.currentFilters.minRating == 0
                                      ? "All"
                                      : "${widget.currentFilters.minRating.toStringAsFixed(1)}+",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: theme.sliderTheme.copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                              ),
                              child: Slider(
                                value: widget.currentFilters.minRating,
                                min: 0,
                                max: 5,
                                divisions: 10,
                                activeColor: Colors.amber,
                                onChanged: (val) {
                                  hapticService.lightImpact();
                                  _updateFilters(widget.currentFilters
                                      .copyWith(minRating: val));
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactToggle({
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _MarkerPreview(
                icon: icon,
                color: activeColor,
                isActive: value,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: value
                          ? activeColor
                          : Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.color
                              ?.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: (val) {
              hapticService.selectionClick();
              onChanged(val);
            },
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.3),
            inactiveTrackColor:
                Theme.of(context).disabledColor.withValues(alpha: 0.1),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _MarkerPreview extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;

  const _MarkerPreview({
    required this.icon,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.grey.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}
