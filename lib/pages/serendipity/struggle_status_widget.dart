import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // For LatLng
import 'dart:ui'; // For ImageFilter
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../providers/serendipity_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../config/theme.dart';

import 'match_list_sheet.dart'; // Import MatchListSheet
import 'pending_matches_sheet.dart';

import '../../models/user_profile.dart';

class StruggleStatusWidget extends ConsumerStatefulWidget {
  final LatLng? currentLocation;

  const StruggleStatusWidget({super.key, this.currentLocation});

  @override
  ConsumerState<StruggleStatusWidget> createState() =>
      _StruggleStatusWidgetState();
}

class _StruggleStatusWidgetState extends ConsumerState<StruggleStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signalState = ref.watch(activeStruggleSignalProvider);
    final matchesState = ref.watch(pendingMatchesProvider);
    final theme = Theme.of(context);

    // Listen to Nerd Match results
    ref.listen(nerdMatchProvider, (previous, next) {
      if (next is AsyncData && next.value!.isNotEmpty) {
        final matches = next.value!;
        // Show List of Matches
        _showNerdMatchList(matches, signalState.value?.subject ?? "Study");
        ref.read(nerdMatchProvider.notifier).clear();
      } else if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nerd Match Error: ${next.error}')),
        );
      }
    });

    return signalState.when(
      loading: () => _buildGlassButton(
        context,
        onPressed: () {},
        child: const SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      ),
      error: (err, st) => _buildGlassButton(
        context,
        activeColor: Colors.red,
        onPressed: () {
          ref.read(activeStruggleSignalProvider.notifier).refresh();
        },
        child: const Icon(Icons.error, color: Colors.white),
      ),
      data: (signal) {
        // Tutors do NOT see the Struggle/SOS button
        final profile = ref.read(myProfileProvider).value;
        if (profile?.isTutor == true) {
          return const SizedBox.shrink();
        }

        // Check for Pending Matches BUT ONLY if a signal is active
        if (signal != null &&
            matchesState.hasValue &&
            matchesState.value!.isNotEmpty) {
          // Show Match Found Button (Gold)
          return _buildGlassButton(
            context,
            activeColor: Colors.amber, // Gold for match
            onPressed: () {
              // Open List of Pending Matches (Requests)
              // Manage Modal State to block map gestures
              ref.read(isModalOpenProvider.notifier).state = true;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const PendingMatchesSheet(),
              ).then((_) {
                if (mounted) {
                  ref.read(isModalOpenProvider.notifier).state = false;
                }
              });
            },
            child: const Icon(Icons.favorite, color: Colors.white),
          );
        }

        if (signal == null) {
          // IDLE STATE - Normal Glass Button
          return _buildGlassButton(
            context,
            onPressed: () => _showStruggleDialog(context),
            child: Text(
              "SOS",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontSize: 16,
              ),
            ),
          );
        }

        // ACTIVE STATE - Pulsing Effect
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // PULSING SOS BUTTON (Primary)
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // The Button
                _buildGlassButton(
                  context,
                  activeColor: AppTheme.serendipityOrange,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => PointerInterceptor(
                        child: AlertDialog(
                          title: const Text('Signal Active 📡'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Subject: ${signal.subject}'),
                              const SizedBox(height: 8),
                              Text(
                                  'Expires in: ${signal.timeRemaining.inMinutes} mins'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(activeStruggleSignalProvider.notifier)
                                    .expireSignal();
                                Navigator.pop(context);
                              },
                              child: const Text('Stop Broadcasting',
                                  style: TextStyle(color: Colors.red)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Keep Waiting'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "SOS",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                // The Pulsing Glow (Behind)
                Positioned.fill(
                  child: IgnorePointer(
                    child: OverflowBox(
                      maxWidth: 100,
                      maxHeight: 100,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Container(
                            width: 56 + (_controller.value * 30),
                            height: 56 + (_controller.value * 30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.serendipityOrange
                                    .withValues(alpha: 1 - _controller.value),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // NERD MATCH BUTTON (Secondary)
            const SizedBox(width: 16),
            _buildNerdMatchButton(
              context,
              isLoading: ref.watch(nerdMatchProvider).isLoading,
              onPressed: () {
                ref.read(nerdMatchProvider.notifier).findMatches();
              },
            ),
          ],
        );
      },
    );
  }

  // Restore deleted methods
  void _showStruggleDialog(BuildContext context) {
    if (widget.currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for location...')),
      );
      return;
    }

    debugPrint("🆘 Opening SOS Dialog - Disabling Map");
    ref.read(isModalOpenProvider.notifier).state = true; // DISABLE MAP

    final subjectController = TextEditingController();
    int confidence = 3;
    double radiusMiles = 5.0;

    final List<double> radiusSteps = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: const Text('Describe your struggle'),
            content: PointerInterceptor(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (_) {}, // Block scroll wheel leakage
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject / Topic',
                          hintText: 'e.g. Calculus, pointers in C',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('How stuck are you?',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: confidence.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        onChanged: (val) {
                          setState(() => confidence = val.toInt());
                        },
                      ),
                      Center(
                        child: Text(_getConfidenceLabel(confidence),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.serendipityOrange,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24),
                      const Text('Visibility Radius (Miles)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: radiusSteps.indexOf(radiusMiles).toDouble(),
                        min: 0,
                        max: (radiusSteps.length - 1).toDouble(),
                        divisions: radiusSteps.length - 1,
                        onChanged: (val) {
                          setState(
                              () => radiusMiles = radiusSteps[val.toInt()]);
                        },
                      ),
                      Center(
                        child: Text(
                          radiusMiles == 0
                              ? "Invisible to others"
                              : "${radiusMiles.toStringAsFixed(2)} miles",
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint("🆘 Closing SOS Dialog - Enabling Map");
                  ref.read(isModalOpenProvider.notifier).state = false;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final subject = subjectController.text.trim();
                  if (subject.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a subject (e.g. Calculus)'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  debugPrint("🆘 Broadcasting Signal - Enabling Map");

                  final meters = (radiusMiles * 1609.34).toInt();
                  final conf = 6 - confidence;

                  final radiusNotifier =
                      ref.read(serendipityRadiusProvider.notifier);
                  final signalNotifier =
                      ref.read(activeStruggleSignalProvider.notifier);
                  final modalNotifier = ref.read(isModalOpenProvider.notifier);

                  radiusNotifier.setRadius(meters);

                  await signalNotifier.createSignal(
                    subject: subject,
                    confidenceLevel: conf,
                    location: widget.currentLocation!,
                  );

                  modalNotifier.state = false;

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.serendipityOrange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Broadcast 📡'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getConfidenceLabel(int level) {
    switch (level) {
      case 1:
        return 'Just checking 😎';
      case 2:
        return 'Almost there 😊';
      case 3:
        return 'Need a hint 🤔';
      case 4:
        return 'Pretty stuck 😓';
      case 5:
        return 'Totally lost 😵';
      default:
        return '';
    }
  }

  Widget _buildGlassButton(BuildContext context,
      {required VoidCallback onPressed,
      required Widget child,
      Color? activeColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const size = 56.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: (activeColor ?? (isDark ? Colors.black : Colors.white))
                .withValues(alpha: 0.7),
            child: InkWell(
              onTap: onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNerdMatchButton(BuildContext context,
      {required VoidCallback onPressed, bool isLoading = false}) {
    return _buildGlassButton(
      context,
      activeColor: Colors.purple.shade600,
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome, color: Colors.white),
    );
  }

  void _showNerdMatchList(List<UserProfile> matches, String subject) {
    ref.read(isModalOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MatchListSheet(
        matches: matches,
        subject: subject,
        myLocation: widget.currentLocation,
        onClose: () => Navigator.pop(context),
      ),
    ).then((_) {
      if (mounted) ref.read(isModalOpenProvider.notifier).state = false;
    });
  }
}
