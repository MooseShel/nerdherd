import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Legal Info")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLegalSection(
            context,
            title: "Terms of Service",
            content:
                "By using Nerd Herd, you agree to follow campus rules and maintain a respectful academic environment. We are a platform for peer-to-peer collaboration and tutoring.",
          ),
          const SizedBox(height: 24),
          _buildLegalSection(
            context,
            title: "Privacy Policy",
            content:
                "We value your privacy. Your location is only shared with other students when you are in 'Study Mode'. We do not sell your data to third parties.",
          ),
          const SizedBox(height: 24),
          _buildLegalSection(
            context,
            title: "Safety Guidelines",
            content:
                "Always meet in public campus locations. Use the report feature if you encounter suspicious behavior. Verified tutors have undergone a basic ID check.",
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context,
      {required String title, required String content}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(content, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
