import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerGcashVaultScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerGcashVaultScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerGcashVaultScreen> createState() => _OwnerGcashVaultScreenState();
}

class _OwnerGcashVaultScreenState extends State<OwnerGcashVaultScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  double _received = 0;
  double _cashouts = 0;
  double _adjustments = 0;
  List<Map<String, dynamic>> _cashoutRows = [];

  double get _balance => _received + _adjustments - _cashouts;

  @override
  void initState() {
    super.initState();
    _loadVault();
  }

  Future<void> _loadVault() async {
    if (mounted) setState(() => _loading = true);
    try {
      final payments = await _supabase
          .from('payments')
          .select('amount,paid_at,created_at,order_id')
          .eq('payment_method', 'gcash')
          .eq('status', 'paid')
          .order('paid_at', ascending: false);

      final cashouts = await _supabase
          .from('owner_gcash_cashouts')
          .select('id,amount,notes,created_at')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);

      final adjustments = await _supabase
          .from('developer_restaurant_vault_adjustments')
          .select('amount')
          .eq('restaurant_id', widget.restaurantId)
          .eq('vault_type', 'gcash');

      double received = 0;
      for (final row in payments as List) {
        final orderId = row['order_id']?.toString();
        if (orderId == null) continue;
        final order = await _supabase
            .from('orders')
            .select('restaurant_id')
            .eq('id', orderId)
            .maybeSingle();
        if (order?['restaurant_id']?.toString() == widget.restaurantId) {
          received += (row['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _received = received;
        _cashoutRows = (cashouts as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _adjustments = (adjustments as List).fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
        _cashouts = _cashoutRows.fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load GCash Vault: $e')),
      );
    }
  }

  Future<void> _cashOut() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cash Out from GCash Vault'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cashout Amount',
                prefixText: '₱ ',
                helperText: 'Available: ₱${_balance.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                amountController.text.trim().replaceAll(',', ''),
              );
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid cashout amount.')),
                );
                return;
              }
              Navigator.pop(dialogContext, [
                amount.toString(),
                notesController.text.trim(),
              ]);
            },
            child: const Text('Cash Out'),
          ),
        ],
      ),
    );

    amountController.dispose();
    notesController.dispose();
    if (result == null || !mounted) return;

    try {
      await _supabase.rpc(
        'record_owner_gcash_cashout',
        params: {
          'p_restaurant_id': widget.restaurantId,
          'p_amount': double.parse(result[0]),
          'p_notes': result[1].isEmpty ? null : result[1],
        },
      );
      await _loadVault();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to cash out: $e')),
        );
      }
    }
  }

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return '—';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day}/${date.year} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GCash Vault',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadVault,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVault,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available GCash Balance',
                            style: TextStyle(
                              color: HalalFoodTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₱${_balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: HalalFoodTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'GCash received: ₱${_received.toStringAsFixed(2)}',
                          ),
                          Text('Developer adjustments: ₱${_adjustments.toStringAsFixed(2)}'),
                          Text('Cashed out: ₱${_cashouts.toStringAsFixed(2)}'),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _balance <= 0 ? null : _cashOut,
                              icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              label: const Text(
                                'Cash Out',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cashout History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_cashoutRows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No cashouts recorded yet.'),
                      ),
                    )
                  else
                    ..._cashoutRows.map(
                      (row) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.outbox_rounded),
                          ),
                          title: Text(
                            '- ₱${((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${row['notes']?.toString().isNotEmpty == true ? '${row['notes']}\n' : ''}${_date(row['created_at']?.toString())}',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
