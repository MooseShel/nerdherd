import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import '../models/transaction.dart';
import '../widgets/ui_components.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final supabase = Supabase.instance.client;

  Stream<List<Transaction>>? _transactionsStream;
  Stream<Map<String, dynamic>>? _balanceStream;
  bool _isProcessingAudio = false;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Stream for wallet balance
    _balanceStream = supabase
        .from('profiles')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', user.id)
        .map((data) => data.isNotEmpty ? data.first : {});

    // Stream for transactions
    _transactionsStream = supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((data) {
          final list = data.map((json) => Transaction.fromJson(json)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> _handleTopUp() async {
    final amountController = TextEditingController();
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: Text('Top Up Wallet', style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter amount to deposit:', style: theme.textTheme.bodyMedium),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.primaryColor)),
                focusedBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: theme.primaryColor, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.disabledColor)),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              Navigator.pop(context);

              try {
                setState(() => _isProcessingAudio = true);
                await paymentService.deposit(amount);
                if (!context.mounted) return;

                setState(() => _isProcessingAudio = false);
                showSuccessSnackBar(context, 'Successfully added \$$amount');
              } catch (e) {
                if (!context.mounted) return;
                setState(() => _isProcessingAudio = false);
                showErrorSnackBar(context, e.toString());
              }
            },
            style: FilledButton.styleFrom(backgroundColor: theme.primaryColor),
            child: const Text('Pay with Card'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWithdraw(double currentBalance) async {
    final amountController = TextEditingController();
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: Text('Withdraw Funds', style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: \$${currentBalance.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.primaryColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.disabledColor)),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              if (amount > currentBalance) {
                showErrorSnackBar(context, 'Insufficient funds');
                return;
              }
              Navigator.pop(context);

              try {
                setState(() => _isProcessingAudio = true);
                await paymentService.withdraw(amount);
                if (!context.mounted) return;

                setState(() => _isProcessingAudio = false);
                showSuccessSnackBar(context, 'Withdrawal initiated: \$$amount');
              } catch (e) {
                if (!context.mounted) return;
                setState(() => _isProcessingAudio = false);
                showErrorSnackBar(context, e.toString());
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Wallet',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _balanceStream,
        builder: (context, balanceSnapshot) {
          final balance =
              (balanceSnapshot.data?['wallet_balance'] as num?)?.toDouble() ??
                  0.0;

          return StreamBuilder<List<Transaction>>(
            stream: _transactionsStream,
            builder: (context, transactionSnapshot) {
              final transactions = transactionSnapshot.data ?? [];

              if (balanceSnapshot.connectionState == ConnectionState.waiting &&
                  !balanceSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance Card
                  _buildBalanceCard(theme, balance),
                  const SizedBox(height: 24),

                  // Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(theme, 'Top Up',
                            Icons.add_card, Colors.blueAccent, _handleTopUp),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                            theme,
                            'Withdraw',
                            Icons.account_balance,
                            Colors.orangeAccent,
                            () => _handleWithdraw(balance)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (transactions.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.receipt_long,
                      title: 'No Transactions',
                      description: 'Your transaction history will appear here.',
                    )
                  else
                    ...transactions.map((t) => _buildTransactionItem(theme, t)),
                ],
              );
            },
          );
        },
      ),
      bottomSheet: _isProcessingAudio
          ? Container(
              color: Colors.black54,
              height: 80,
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Processing Payment...',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBalanceCard(ThemeData theme, double balance) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${balance.toStringAsFixed(2)}',
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                'Secured by Stripe (Mock)',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
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
            Text(label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(ThemeData theme, Transaction t) {
    final isPositive = t.amount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
              color: isPositive ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description ?? t.type.toUpperCase(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  t.createdAt.toString().split('.')[0], // Simple cleanup
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}\$${t.amount.abs().toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
