import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // For LatLng
import 'dart:ui'; // For ImageFilter
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../providers/serendipity_provider.dart';
import '../../config/theme.dart';
import 'match_intro_sheet.dart';

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
    double radiusMiles = 1.0;

    final List<double> radiusSteps = [0.0, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0];

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
                  debugPrint("🆘 Broadcasting Signal - Enabling Map");

                  // Capture needed values and refers before potential disposal
                  final meters = (radiusMiles * 1609.34).toInt();
                  final subject = subjectController.text;
                  final conf = confidence;
                  final radiusNotifier =
                      ref.read(serendipityRadiusProvider.notifier);
                  final signalNotifier =
                      ref.read(activeStruggleSignalProvider.notifier);
                  final modalNotifier = ref.read(isModalOpenProvider.notifier);

                  // Update radius first
                  radiusNotifier.setRadius(meters);

                  // Create signal
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
        return 'Totally lost 😵';
      case 2:
        return 'Pretty stuck 😓';
      case 3:
        return 'Need a hint 🤔';
      case 4:
        return 'Almost there 😊';
      case 5:
        return 'Just checking 😎';
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

  @override
  Widget build(BuildContext context) {
    final signalState = ref.watch(activeStruggleSignalProvider);
    final matchesState = ref.watch(pendingMatchesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check for Pending Matches BUT ONLY if a signal is active
    final signal = signalState.value;
    if (signal != null &&
        matchesState.hasValue &&
        matchesState.value!.isNotEmpty) {
      final matches = matchesState.value!;
      // Show Match Found Button (Gold)
      return _buildGlassButton(
        context,
        activeColor: Colors.amber, // Gold for match
        onPressed: () {
          // Open Intro Sheet for the first match
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => MatchIntroSheet(match: matches.first),
          );
        },
        child: const Icon(Icons.favorite, color: Colors.white),
      );
    }

    return signalState.when(
      loading: () => const SizedBox(
        width: 56,
        height: 56,
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => _buildGlassButton(
        context,
        onPressed: () => ref.refresh(activeStruggleSignalProvider),
        activeColor: theme.colorScheme.error,
        child: const Icon(Icons.error, color: Colors.white),
      ),
      data: (signal) {
        if (signal == null) {
          // IDLE STATE - Normal Glass Button
          return _buildGlassButton(
            context,
            onPressed: () => _showStruggleDialog(context),
            child: Text(
              "SOS",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          );
        } else {
          // ACTIVE STATE - Pulsing
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: _buildGlassButton(
                  context,
                  activeColor: AppTheme.serendipityOrange,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
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
                            child: const Text('I\'m good (Cancel)'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Keep waiting'),
                          ),
                        ],
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
              ),
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
          );
        }
      },
    );
  }
}
