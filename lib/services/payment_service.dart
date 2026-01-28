import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../models/transaction.dart';

class PaymentService {
  final SupabaseClient _supabase;

  PaymentService(this._supabase);

  /// Process a deposit using Stripe (top-up).
  Future<bool> deposit(double amount) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. Call Edge Function (Payment Mode)
      // This now returns customerId and ephemeralKey to allow saving/reusing cards
      final response = await _supabase.functions.invoke(
        'stripe-payment',
        body: {
          'amount': amount,
          'user_id': user.id,
          'customer_email': user.email,
          'mode': 'payment', // Explicit mode
          'description': 'Nerd Herd Wallet Top-up',
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to init payment: ${response.data}');
      }

      final data = response.data;
      final clientSecret = data['clientSecret'] as String;
      final customerId = data['customer'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Nerd Herd',
          style: ThemeMode.dark,
          // These two params enable "Saved Cards"
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
        ),
      );

      // 3. Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      return true;
    } catch (e) {
      if (e is StripeException) {
        throw Exception('Payment cancelled: ${e.error.localizedMessage}');
      }
      throw Exception('Deposit failed: ${e.toString()}');
    }
  }

  /// Open the "Manage Payment Methods" sheet (Save/Remove cards).
  Future<void> managePaymentMethods() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. Call Edge Function (Setup Mode)
      final response = await _supabase.functions.invoke(
        'stripe-payment',
        body: {
          'user_id': user.id,
          'customer_email': user.email,
          'mode': 'setup',
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to init setup: ${response.data}');
      }

      final data = response.data;

      // 2. Initialize Customer Sheet
      await Stripe.instance.initCustomerSheet(
        // ignore: deprecated_member_use
        customerSheetInitParams: CustomerSheetInitParams(
          customerId: data['customer'],
          customerEphemeralKeySecret: data['ephemeralKey'],
          merchantDisplayName: 'Nerd Herd',
          style: ThemeMode.dark,
        ),
      );

      // 3. Present
      await Stripe.instance.presentCustomerSheet();
    } catch (e) {
      if (e is StripeException) {
        // User cancelled or error
        return;
      }
      throw Exception('Manage Cards failed: $e');
    }
  }

  /// Simulates a withdrawal of funds.
  Future<bool> withdraw(double amount) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check balance
      final profile = await _supabase
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
      await _supabase.from('transactions').insert({
        'user_id': user.id,
        'amount': -amount, // Negative for withdrawal
        'type': 'withdrawal',
        'description': 'Withdrawal to Bank Account',
      });

      // 2. Update balance
      await _supabase.from('profiles').update({
        'wallet_balance': currentBalance - amount,
      }).eq('user_id', user.id);

      return true;
    } catch (e) {
      throw Exception('Withdrawal failed: ${e.toString()}');
    }
  }

  /// Get transaction history for current user
  Future<List<Transaction>> getHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
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
      await _supabase.rpc('process_payment', params: {
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

  /// Process a sponsorship payment for a study spot.
  Future<bool> paySponsorship(
      String spotId, double amount, String description) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Call the Database Function (RPC)
      await _supabase.rpc('pay_sponsorship', params: {
        'p_user_id': user.id,
        'p_amount': amount,
        'p_description': description,
      });

      return true;
    } catch (e) {
      throw Exception('Sponsorship payment failed: ${e.toString()}');
    }
  }

  /// Refund a payment for an appointment (Tutor -> Student)
  Future<bool> refundPayment(String appointmentId) async {
    try {
      // Fetch appointment details
      final apptData = await _supabase
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
      await _supabase.rpc('process_payment', params: {
        'p_sender_id': hostId,
        'p_receiver_id': attendeeId,
        'p_amount': price,
        'p_description': 'Refund: Cancelled/Declined Session',
      });

      // Update appointment to unpaid status
      await _supabase.from('appointments').update({
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
