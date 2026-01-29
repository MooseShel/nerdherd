import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nerd_herd/providers/wallet_provider.dart';
import 'package:nerd_herd/providers/payment_provider.dart';
import 'package:nerd_herd/providers/user_profile_provider.dart';
import 'package:nerd_herd/models/transaction.dart';
import 'package:nerd_herd/models/user_profile.dart';
import 'package:nerd_herd/services/remote_logger_service.dart';
import 'package:nerd_herd/services/logger_service.dart';
import 'package:flutter/services.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WALLET LOADED: v2.1.7 (Full Error Logging Ready)'),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _handleTopUp() async {
    final profileAsync = ref.read(myProfileProvider);
    final UserProfile? profile = profileAsync.value;

    if (profile == null || profile.stripeCustomerId == null) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add Payment Method'),
            content: const Text(
                'Please add a saved credit card in "Manage Saved Cards" before you can top up your wallet.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleManageCards();
                },
                child: const Text('Add Card Now'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter amount to deposit'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '\$ ',
                hintText: '20.00',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isActionLoading = true);
      try {
        await ref.read(paymentControllerProvider.notifier).deposit(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Top-up successful!'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _showErrorDialog(String title, dynamic error) async {
    final errorMsg = error.toString();
    logger.remoteError('$title | UI Dialog', error: error);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following error occurred:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorMsg,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This error has been logged automatically. You can also copy it to send to support.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: errorMsg));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error copied to clipboard')),
              );
            },
            child: const Text('Copy Error'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWithdraw() async {
    final currentBalance = ref.read(walletBalanceProvider).value ?? 0.0;
    if (currentBalance <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient funds to withdraw.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance: \$${currentBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Enter amount to withdraw:'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                if (amount > currentBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Amount exceeds balance'),
                        backgroundColor: Colors.red),
                  );
                } else {
                  Navigator.pop(context, amount);
                }
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isActionLoading = true);
      try {
        await ref.read(paymentControllerProvider.notifier).withdraw(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Withdrawal processed successfully!'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _handleManageCards() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting Stripe Manage Cards (v2.1.5)...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    setState(() => _isActionLoading = true);
    try {
      await ref.read(paymentControllerProvider.notifier).manageCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manage Cards Call Finished'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Manage Cards Failed', e);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanceAsync = ref.watch(walletBalanceProvider);
    final historyAsync = ref.watch(paymentHistoryProvider);
    // Ensure profile is watched so it's fresh for _handleTopUp
    ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildWalletHeader(theme, balanceAsync),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('My Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Build v2.1.7 - Diagnostic Release',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Top Up',
                      icon: Icons.add_circle_outline,
                      color: theme.primaryColor,
                      onTap: _handleTopUp,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Withdraw',
                      icon: Icons.account_balance_wallet_outlined,
                      color: (balanceAsync.value ?? 0) > 0
                          ? Colors.amber
                          : Colors.grey,
                      onTap: (balanceAsync.value ?? 0) > 0
                          ? () => _handleWithdraw()
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!kIsWeb)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20)
                  .copyWith(top: 8, bottom: 8),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading ? null : _handleManageCards,
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Manage Saved Cards'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Recent Transactions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _buildTransactionList(theme, historyAsync),
        ],
      ),
    );
  }

  Widget _buildWalletHeader(ThemeData theme, AsyncValue<double> balanceAsync) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor,
            theme.colorScheme.tertiary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Current Balance',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                ),
                const SizedBox(height: 8),
                balanceAsync.when(
                  data: (balance) => Text(
                    '\$${NumberFormat('#,##0.00').format(balance)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () =>
                      const CircularProgressIndicator(color: Colors.white),
                  error: (_, __) => const Text('---',
                      style: TextStyle(color: Colors.white, fontSize: 48)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: _isActionLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
      ThemeData theme, AsyncValue<List<Transaction>> historyAsync) {
    return historyAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text('No transactions yet.')),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final tx = transactions[index];
              final isPositive = tx.amount > 0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isPositive ? Colors.green : Colors.red)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
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
                            tx.description ?? tx.type.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('MMM d, h:mm a').format(tx.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}\$${tx.amount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
            childCount: transactions.length,
          ),
        );
      },
      loading: () => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator())),
      error: (err, __) =>
          SliverFillRemaining(child: Center(child: Text('Error: $err'))),
    );
  }
}
