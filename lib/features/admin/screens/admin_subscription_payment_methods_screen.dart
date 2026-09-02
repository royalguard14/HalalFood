import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSubscriptionPaymentMethodsScreen extends StatefulWidget {
  const AdminSubscriptionPaymentMethodsScreen({super.key});

  @override
  State<AdminSubscriptionPaymentMethodsScreen> createState() =>
      _AdminSubscriptionPaymentMethodsScreenState();
}

class _AdminSubscriptionPaymentMethodsScreenState
    extends State<AdminSubscriptionPaymentMethodsScreen> {
  final db = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> methods = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final result = await db
          .from('subscription_payment_methods')
          .select()
          .order('sort_order')
          .order('created_at');
      if (mounted) {
        setState(() {
          methods = List<Map<String, dynamic>>.from(result);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load payment methods: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> values, String? id) async {
    try {
      if (id == null) {
        await db.from('subscription_payment_methods').insert(values);
      } else {
        await db
            .from('subscription_payment_methods')
            .update(values)
            .eq('id', id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save payment method: $e')),
        );
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> method) async {
    try {
      await db
          .from('subscription_payment_methods')
          .update({'is_active': method['is_active'] != true})
          .eq('id', method['id']);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update payment method: $e')),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text(
          'Delete ${method['name'] ?? 'this payment method'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await db
          .from('subscription_payment_methods')
          .delete()
          .eq('id', method['id']);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete payment method: $e')),
        );
      }
    }
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _showForm([Map<String, dynamic>? existing]) async {
    final controllers = <String, TextEditingController>{
      for (final key in [
        'name',
        'type',
        'account_name',
        'account_number',
        'instructions',
        'qr_code_url',
        'sort_order',
      ])
        key: TextEditingController(
          text: existing?[key]?.toString() ??
              (key == 'type'
                  ? 'gcash'
                  : key == 'sort_order'
                      ? '${methods.length + 1}'
                      : ''),
        ),
    };

    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null
                      ? 'Add Payment Method'
                      : 'Edit Payment Method',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ...controllers.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: entry.value,
                      maxLines: entry.key == 'instructions' ? 4 : 1,
                      keyboardType: entry.key == 'sort_order'
                          ? TextInputType.number
                          : null,
                      decoration: InputDecoration(
                        labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: () {
                    final formValues = <String, dynamic>{
                      'name': controllers['name']!.text.trim(),
                      'type': controllers['type']!.text.trim().toLowerCase(),
                      'account_name':
                          _nullable(controllers['account_name']!.text),
                      'account_number':
                          _nullable(controllers['account_number']!.text),
                      'instructions':
                          _nullable(controllers['instructions']!.text),
                      'qr_code_url':
                          _nullable(controllers['qr_code_url']!.text),
                      'sort_order':
                          int.tryParse(controllers['sort_order']!.text) ?? 0,
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    };
                    Navigator.of(sheetContext).pop(formValues);
                  },
                  child: const Text('Save Payment Method'),
                ),
              ],
            ),
          ),
        );
      },
    );

    // The controllers belong only to this short-lived form. Do not dispose
    // them here because the bottom-sheet route may still be completing its
    // widget teardown when showModalBottomSheet returns.
    if (values != null && mounted) {
      await _save(values, existing?['id']?.toString());
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      case 'gcash':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Method'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Subscription Payment Methods',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enabled methods will be shown to restaurant owners when they subscribe.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (methods.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No payment methods configured yet.'),
                      ),
                    ),
                  ...methods.map(
                    (method) => Card(
                      child: ListTile(
                        leading: Icon(_iconFor(method['type']?.toString())),
                        title: Text(
                          method['name']?.toString() ?? 'Payment Method',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [method['account_name'], method['account_number']]
                              .where(
                                (value) =>
                                    value != null &&
                                    value.toString().isNotEmpty,
                              )
                              .join(' • '),
                        ),
                        trailing: Wrap(
                          children: [
                            Switch(
                              value: method['is_active'] == true,
                              onChanged: (_) => _toggle(method),
                            ),
                            IconButton(
                              onPressed: () => _showForm(method),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              onPressed: () => _delete(method),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
