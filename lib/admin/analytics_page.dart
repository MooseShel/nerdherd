import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      data: (stats) {
        // Map user growth data to FlSpots
        final userGrowthSpots = stats.userGrowth.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
        }).toList();

        // Calculate max Y for growth
        final maxUsers = stats.userGrowth.isNotEmpty
            ? stats.userGrowth
                .map((e) => e.count)
                .reduce((a, b) => a > b ? a : b)
            : 10;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Platform Analytics',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time Performance',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildChartCard(
              theme,
              title: 'Total Revenue',
              subtitle: 'From completed transactions',
              chart: Center(
                child: Text(
                  '\$${NumberFormat('#,##0.00').format(stats.totalRevenue)}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              theme,
              title: 'User Growth',
              subtitle: 'Cumulative users over 7 days',
              chart: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox();
                          final index = value.toInt();
                          if (index < 0 || index >= stats.userGrowth.length) {
                            return const SizedBox();
                          }
                          return Text(
                            DateFormat('MM/dd')
                                .format(stats.userGrowth[index].day),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: (maxUsers * 1.2).toDouble(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: userGrowthSpots,
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              theme,
              title: 'Daily Appointments',
              subtitle: 'Last 7 days activity',
              chart: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 ||
                              index >= stats.appointmentActivity.length) {
                            return const SizedBox();
                          }
                          return Text(
                            DateFormat('MM/dd')
                                .format(stats.appointmentActivity[index].day),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups:
                      stats.appointmentActivity.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.count.toDouble(),
                          color: Colors.purpleAccent,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildChartCard(ThemeData theme,
      {required String title,
      required String subtitle,
      required Widget chart}) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.green)),
                ],
              ),
              Icon(Icons.analytics_outlined,
                  color: theme.primaryColor.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: chart),
        ],
      ),
    );
  }
}
