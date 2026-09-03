import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerPromoManagementScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerPromoManagementScreen({super.key, required this.restaurantId, required this.restaurantName});

  @override
  State<OwnerPromoManagementScreen> createState() => _OwnerPromoManagementScreenState();
}

class _OwnerPromoManagementScreenState extends State<OwnerPromoManagementScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _promos = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _db.from('promo_codes').select().eq('restaurant_id', widget.restaurantId).order('created_at', ascending: false);
      if (mounted) setState(() { _promos = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); _msg('Unable to load promos: $e'); } }
  }

  Future<void> _save({Map<String, dynamic>? promo}) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _PromoFormDialog(promo: promo));
    if (result == null) return;
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
    try {
      if (promo == null) {
        await _db.from('promo_codes').insert(data);
      } else {
        await _db.from('promo_codes').update(data).eq('id', promo['id']).eq('restaurant_id', widget.restaurantId);
      }
      await _load();
      if (mounted) _msg(promo == null ? 'Promo created successfully.' : 'Promo updated successfully.');
    } catch (e) { _msg('Unable to save promo: $e'); }
  }

  Future<void> _toggle(Map<String, dynamic> promo) async {
    try {
      await _db.from('promo_codes').update({'is_active': promo['is_active'] != true}).eq('id', promo['id']).eq('restaurant_id', widget.restaurantId);
      await _load();
    } catch (e) { _msg('Unable to update promo: $e'); }
  }

  Future<void> _delete(Map<String, dynamic> promo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promo', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Delete ${promo['code']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('promo_codes').delete().eq('id', promo['id']).eq('restaurant_id', widget.restaurantId);
      await _load();
      if (mounted) _msg('Promo deleted.');
    } catch (e) { _msg('Unable to delete promo: $e'); }
  }

  void _msg(String message) {
    if (mounted) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return '₱${n.toStringAsFixed(2)}';
  }

  String _discount(Map<String, dynamic> p) {
    final type = p['discount_type']?.toString() ?? 'percentage';
    final v = p['discount_value'];
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return type == 'percentage' ? '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(2)}% OFF' : '${_money(n)} OFF';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName.isEmpty ? 'Promos & Discounts' : widget.restaurantName, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _loading ? null : () => _save(), icon: const Icon(Icons.add_rounded), label: const Text('Create Promo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? RefreshIndicator(onRefresh: _load, child: ListView(children: const [SizedBox(height: 180), Icon(Icons.local_offer_outlined, size: 64), SizedBox(height: 12), Center(child: Text('No promos yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Center(child: Text('Create a promo to attract more customers.'))]))
              : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: _promos.length, itemBuilder: (_, i) => _promoCard(_promos[i]))),
    );
  }

  Widget _promoCard(Map<String, dynamic> promo) {
    final active = promo['is_active'] == true;
    final limit = promo['usage_limit'];
    final used = promo['usage_count'] ?? 0;
    final description = promo['description']?.toString().trim() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _save(promo: promo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.local_offer_rounded, color: Colors.orange, size: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(promo['code']?.toString() ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .7)),
                const SizedBox(height: 3),
                Text(promo['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
              Switch(value: active, onChanged: (_) => _toggle(promo)),
            ]),
            const SizedBox(height: 14),
            Text(_discount(promo), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)), child: Text(description, style: const TextStyle(height: 1.35))),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _chip(active ? 'Active' : 'Inactive', active ? Colors.green : Colors.grey),
              _chip('Min. ${_money(promo['minimum_order'])}', Colors.blue),
              if (promo['discount_type'] == 'percentage' && promo['maximum_discount'] != null) _chip('Max. ${_money(promo['maximum_discount'])}', Colors.deepOrange),
              _chip(limit == null ? '$used uses' : '$used / $limit uses', Colors.deepPurple),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _save(promo: promo), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit'))),
              const SizedBox(width: 8),
              IconButton(onPressed: () => _delete(promo), icon: const Icon(Icons.delete_outline_rounded), color: Colors.redAccent, tooltip: 'Delete promo'),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}

class _PromoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? promo;
  const _PromoFormDialog({this.promo});
  @override
  State<_PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<_PromoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code, _title, _description, _value, _minimum, _maximum, _usageLimit;
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
    _minimum = TextEditingController(text: p?['minimum_order']?.toString() ?? '0');
    _maximum = TextEditingController(text: p?['maximum_discount']?.toString() ?? '');
    _usageLimit = TextEditingController(text: p?['usage_limit']?.toString() ?? '');
    _type = p?['discount_type']?.toString() ?? 'percentage';
    _active = p?['is_active'] != false;
  }

  @override
  void dispose() { for (final c in [_code, _title, _description, _value, _minimum, _maximum, _usageLimit]) { c.dispose(); } super.dispose(); }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = double.tryParse(_value.text.trim());
    final minimum = double.tryParse(_minimum.text.trim()) ?? 0;
    final maximum = double.tryParse(_maximum.text.trim());
    final limitText = _usageLimit.text.trim();
    final limit = limitText.isEmpty ? null : int.tryParse(limitText);
    if (value == null || value <= 0 || (limitText.isNotEmpty && (limit == null || limit <= 0))) return;
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

  Widget _field(TextEditingController c, String label, IconData icon, {bool required = false, TextInputType? keyboard, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 13), child: TextFormField(controller: c, maxLines: lines, keyboardType: keyboard, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)), validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.promo == null ? 'Create Promo' : 'Edit Promo', style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(width: 430, child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(_code, 'Promo Code', Icons.confirmation_number_outlined, required: true),
        _field(_title, 'Promo Name', Icons.title_rounded, required: true),
        _field(_description, 'Promo Details', Icons.description_outlined, lines: 3),
        DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Discount Type', prefixIcon: Icon(Icons.discount_rounded)), items: const [DropdownMenuItem(value: 'percentage', child: Text('Percentage')), DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount'))], onChanged: (v) => setState(() => _type = v ?? 'percentage')),
        const SizedBox(height: 13),
        _field(_value, _type == 'percentage' ? 'Discount Percentage' : 'Discount Amount', Icons.savings_outlined, required: true, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        _field(_minimum, 'Minimum Order', Icons.shopping_bag_outlined, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        if (_type == 'percentage') _field(_maximum, 'Maximum Discount (optional)', Icons.money_off_csred_outlined, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        _field(_usageLimit, 'Usage Limit (optional)', Icons.people_outline_rounded, keyboard: TextInputType.number),
        SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Promo Active', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Customers can use this promo while active.'), value: _active, onChanged: (v) => setState(() => _active = v)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
