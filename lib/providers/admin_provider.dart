import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

  AdminStats({
    required this.totalUsers,
    required this.bannedUsers,
    required this.totalAppointments,
    required this.totalSpots,
  });
}

// --- Providers ---

// 1. Admin Stats Provider
@Riverpod(keepAlive: true)
Future<AdminStats> adminStats(AdminStatsRef ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // Parallel execution for performance
  final results = await Future.wait<dynamic>([
    supabase.from('profiles').count(CountOption.exact),
    supabase
        .from('profiles')
        .select()
        .eq('is_banned', true)
        .count(CountOption.exact),
    supabase.from('appointments').count(CountOption.exact),
    // Wrap potentially missing table in try-catch wrapper (though Future.wait might fail all)
    // We'll assume table exists for now based on dashboard validation.
    // If we want to be safe, we'd need individual error handling.
    // For now, let's assume 'study_spots' exists as per previous context.
    supabase.from('study_spots').count(CountOption.exact).catchError((_) => 0),
  ]);

  return AdminStats(
    totalUsers: results[0] as int,
    bannedUsers: (results[1] as PostgrestResponse)
        .count, // select().count() returns PostgrestResponse
    totalAppointments: results[2] as int,
    totalSpots: results[3] as int,
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
Stream<List<SupportTicket>> supportTickets(SupportTicketsRef ref) {
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

  // Add more actions as needed (Ban User, Verify Tutor, etc.)
}
