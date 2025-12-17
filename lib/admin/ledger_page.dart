import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final supabase = Supabase.instance.client;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  double _totalVolume = 0;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('transactions')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _transactions =
              data.map((json) => Transaction.fromJson(json)).toList();
          _isLoading = false;
          _calculateTotalResponse();
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateTotalResponse() {
    double total = 0;
    for (var t in _transactions) {
      if (t.type == 'payment' || t.type == 'deposit') {
        total += t.amount;
      }
    }
    _totalVolume = total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text('\$${_totalVolume.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? Center(
                      child: Text('No transactions found',
                          style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final isPlus = tx.type == 'deposit' ||
                            tx.type == 'payment'; // Simplified logic
                        return ListTile(
                          leading: Icon(
                            isPlus ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isPlus ? Colors.green : Colors.red,
                          ),
                          title: Text('${tx.type.toUpperCase()}'),
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
  }
}
