import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerPromoManagementScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerPromoManagementScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerPromoManagementScreen> createState() => _OwnerPromoManagementScreenState();
}

class _OwnerPromoManagementScreenState extends State<OwnerPromoManagementScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _promos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _db
          .from('promo_codes')
          .select()
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _promos = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _msg('Unable to load promos: $e');
      }
    }
  }

  Future<void> _save({Map<String, dynamic>? promo}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PromoFormDialog(promo: promo),
    );

    if (result == null) return;

    final data = {
      'restaurant_id': widget.restaurantId,
      'code': result['code'],
      'title': result['title'],
      'discount_type': result['discount_type'],
      'discount_value': result['discount_value'],
      'minimum_order': result['minimum_order'],
      'is_active': result['is_active'],
    };

    try {
      if (promo == null) {
        await _db.from('promo_codes').insert(data);
      } else {
        await _db
            .from('promo_codes')
            .update(data)
            .eq('id', promo['id'])
            .eq('restaurant_id', widget.restaurantId);
      }
      await _load();
    } catch (e) {
      _msg('Unable to save promo: $e');
    }
  }

  Future<void> _toggle(Map<String, dynamic> promo) async {
    try {
      await _db
          .from('promo_codes')
          .update({'is_active': promo['is_active'] != true})
          .eq('id', promo['id'])
          .eq('restaurant_id', widget.restaurantId);
      await _load();
    } catch (e) {
      _msg('Unable to update promo: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> promo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promo'),
        content: Text('Delete ${promo['code']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db
          .from('promo_codes')
          .delete()
          .eq('id', promo['id'])
          .eq('restaurant_id', widget.restaurantId);
      await _load();
    } catch (e) {
      _msg('Unable to delete promo: $e');
    }
  }

  void _msg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promos & Discounts', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _save(),
        icon: const Icon(Icons.add),
        label: const Text('Create Promo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? const Center(child: Text('No promos for this restaurant yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _promos.length,
                    itemBuilder: (context, index) {
                      final promo = _promos[index];
                      final type = promo['discount_type'];
                      final value = promo['discount_value'];
                      final active = promo['is_active'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => _save(promo: promo),
                          leading: const CircleAvatar(child: Icon(Icons.local_offer_rounded)),
                          title: Text(
                            promo['code']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${promo['title'] ?? ''}\n${type == 'percentage' ? '$value% OFF' : '₱$value OFF'}  •  Min ₱${promo['minimum_order'] ?? 0}',
                            maxLines: 2,
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(value: active, onChanged: (_) => _toggle(promo)),
                              IconButton(
                                onPressed: () => _delete(promo),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _PromoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? promo;

  const _PromoFormDialog({this.promo});

  @override
  State<_PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<_PromoFormDialog> {
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _minimum;
  late String _type;
  late bool _active;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final promo = widget.promo;
    _code = TextEditingController(text: promo?['code']?.toString() ?? '');
    _title = TextEditingController(text: promo?['title']?.toString() ?? '');
    _value = TextEditingController(text: promo?['discount_value']?.toString() ?? '');
    _minimum = TextEditingController(text: promo?['minimum_order']?.toString() ?? '0');
    _type = promo?['discount_type']?.toString() ?? 'percentage';
    _active = promo?['is_active'] != false;
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _value.dispose();
    _minimum.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final discount = double.tryParse(_value.text.trim());
    final minimum = double.tryParse(_minimum.text.trim()) ?? 0;
    if (discount == null || discount <= 0) return;

    Navigator.of(context).pop({
      'code': _code.text.trim().toUpperCase(),
      'title': _title.text.trim(),
      'discount_type': _type,
      'discount_value': discount,
      'minimum_order': minimum,
      'is_active': _active,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.promo == null ? 'Create Promo' : 'Edit Promo',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Promo Code'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Promo Title'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
                TextFormField(
                  controller: _value,
                  decoration: InputDecoration(
                    labelText: _type == 'percentage' ? 'Discount Percentage' : 'Discount Amount',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    if (_type == 'percentage' && n > 100) return 'Percentage cannot exceed 100';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _minimum,
                  decoration: const InputDecoration(labelText: 'Minimum Order'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n < 0 ? 'Enter a valid amount' : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Promo Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
