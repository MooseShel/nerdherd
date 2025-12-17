import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/admin_provider.dart';
import 'package:intl/intl.dart';

class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  // Logic moved to Ledger Provider

  double _calculateTotal(List<Transaction> transactions) {
    double total = 0;
    for (var t in transactions) {
      if (t.type == 'payment' || t.type == 'deposit') {
        total += t.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledgerAsync = ref.watch(ledgerProvider);

    return ledgerAsync.when(
      data: (transactions) {
        final totalVolume = _calculateTotal(transactions);
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Volume (Latest 100)',
                      style: theme.textTheme.bodyMedium),
                  Text('\$${totalVolume.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text('No transactions found',
                          style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isPlus =
                            tx.type == 'deposit' || tx.type == 'payment';
                        return ListTile(
                          leading: Icon(
                            isPlus ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isPlus ? Colors.green : Colors.red,
                          ),
                          title: Text(tx.type.toUpperCase()),
                          subtitle: Text(DateFormat('yyyy-MM-dd HH:mm')
                              .format(tx.createdAt)),
                          trailing: Text(
                            '${isPlus ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isPlus ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
