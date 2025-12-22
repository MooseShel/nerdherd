import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import 'user_management_page.dart';
import 'appointment_management_page.dart';
import 'spot_management_page.dart';
import 'analytics_page.dart';
import 'tutor_verification_page.dart';
import 'announcements_page.dart';
import 'moderation_page.dart';
import 'ledger_page.dart';
import 'support_page.dart';

import 'admin_financial_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  // Stats are now handled by Provider

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 11,
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
              Tab(text: "FINANCIALS"), // New Tab
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
            const AdminFinancialPage(), // New Page
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
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard(
                    theme,
                    title: 'Total Users',
                    value: stats.totalUsers.toString(),
                    icon: Icons.people,
                    color: Colors.blueAccent,
                  ),
                  _buildStatCard(
                    theme,
                    title: 'Appointments',
                    value: stats.totalAppointments.toString(),
                    icon: Icons.calendar_today,
                    color: Colors.purpleAccent,
                  ),
                  _buildStatCard(
                    theme,
                    title: 'Study Spots',
                    value: stats.totalSpots.toString(),
                    icon: Icons.place,
                    color: Colors.orangeAccent,
                  ),
                  _buildStatCard(
                    theme,
                    title: 'Banned Users',
                    value: stats.bannedUsers.toString(),
                    icon: Icons.block,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading stats: $err')),
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
