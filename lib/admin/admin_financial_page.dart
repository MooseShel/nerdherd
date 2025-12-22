import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
// import 'package:fl_chart/fl_chart.dart'; // Ensure fl_chart is added to pubspec.yaml if not already

class AdminFinancialPage extends StatefulWidget {
  const AdminFinancialPage({super.key});

  @override
  State<AdminFinancialPage> createState() => _AdminFinancialPageState();
}

class _AdminFinancialPageState extends State<AdminFinancialPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  final _currencyFormat = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _supabase.rpc('get_financial_stats');
      setState(() {
        _stats = res as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching financial stats: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading financials: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Financials')),
        body: const Center(child: Text('No data available')),
      );
    }

    final gtv = (_stats!['total_gtv'] as num?)?.toDouble() ?? 0.0;
    final revenue = (_stats!['total_net_revenue'] as num?)?.toDouble() ?? 0.0;
    // final dailyRevenue = (_stats!['daily_revenue'] as List?) ?? []; // Unused for now
    final revenueByStream = (_stats!['revenue_by_stream'] as List?) ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Financial Overview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    context,
                    "Total GTV",
                    gtv,
                    Icons.payments,
                    Colors.blue,
                    subtitle: "Gross Transaction Volume",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    "Net Revenue",
                    revenue,
                    Icons.attach_money,
                    Colors.green,
                    subtitle: "Total Earnings (20% fee)",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Revenue Stream Breakdown
            Text("Revenue Streams", style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (revenueByStream.isEmpty)
              _buildEmptyState(context, "No revenue streams yet")
            else
              Column(
                children: revenueByStream.map<Widget>((stream) {
                  final String name = stream['stream'] ?? 'Unknown';
                  final double val =
                      (stream['total'] as num?)?.toDouble() ?? 0.0;
                  final double percentage = revenue > 0 ? (val / revenue) : 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconForStream(name),
                            color: theme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatStreamName(name),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percentage,
                                backgroundColor:
                                    theme.dividerColor.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.primaryColor),
                                borderRadius: BorderRadius.circular(2),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _currencyFormat.format(val),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            // We could add a chart here if we had fl_chart, but keeping it simple for now with list
            // to ensure no dependency errors if package is missing.
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, double value,
      IconData icon, Color color,
      {String? subtitle}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFormat.format(value),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).disabledColor),
        ),
      ),
    );
  }

  String _formatStreamName(String raw) {
    return raw
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  IconData _getIconForStream(String name) {
    switch (name) {
      case 'platform_fee':
        return Icons.business_center;
      case 'subscription':
        return Icons.star;
      case 'ad_revenue':
        return Icons.campaign;
      default:
        return Icons.monetization_on;
    }
  }
}
