import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

class MapFilters {
  final bool showTutors;
  final bool showStudents;
  final List<String> selectedSubjects;

  MapFilters({
    this.showTutors = true,
    this.showStudents = true,
    this.selectedSubjects = const [],
  });

  MapFilters copyWith({
    bool? showTutors,
    bool? showStudents,
    List<String>? selectedSubjects,
  }) {
    return MapFilters(
      showTutors: showTutors ?? this.showTutors,
      showStudents: showStudents ?? this.showStudents,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
    );
  }
}

class MapFilterWidget extends StatefulWidget {
  final MapFilters currentFilters;
  final Function(MapFilters) onFilterChanged;
  final List<String> availableSubjects;

  const MapFilterWidget({
    super.key,
    required this.currentFilters,
    required this.onFilterChanged,
    this.availableSubjects = const [
      'Calculus',
      'Physics',
      'History',
      'Art',
      'CS',
      'Chemistry'
    ],
  });

  @override
  State<MapFilterWidget> createState() => _MapFilterWidgetState();
}

class _MapFilterWidgetState extends State<MapFilterWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpanded() {
    hapticService.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _updateFilters(MapFilters newFilters) {
    widget.onFilterChanged(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Toggle Button
        FloatingActionButton.small(
          heroTag: "filter_toggle",
          onPressed: _toggleExpanded,
          backgroundColor: _isExpanded ? theme.primaryColor : theme.cardColor,
          foregroundColor: _isExpanded ? Colors.white : theme.primaryColor,
          child: Icon(_isExpanded ? Icons.close : Icons.filter_list),
        ),

        const SizedBox(height: 12),

        // Expanded Panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: _isExpanded ? 260 : 0,
          height: _isExpanded ? null : 0,
          constraints: BoxConstraints(
            maxHeight: _isExpanded ? 400 : 0,
          ),
          decoration: BoxDecoration(
            color: theme.cardTheme.color?.withOpacity(0.9) ??
                (isDark
                    ? const Color(0xFF0F111A).withOpacity(0.9)
                    : Colors.white.withOpacity(0.9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: _isExpanded
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "FILTER PEERS",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.textTheme.labelSmall?.color
                                  ?.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Type Toggles
                          _buildSwitch(
                            "Tutors",
                            widget.currentFilters.showTutors,
                            Colors.amber, // Semantic color
                            (val) => _updateFilters(widget.currentFilters
                                .copyWith(showTutors: val)),
                            theme,
                          ),
                          _buildSwitch(
                            "Students",
                            widget.currentFilters.showStudents,
                            theme.primaryColor,
                            (val) => _updateFilters(widget.currentFilters
                                .copyWith(showStudents: val)),
                            theme,
                          ),

                          const SizedBox(height: 16),
                          Divider(color: theme.dividerColor.withOpacity(0.1)),
                          const SizedBox(height: 8),

                          Text(
                            "SUBJECTS",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.textTheme.labelSmall?.color
                                  ?.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subject Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.availableSubjects.map((subject) {
                              final isSelected = widget
                                  .currentFilters.selectedSubjects
                                  .contains(subject);
                              return FilterChip(
                                label: Text(subject),
                                selected: isSelected,
                                onSelected: (selected) {
                                  hapticService.lightImpact();
                                  final newSubjects = List<String>.from(
                                      widget.currentFilters.selectedSubjects);
                                  if (selected) {
                                    newSubjects.add(subject);
                                  } else {
                                    newSubjects.remove(subject);
                                  }
                                  _updateFilters(widget.currentFilters
                                      .copyWith(selectedSubjects: newSubjects));
                                },
                                backgroundColor:
                                    theme.cardTheme.color?.withOpacity(0.5),
                                selectedColor:
                                    theme.primaryColor.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? theme.primaryColor
                                      : theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        20)), // Rounded chips
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, Color activeColor,
      Function(bool) onChanged, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                label == "Tutors" ? Icons.school : Icons.person,
                size: 16,
                color: value
                    ? activeColor
                    : theme.iconTheme.color?.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: (val) {
              hapticService.selectionClick();
              onChanged(val);
            },
            activeColor: activeColor,
            activeTrackColor: activeColor.withOpacity(0.3),
            inactiveTrackColor: theme.disabledColor.withOpacity(0.1),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
