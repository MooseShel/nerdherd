import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_management_page.dart';
import 'appointment_management_page.dart';
import 'spot_management_page.dart';
import 'analytics_page.dart';
import 'tutor_verification_page.dart';
import 'announcements_page.dart';
import 'moderation_page.dart';
import 'ledger_page.dart';
import 'support_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;
  int _totalUsers = 0;
  int _bannedUsers = 0;
  int _totalAppointments = 0;
  int _totalSpots = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final totalUsers =
          await supabase.from('profiles').count(CountOption.exact);
      final bannedUsers = await supabase
          .from('profiles')
          .select()
          .eq('is_banned', true)
          .count(CountOption.exact);

      final totalAppointments =
          await supabase.from('appointments').count(CountOption.exact);

      // Handle potential missing table or error for spots efficiently
      int totalSpots = 0;
      try {
        totalSpots =
            await supabase.from('study_spots').count(CountOption.exact);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalUsers = totalUsers;
          _bannedUsers = bannedUsers.count;
          _totalAppointments = totalAppointments;
          _totalSpots = totalSpots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 10,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Admin Portal',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          foregroundColor: theme.textTheme.bodyLarge?.color,
          bottom: TabBar(
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.textTheme.bodySmall?.color,
            isScrollable: true,
            tabs: const [
              Tab(text: "OVERVIEW"),
              Tab(text: "ANALYTICS"),
              Tab(text: "REPORTS"), // Moderation
              Tab(text: "LEDGER"),
              Tab(text: "SUPPORT"),
              Tab(text: "VERIFICATION"),
              Tab(text: "ANNOUNCEMENTS"),
              Tab(text: "USERS"),
              Tab(text: "APPOINTMENTS"),
              Tab(text: "SPOTS"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(theme),
            const AnalyticsPage(),
            const ModerationPage(),
            const LedgerPage(),
            const SupportPage(),
            const TutorVerificationPage(),
            const AnnouncementsPage(),
            const UserManagementPage(),
            const AppointmentManagementPage(),
            const SpotManagementPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              theme,
              title: 'Total Users',
              value: _totalUsers.toString(),
              icon: Icons.people,
              color: Colors.blueAccent,
            ),
            _buildStatCard(
              theme,
              title: 'Appointments',
              value: _totalAppointments.toString(),
              icon: Icons.calendar_today,
              color: Colors.purpleAccent,
            ),
            _buildStatCard(
              theme,
              title: 'Study Spots',
              value: _totalSpots.toString(),
              icon: Icons.place,
              color: Colors.orangeAccent,
            ),
            _buildStatCard(
              theme,
              title: 'Banned Users',
              value: _bannedUsers.toString(),
              icon: Icons.block,
              color: Colors.redAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme,
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
