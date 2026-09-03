// Owner Promo Management Screen
// Scoped to the currently selected restaurant. Admin promo management is untouched.

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
  final SupabaseClient _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _promos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load promos: $e')),
      );
    }
  }

  Future<void> _openForm([Map<String, dynamic>? promo]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PromoFormDialog(promo: promo),
    );
    if (result == null) return;

    try {
      final data = {
        'restaurant_id': widget.restaurantId,
        'code': result['code'],
        'title': result['title'],
        'description': result['description'],
        'discount_type': result['discount_type'],
        'discount_value': result['discount_value'],
        'minimum_order': result['minimum_order'],
        'maximum_discount': result['maximum_discount'],
        'usage_limit': result['usage_limit'],
        'is_active': result['is_active'],
      };

      if (promo == null) {
        await _db.from('promo_codes').insert(data);
      } else {
        await _db
            .from('promo_codes')
            .update(data)
            .eq('id', promo['id'])
            .eq('restaurant_id', widget.restaurantId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(promo == null ? 'Promo created.' : 'Promo updated.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save promo: $e')),
      );
    }
  }

  Future<void> _toggle(Map<String, dynamic> promo, bool value) async {
    try {
      await _db
          .from('promo_codes')
          .update({'is_active': value})
          .eq('id', promo['id'])
          .eq('restaurant_id', widget.restaurantId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update promo: $e')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Promo'),
        content: Text('Delete promo code ${promo['code']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _db
          .from('promo_codes')
          .delete()
          .eq('id', promo['id'])
          .eq('restaurant_id', widget.restaurantId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete promo: $e')),
      );
    }
  }

  String _discountText(Map<String, dynamic> promo) {
    final type = promo['discount_type']?.toString();
    final value = promo['discount_value'];
    if (type == 'percentage') return '${value ?? 0}% OFF';
    return '₱${value ?? 0} OFF';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.restaurantName} • Promos & Discounts'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Promo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        const Text('No promos yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Create a promo or discount exclusively for this restaurant.'),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _openForm(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Promo'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _promos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final promo = _promos[index];
                      final active = promo['is_active'] == true;
                      final used = (promo['usage_count'] as num?)?.toInt() ?? 0;
                      final limit = (promo['usage_limit'] as num?)?.toInt();
                      final type = promo['discount_type']?.toString();
                      final minimum = (promo['minimum_order'] as num?)?.toDouble();
                      final maximum = (promo['maximum_discount'] as num?)?.toDouble();

                      return Card(
                        elevation: 1.5,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            promo['code']?.toString() ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          promo['title']?.toString() ?? 'Untitled Promo',
                                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: active,
                                    onChanged: (value) => _toggle(promo, value),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    _discountText(promo),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Chip(
                                    label: Text(active ? 'Active' : 'Inactive'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              if ((promo['description']?.toString() ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  promo['description'].toString(),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (minimum != null && minimum > 0)
                                    Chip(label: Text('Min. order ₱${minimum.toStringAsFixed(0)}')),
                                  if (type == 'percentage' && maximum != null && maximum > 0)
                                    Chip(label: Text('Max. discount ₱${maximum.toStringAsFixed(0)}')),
                                  Chip(label: Text(limit == null ? '$used uses' : '$used / $limit uses')),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _openForm(promo),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(promo),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                ],
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _value;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _usageLimit;
  late String _type;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final p = widget.promo;
    _code = TextEditingController(text: p?['code']?.toString() ?? '');
    _title = TextEditingController(text: p?['title']?.toString() ?? '');
    _description = TextEditingController(text: p?['description']?.toString() ?? '');
    _value = TextEditingController(text: p?['discount_value']?.toString() ?? '');
    _minimum = TextEditingController(text: p?['minimum_order']?.toString() ?? '');
    _maximum = TextEditingController(text: p?['maximum_discount']?.toString() ?? '');
    _usageLimit = TextEditingController(text: p?['usage_limit']?.toString() ?? '');
    _type = p?['discount_type']?.toString() == 'fixed' ? 'fixed' : 'percentage';
    _active = p?['is_active'] != false;
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _description.dispose();
    _value.dispose();
    _minimum.dispose();
    _maximum.dispose();
    _usageLimit.dispose();
    super.dispose();
  }

  double? _number(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  int? _integer(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = _number(_value);
    final minimum = _number(_minimum);
    final maximum = _number(_maximum);
    final limit = _integer(_usageLimit);

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid discount value.')),
      );
      return;
    }
    if (minimum != null && minimum < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum order cannot be negative.')),
      );
      return;
    }
    if (_type == 'percentage' && value > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percentage discount cannot exceed 100%.')),
      );
      return;
    }
    if (maximum != null && maximum < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum discount cannot be negative.')),
      );
      return;
    }
    if (limit != null && limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usage limit must be greater than zero.')),
      );
      return;
    }

    Navigator.pop(context, {
      'code': _code.text.trim().toUpperCase(),
      'title': _title.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'discount_type': _type,
      'discount_value': value,
      'minimum_order': minimum,
      'maximum_discount': _type == 'percentage' ? maximum : null,
      'usage_limit': limit,
      'is_active': _active,
    });
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboard,
    int lines = 1,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: TextFormField(
          controller: c,
          maxLines: lines,
          keyboardType: keyboard,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.promo == null ? 'Create Promo' : 'Edit Promo',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  _code,
                  'Promo Code',
                  Icons.confirmation_number_outlined,
                  required: true,
                ),
                _field(
                  _title,
                  'Promo Name',
                  Icons.title_rounded,
                  required: true,
                ),
                _field(
                  _description,
                  'Promo Details',
                  Icons.description_outlined,
                  lines: 3,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Discount Type',
                    prefixIcon: Icon(Icons.discount_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text('Fixed Amount'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'percentage'),
                ),
                const SizedBox(height: 13),
                _field(
                  _value,
                  _type == 'percentage' ? 'Discount Percentage' : 'Discount Amount',
                  Icons.savings_outlined,
                  required: true,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  _minimum,
                  'Minimum Order',
                  Icons.shopping_bag_outlined,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (_type == 'percentage')
                  _field(
                    _maximum,
                    'Maximum Discount (optional)',
                    Icons.money_off_csred_outlined,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                _field(
                  _usageLimit,
                  'Usage Limit (optional)',
                  Icons.people_outline_rounded,
                  keyboard: TextInputType.number,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Promo Active',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Customers can use this promo while active.',
                  ),
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
          onPressed: () => Navigator.pop(context),
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
