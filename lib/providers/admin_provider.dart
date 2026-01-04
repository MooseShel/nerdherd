import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../models/transaction.dart';
import '../models/support_ticket.dart';
import '../services/logger_service.dart';

part 'admin_provider.g.dart';

// --- Models ---

class AdminStats {
  final int totalUsers;
  final int bannedUsers;
  final int totalAppointments;
  final int totalSpots;
  final double totalRevenue;
  final List<TimeSeriesData> userGrowth;
  final List<TimeSeriesData> appointmentActivity;

  AdminStats({
    required this.totalUsers,
    required this.bannedUsers,
    required this.totalAppointments,
    required this.totalSpots,
    required this.totalRevenue,
    required this.userGrowth,
    required this.appointmentActivity,
  });
}

class TimeSeriesData {
  final DateTime day;
  final int count;

  TimeSeriesData({required this.day, required this.count});

  factory TimeSeriesData.fromJson(Map<String, dynamic> json) {
    return TimeSeriesData(
      day: DateTime.parse(json['day']),
      count: json['count'] ?? 0,
    );
  }
}

// --- Providers ---

// 1. Admin Stats Provider
@Riverpod(keepAlive: true)
Future<AdminStats> adminStats(Ref ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // Fetch complex stats via RPC
  final rpcResponse = await supabase.rpc('get_platform_stats');
  final data = rpcResponse as Map<String, dynamic>;

  // Fetch banned count separately as it is not in the RPC yet (or we can add it to RPC)
  // Let's stick to the RPC for everything eventually, but for now combine
  final bannedResult = await supabase
      .from('profiles')
      .select()
      .eq('is_banned', true)
      .count(CountOption.exact);

  final spotsCount = await supabase
      .from('study_spots')
      .count(CountOption.exact)
      .catchError((_) => 0);

  return AdminStats(
    totalUsers: data['total_users'] ?? 0,
    bannedUsers: bannedResult.count,
    totalAppointments: data['total_appointments'] ?? 0,
    totalSpots: spotsCount,
    totalRevenue: (data['total_revenue'] ?? 0).toDouble(),
    userGrowth: (data['user_growth'] as List)
        .map((e) => TimeSeriesData.fromJson(e))
        .toList(),
    appointmentActivity: (data['appointment_activity'] as List)
        .map((e) => TimeSeriesData.fromJson(e))
        .toList(),
  );
}

// 2. Ledger Provider (Transactions)
@Riverpod(keepAlive: true)
class Ledger extends _$Ledger {
  @override
  Future<List<Transaction>> build() async {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase
        .from('transactions')
        .select()
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((e) => Transaction.fromJson(e)).toList();
  }

  // Future: Add pagination loadMore() if needed
}

// 3. Support Tickets Provider (Realtime Stream)
@Riverpod(keepAlive: true)
Stream<List<SupportTicket>> supportTickets(Ref ref) {
  final supabase = ref.watch(supabaseClientProvider);

  // Fetch initial data + Subscribe
  final streamController = StreamController<List<SupportTicket>>();

  // Initial Fetch
  Future<void> fetchInitial() async {
    try {
      final response = await supabase
          .from('support_tickets')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: true);

      final tickets =
          (response as List).map((e) => SupportTicket.fromJson(e)).toList();
      streamController.add(tickets);
    } catch (e) {
      streamController.addError(e);
    }
  }

  fetchInitial();

  final subscription = supabase
      .channel('public:support_tickets')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'support_tickets',
        callback: (payload) {
          // Simplest approach: Refetch on any change to keep correct order/filter
          // Optimization: Handle Insert/Update manually to avoid full refetch
          fetchInitial();
        },
      )
      .subscribe();

  ref.onDispose(() {
    subscription.unsubscribe();
    streamController.close();
  });

  return streamController.stream;
}

// 4. Admin Actions
@Riverpod(keepAlive: true)
class AdminController extends _$AdminController {
  @override
  void build() {}

  Future<void> resolveTicket(String ticketId) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('support_tickets')
          .update({'status': 'closed'}).eq('id', ticketId);
      // The stream provider will auto-update because of the realtime subscription
    } catch (e) {
      logger.error("Failed to resolve ticket", error: e);
      rethrow;
    }
  }

  Future<void> banUser(String userId) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('profiles')
          .update({'is_banned': true}).eq('user_id', userId);
      // Invalidate stats to reflect the new banned count
      ref.invalidate(adminStatsProvider);
    } catch (e) {
      logger.error("Failed to ban user", error: e);
      rethrow;
    }
  }

  // Add more actions as needed (Ban User, Verify Tutor, etc.)
}
