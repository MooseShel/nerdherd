import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';

class PaymentService {
  final supabase = Supabase.instance.client;

  /// Simulates a deposit of funds into the user's wallet.
  ///
  /// In a real app, this would involve a Stripe PaymentIntent.
  Future<bool> deposit(double amount) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Simulate network delay for payment processing
      await Future.delayed(const Duration(seconds: 2));

      // 1. Log transaction
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'amount': amount,
        'type': 'deposit',
        'description': 'Top up via Card ending in 4242',
      });

      // 2. Update wallet balance (using a stored procedure is safer but this works for MVP)
      // Fetch current balance first to be safe, or use Postgres increment if possible.
      // For MVP, we'll just read-modify-write knowing race conditions exist.
      final profile = await supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('user_id', user.id)
          .single();
      final currentBalance =
          (profile['wallet_balance'] as num?)?.toDouble() ?? 0.0;

      await supabase.from('profiles').update({
        'wallet_balance': currentBalance + amount,
      }).eq('user_id', user.id);

      return true;
    } catch (e) {
      throw Exception('Deposit failed: ${e.toString()}');
    }
  }

  /// Simulates a withdrawal of funds.
  Future<bool> withdraw(double amount) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check balance
      final profile = await supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('user_id', user.id)
          .single();
      final currentBalance =
          (profile['wallet_balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        throw Exception('Insufficient funds');
      }

      await Future.delayed(const Duration(seconds: 2));

      // 1. Log transaction
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'amount': -amount, // Negative for withdrawal
        'type': 'withdrawal',
        'description': 'Withdrawal to Bank Account',
      });

      // 2. Update balance
      await supabase.from('profiles').update({
        'wallet_balance': currentBalance - amount,
      }).eq('user_id', user.id);

      return true;
    } catch (e) {
      throw Exception('Withdrawal failed: ${e.toString()}');
    }
  }

  /// Get transaction history for current user
  Future<List<Transaction>> getHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Transaction.fromJson(json))
        .toList();
  }

  /// Process a payment from one user to another (e.g. Student to Tutor)
  Future<bool> processPayment(String senderId, String receiverId, double amount,
      String description) async {
    try {
      if (amount <= 0) return true; // No payment needed

      // Use the secure Database Function (RPC) to handle the transfer atomically
      // and bypass RLS for the receiver's transaction record.
      await supabase.rpc('process_payment', params: {
        'p_sender_id': senderId,
        'p_receiver_id': receiverId,
        'p_amount': amount,
        'p_description': description,
      });

      return true;
    } catch (e) {
      // Improve error message if possible
      final msg = e.toString();
      if (msg.contains('Insufficient funds')) {
        throw Exception('Insufficient funds in wallet.');
      }
      throw Exception('Payment failed: $msg');
    }
  }

  /// Refund a payment for an appointment (Tutor -> Student)
  Future<bool> refundPayment(String appointmentId) async {
    try {
      // Fetch appointment details
      final apptData = await supabase
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .single();

      final price = (apptData['price'] as num?)?.toDouble() ?? 0.0;
      final isPaid = apptData['is_paid'] as bool? ?? false;
      final hostId = apptData['host_id'] as String;
      final attendeeId = apptData['attendee_id'] as String;

      if (!isPaid || price <= 0) return true; // Nothing to refund

      // Reverse transaction: Host (Tutor) pays back Attendee (Student)
      // We use the same RPC function.
      await supabase.rpc('process_payment', params: {
        'p_sender_id': hostId,
        'p_receiver_id': attendeeId,
        'p_amount': price,
        'p_description': 'Refund: Cancelled/Declined Session',
      });

      // Update appointment to unpaid status
      await supabase.from('appointments').update({
        'is_paid': false,
        // We leave price reference but mark unpaid
      }).eq('id', appointmentId);

      return true;
    } catch (e) {
      // logger.error("Refund error", error: e); // Assuming logger is available or just silence it safely
      return false;
    }
  }
}

final paymentService = PaymentService();
