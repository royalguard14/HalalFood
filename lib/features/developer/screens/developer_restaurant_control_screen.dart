import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeveloperRestaurantControlScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const DeveloperRestaurantControlScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<DeveloperRestaurantControlScreen> createState() =>
      _DeveloperRestaurantControlScreenState();
}

class _DeveloperRestaurantControlScreenState
    extends State<DeveloperRestaurantControlScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  bool _deletingVault = false;

  double _cashReceived = 0;
  double _gcashReceived = 0;
  double _gcashCashouts = 0;
  double _cashAdjustments = 0;
  double _gcashAdjustments = 0;

  List<Map<String, dynamic>> _adjustments = [];

  double get _cashBalance => _cashReceived + _cashAdjustments;
  double get _gcashBalance =>
      _gcashReceived + _gcashAdjustments - _gcashCashouts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    try {
      final orders = await _supabase
          .from('orders')
          .select('id')
          .eq('restaurant_id', widget.restaurantId);

      final ids = orders
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .toList();

      final payments = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await _supabase
              .from('payments')
              .select('amount,payment_method,status')
              .eq('status', 'paid')
              .inFilter('order_id', ids);

      final cashouts = await _supabase
          .from('owner_gcash_cashouts')
          .select('amount')
          .eq('restaurant_id', widget.restaurantId);

      final adjustments = await _supabase
          .from('developer_restaurant_vault_adjustments')
          .select('id,vault_type,amount,notes,created_at')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);

      double cash = 0;
      double gcash = 0;

      for (final row in payments) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final method = row['payment_method']?.toString().toLowerCase();

        if (method == 'cash_on_delivery') cash += amount;
        if (method == 'gcash') gcash += amount;
      }

      final out = cashouts.fold<double>(
        0,
        (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
      );

      double cashAdjustments = 0;
      double gcashAdjustments = 0;

      for (final row in adjustments) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (row['vault_type'] == 'cash') cashAdjustments += amount;
        if (row['vault_type'] == 'gcash') gcashAdjustments += amount;
      }

      if (!mounted) return;

      setState(() {
        _cashReceived = cash;
        _gcashReceived = gcash;
        _gcashCashouts = out;
        _cashAdjustments = cashAdjustments;
        _gcashAdjustments = gcashAdjustments;
        _adjustments = adjustments
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load vault: $e')),
      );
    }
  }

  Future<void> _adjust(String vault) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => _VaultAdjustmentDialog(vault: vault),
    );

    if (result == null || !mounted) return;

    final value = double.tryParse(result[0].replaceAll(',', ''));

    if (value == null || value == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a non-zero amount.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _supabase.rpc(
        'developer_record_vault_adjustment',
        params: {
          'p_restaurant_id': widget.restaurantId,
          'p_vault_type': vault,
          'p_amount': value,
          'p_notes': result[1].isEmpty ? null : result[1],
        },
      );

      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Adjustment failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteVaultData() async {
    if (_deletingVault || _saving || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Clear Entire Vault?')),
          ],
        ),
        content: const Text(
          'This permanently deletes all developer vault adjustment records '
          'for this restaurant.\n\n'
          'Orders, payments, GCash cashouts, and restaurant data will NOT be deleted.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear Entire Vault'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingVault = true);

    try {
      final result = await _supabase.rpc(
        'developer_clear_entire_vault',
        params: {'p_restaurant_id': widget.restaurantId},
      );

      if (!mounted) return;

      await _load();
      if (!mounted) return;

      final deletedAdjustments = result is Map
          ? (result['deleted_adjustments'] ?? 0).toString()
          : '0';
      final deletedCashouts = result is Map
          ? (result['deleted_gcash_cashouts'] ?? 0).toString()
          : '0';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Entire vault cleared. $deletedAdjustments adjustment(s) and '
            '$deletedCashouts GCash cashout(s) removed.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Unable to delete vault data: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingVault = false);
    }
  }

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return '—';

    final datePart = '${date.month}/${date.day}/${date.year}';
    final timePart =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return '$datePart $timePart';
  }

  Widget _vault(
    String title,
    double balance,
    IconData icon,
    VoidCallback onAdjust,
  ) {
    final isCash = title == 'Cash Vault';
    final received = isCash ? _cashReceived : _gcashReceived;
    final adjustments = isCash ? _cashAdjustments : _gcashAdjustments;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '₱${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text('Received: ₱${received.toStringAsFixed(2)}'),
            Text('Developer adjustments: ₱${adjustments.toStringAsFixed(2)}'),
            if (!isCash)
              Text('GCash cashouts: ₱${_gcashCashouts.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving || _deletingVault ? null : onAdjust,
                icon: const Icon(Icons.tune_rounded),
                label: const Text(
                  'Manipulate Vault',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.restaurantName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _saving || _deletingVault ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const Text(
                    'Restaurant Control',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Developer-only financial control. Positive adjustments add funds; negative adjustments subtract funds.',
                  ),
                  const SizedBox(height: 16),
                  _vault(
                    'Cash Vault',
                    _cashBalance,
                    Icons.payments_rounded,
                    () => _adjust('cash'),
                  ),
                  const SizedBox(height: 12),
                  _vault(
                    'GCash Vault',
                    _gcashBalance,
                    Icons.phone_android_rounded,
                    () => _adjust('gcash'),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    color: Colors.red.withValues(alpha: 0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Danger Zone',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Clear the entire vault for this restaurant: developer adjustments and GCash cashout records. Orders and payment records are preserved.',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _saving || _deletingVault
                                  ? null
                                  : _deleteVaultData,
                              icon: _deletingVault
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.delete_forever_rounded),
                              label: Text(
                                _deletingVault
                                    ? 'Clearing Entire Vault...'
                                    : 'Clear Entire Vault',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Developer Adjustment History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_adjustments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No developer adjustments recorded.'),
                      ),
                    )
                  else
                    ..._adjustments.map((row) {
                      final amount =
                          (row['amount'] as num?)?.toDouble() ?? 0;
                      final vaultType = row['vault_type']?.toString() ?? '';
                      final notes = row['notes']?.toString() ?? '';
                      final noteText = notes.isNotEmpty ? '$notes\n' : '';

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            vaultType == 'cash'
                                ? Icons.payments_rounded
                                : Icons.phone_android_rounded,
                          ),
                          title: Text(
                            '${vaultType == 'cash' ? 'Cash' : 'GCash'}  ${amount >= 0 ? '+' : '−'} ₱${amount.abs().toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '$noteText${_date(row['created_at']?.toString())}',
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _VaultAdjustmentDialog extends StatefulWidget {
  final String vault;

  const _VaultAdjustmentDialog({required this.vault});

  @override
  State<_VaultAdjustmentDialog> createState() => _VaultAdjustmentDialogState();
}

class _VaultAdjustmentDialogState extends State<_VaultAdjustmentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultName = widget.vault == 'cash' ? 'Cash' : 'GCash';

    return AlertDialog(
      title: Text('$vaultName Vault Adjustment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                helperText: 'Positive adds funds; negative subtracts funds.',
                prefixText: '₱ ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason / Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            [
              _amountController.text.trim(),
              _notesController.text.trim(),
            ],
          ),
          child: const Text('Save Adjustment'),
        ),
      ],
    );
  }
}
