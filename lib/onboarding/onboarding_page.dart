import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_gate.dart';
import '../config/theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Find Your Squad',
      'description':
          'Discover tutors and study partners on the map. Connect instantly with peers nearby.',
      'icon': Icons.map_rounded,
      'color': Colors.cyanAccent,
    },
    {
      'title': 'Book & Pay Instantly',
      'description':
          'Schedule sessions and pay securely directly through the app. No more cash hassles.',
      'icon': Icons.payment_rounded,
      'color': Colors.greenAccent,
    },
    {
      'title': 'Academic Velocity',
      'description':
          'Track your earnings, manage your schedule, and accelerate your learning journey.',
      'icon': Icons.rocket_launch_rounded,
      'color': Colors.amberAccent,
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We'll use a dark theme by default for the onboarding to match branding
    final theme = AppTheme.darkTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: Stack(
        children: [
          // Background Gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage]['color'].withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: _pages[_currentPage]['color'].withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(theme, _pages[index]);
                    },
                  ),
                ),
                _buildBottomControls(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(ThemeData theme, Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: page['color'].withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: page['color'].withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: page['color'].withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ],
            ),
            child: Icon(
              page['icon'],
              size: 80,
              color: page['color'],
            ),
          ),
          const SizedBox(height: 60),
          Text(
            page['title'],
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            page['description'],
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
              height: 1.5,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? _pages[_currentPage]['color']
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {
                if (_currentPage < _pages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                } else {
                  _finishOnboarding();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _pages[_currentPage]['color'],
                foregroundColor: Colors.black,
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? "Get Started" : "Next",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
