import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../widgets/ui_components.dart';

class NerdMatchReveal extends StatefulWidget {
  final UserProfile matchedUser;
  final double similarity;
  final String subject;
  final VoidCallback onConnect;
  final VoidCallback onDismiss;

  const NerdMatchReveal({
    super.key,
    required this.matchedUser,
    required this.similarity,
    required this.subject,
    required this.onConnect,
    required this.onDismiss,
  });

  @override
  State<NerdMatchReveal> createState() => _NerdMatchRevealState();
}

class _NerdMatchRevealState extends State<NerdMatchReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _blurAnimation = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.6, curve: Curves.easeIn)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          AnimatedBuilder(
            animation: _blurAnimation,
            builder: (context, child) {
              return BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _blurAnimation.value,
                  sigmaY: _blurAnimation.value,
                ),
                child: Container(
                    color: Colors.black
                        .withValues(alpha: 0.3 * _opacityAnimation.value)),
              );
            },
          ),

          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassContainer(
                    blur: 25,
                    opacity: isDark ? 0.15 : 0.4,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sparkle Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade300,
                                Colors.orange.shade600,
                              ],
                            ),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'NERD MATCH!',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          '${(widget.similarity * 100).toInt()}% Study Compatibility',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Profile Circular Clip
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: theme.primaryColor, width: 3),
                            image: widget.matchedUser.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                        widget.matchedUser.avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: widget.matchedUser.avatarUrl == null
                              ? Center(
                                  child: Text(
                                    widget.matchedUser.fullName?[0] ?? '?',
                                    style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          widget.matchedUser.fullName ?? 'Future Study Buddy',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),

                        // Study Style Chips
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildStyleChip(
                              context,
                              widget.matchedUser.studyStyleSocial > 0.5
                                  ? Icons.groups
                                  : Icons.person,
                              widget.matchedUser.studyStyleSocial > 0.5
                                  ? 'Social'
                                  : 'Quiet',
                            ),
                            _buildStyleChip(
                              context,
                              widget.matchedUser.studyStyleTemporal > 0.5
                                  ? Icons.nightlight_round
                                  : Icons.wb_sunny,
                              widget.matchedUser.studyStyleTemporal > 0.5
                                  ? 'Night Owl'
                                  : 'Early Bird',
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        PrimaryButton(
                          label: 'Connect & Say Hi!',
                          fullWidth: true,
                          onPressed: widget.onConnect,
                        ),
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: 'Keep Looking',
                          fullWidth: true,
                          onPressed: widget.onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
