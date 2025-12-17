import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class TutorVerificationPage extends StatefulWidget {
  const TutorVerificationPage({super.key});

  @override
  State<TutorVerificationPage> createState() => _TutorVerificationPageState();
}

class _TutorVerificationPageState extends State<TutorVerificationPage> {
  final supabase = Supabase.instance.client;
  List<UserProfile> _pendingTutors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingTutors();
  }

  Future<void> _fetchPendingTutors() async {
    try {
      setState(() => _isLoading = true);
      // Fetch users who are tutors but NOT verified
      final response = await supabase
          .from('profiles')
          .select()
          .eq('is_tutor', true)
          .eq('is_verified_tutor', false)
          .limit(50);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _pendingTutors =
              data.map((json) => UserProfile.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending tutors: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyTutor(UserProfile tutor) async {
    try {
      await supabase
          .from('profiles')
          .update({'is_verified_tutor': true}).eq('user_id', tutor.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${tutor.fullName} verified successfully!'),
            backgroundColor: Colors.green));
        _fetchPendingTutors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectTutor(UserProfile tutor) async {
    // For now, rejection just effectively does nothing or we could toggle is_tutor to false.
    // Let's toggle is_tutor to false to "reject" their application.
    try {
      await supabase
          .from('profiles')
          .update({'is_tutor': false}).eq('user_id', tutor.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tutor application rejected.'),
            backgroundColor: Colors.orange));
        _fetchPendingTutors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_pendingTutors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text('No pending tutor verifications',
                style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingTutors.length,
      itemBuilder: (context, index) {
        final tutor = _pendingTutors[index];
        return Card(
          elevation: 0,
          color: theme.cardTheme.color,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundImage: tutor.avatarUrl != null
                  ? NetworkImage(tutor.avatarUrl!)
                  : null,
              child: tutor.avatarUrl == null
                  ? Text(tutor.fullName?.substring(0, 1) ?? 'T')
                  : null,
            ),
            title: Text(tutor.fullName ?? 'Unknown'),
            subtitle: Text(tutor.universityId ?? 'No University ID'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Bio', tutor.bio ?? 'N/A'),
                    _infoRow('Classes', tutor.currentClasses.join(', ')),
                    _infoRow('Hourly Rate', '\$${tutor.hourlyRate}'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _rejectTutor(tutor),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('REJECT'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _verifyTutor(tutor),
                          icon: const Icon(Icons.verified, size: 18),
                          label: const Text('VERIFY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
