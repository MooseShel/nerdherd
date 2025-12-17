import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/payment_service.dart';
import 'auth_provider.dart';
import '../models/transaction.dart';

part 'payment_provider.g.dart';

@Riverpod(keepAlive: true)
PaymentService paymentService(PaymentServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PaymentService(supabase);
}

@Riverpod(keepAlive: true)
Future<List<Transaction>> paymentHistory(PaymentHistoryRef ref) async {
  final service = ref.watch(paymentServiceProvider);
  // We should also watch authState to refetch on user change, but service fetches current user anyway.
  final authState = ref.watch(authStateProvider);
  if (authState.value == null) return [];

  return service.getHistory();
}

// Controller for actions (optional, can just use service directly via ref.read)
@Riverpod(keepAlive: true)
class PaymentController extends _$PaymentController {
  @override
  void build() {}

  Future<void> deposit(double amount) async {
    final service = ref.read(paymentServiceProvider);
    await service.deposit(amount);
    ref.invalidate(paymentHistoryProvider); // Refresh history
  }

  Future<void> withdraw(double amount) async {
    final service = ref.read(paymentServiceProvider);
    await service.withdraw(amount);
    ref.invalidate(paymentHistoryProvider);
  }

  Future<void> processPayment(String senderId, String receiverId, double amount,
      String description) async {
    final service = ref.read(paymentServiceProvider);
    await service.processPayment(senderId, receiverId, amount, description);
    ref.invalidate(paymentHistoryProvider);
  }
}
