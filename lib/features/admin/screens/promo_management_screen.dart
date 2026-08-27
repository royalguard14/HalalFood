import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class PromoManagementScreen extends StatefulWidget {
  const PromoManagementScreen({super.key});

  @override
  State<PromoManagementScreen> createState() => _PromoManagementScreenState();
}

class _PromoManagementScreenState extends State<PromoManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  List<Map<String, dynamic>> _promos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _promos = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered => _promos.where((promo) {
    final active = promo['is_active'] == true;
    final expired = _isExpired(promo);
    return switch (_filter) {
      'active' => active && !expired,
      'inactive' => !active,
      'expired' => expired,
      _ => true,
    };
  }).toList();

  bool _isExpired(Map<String, dynamic> promo) {
    final value = promo['ends_at']?.toString();
    if (value == null || value.isEmpty) return false;
    final date = DateTime.tryParse(value);
    return date != null && date.isBefore(DateTime.now());
  }

  Future<void> _openForm([Map<String, dynamic>? promo]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _PromoFormScreen(promo: promo)),
    );
    if (saved == true) {
      await _load();
      if (mounted) _message(promo == null ? 'Promo created successfully.' : 'Promo updated successfully.');
    }
  }

  Future<void> _toggle(Map<String, dynamic> promo) async {
    final next = promo['is_active'] != true;
    try {
      await _supabase.from('promo_codes').update({'is_active': next}).eq('id', promo['id']);
      await _load();
      if (mounted) _message(next ? 'Promo activated.' : 'Promo deactivated.');
    } catch (e) {
      if (mounted) _message('Unable to update promo: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Promo', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Delete promo code ${promo['code']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.from('promo_codes').delete().eq('id', promo['id']);
      await _load();
      if (mounted) _message('Promo deleted.');
    } catch (e) {
      if (mounted) _message('Unable to delete promo: $e');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final promos = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promos & Discounts', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Promo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent), const SizedBox(height: 12), const Text('Unable to load promos', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Try Again'))])))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _summary(),
                      const SizedBox(height: 16),
                      SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
                        for (final item in const [('All', 'all'), ('Active', 'active'), ('Inactive', 'inactive'), ('Expired', 'expired')])
                          Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(item.$1), selected: _filter == item.$2, onSelected: (_) => setState(() => _filter = item.$2))),
                      ])),
                      const SizedBox(height: 16),
                      if (promos.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: Column(children: [Icon(Icons.local_offer_outlined, size: 64), SizedBox(height: 12), Text('No promos found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Create your first promo code to start offering discounts.')])) )
                      else
                        ...promos.map(_promoCard),
                    ],
                  ),
                ),
    );
  }

  Widget _summary() {
    final active = _promos.where((p) => p['is_active'] == true && !_isExpired(p)).length;
    final expired = _promos.where(_isExpired).length;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(child: _metric('Total', _promos.length, Icons.local_offer_rounded, HalalFoodTheme.primaryGreen)),
      Expanded(child: _metric('Active', active, Icons.check_circle_rounded, Colors.green)),
      Expanded(child: _metric('Expired', expired, Icons.timer_off_rounded, Colors.orange)),
    ])));
  }

  Widget _metric(String label, int value, IconData icon, Color color) => Column(children: [Icon(icon, color: color), const SizedBox(height: 5), Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary))]);

  Widget _promoCard(Map<String, dynamic> promo) {
    final active = promo['is_active'] == true;
    final expired = _isExpired(promo);
    final type = promo['discount_type']?.toString() ?? 'percentage';
    final value = promo['discount_value'];
    final discount = type == 'percentage' ? '${value is num ? value.toStringAsFixed(value % 1 == 0 ? 0 : 2) : value}% OFF' : '${_money(value)} OFF';
    final usageLimit = promo['usage_limit'];
    final usage = promo['usage_count'] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openForm(promo),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.local_offer_rounded, color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(promo['code']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: .6)), Text(promo['title']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary))])),
              Switch(value: active, onChanged: expired ? null : (_) => _toggle(promo)),
            ]),
            const SizedBox(height: 14),
            Text(discount, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: HalalFoodTheme.primaryGreen)),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _chip(active ? 'Active' : 'Inactive', active ? Colors.green : Colors.grey),
              if (expired) _chip('Expired', Colors.red),
              _chip('Min. ${_money(promo['minimum_order'])}', Colors.blue),
              _chip(usageLimit == null ? '$usage uses' : '$usage / $usageLimit uses', Colors.deepPurple),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _openForm(promo), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit'))),
              const SizedBox(width: 8),
              IconButton(onPressed: () => _delete(promo), icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete promo', color: Colors.redAccent),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}

class _PromoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? promo;
  const _PromoFormScreen({this.promo});
  @override
  State<_PromoFormScreen> createState() => _PromoFormScreenState();
}

class _PromoFormScreenState extends State<_PromoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _value;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _usageLimit;
  String _type = 'percentage';
  bool _active = true;
  bool _saving = false;
  bool get _editing => widget.promo != null;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final data = {
      'code': _code.text.trim().toUpperCase(),
      'title': _title.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'discount_type': _type,
      'discount_value': double.parse(_value.text.trim()),
      'minimum_order': double.tryParse(_minimum.text.trim()) ?? 0,
      'maximum_discount': _type == 'percentage' && _maximum.text.trim().isNotEmpty ? double.tryParse(_maximum.text.trim()) : null,
      'usage_limit': _usageLimit.text.trim().isEmpty ? null : int.tryParse(_usageLimit.text.trim()),
      'is_active': _active,
    };
    try {
      if (_editing) { await _supabase.from('promo_codes').update(data).eq('id', widget.promo!['id']); }
      else { await _supabase.from('promo_codes').insert(data); }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save promo: $e'))); }
    }
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool required = false, TextInputType? type, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 14), child: TextFormField(controller: controller, maxLines: lines, enabled: !_saving, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)), validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required.' : null : null));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_editing ? 'Edit Promo' : 'Create Promo', style: const TextStyle(fontWeight: FontWeight.w800))),
    body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
      _field(_code, 'Promo Code', Icons.confirmation_number_outlined, required: true),
      _field(_title, 'Promo Title', Icons.title_rounded, required: true),
      _field(_description, 'Description', Icons.description_outlined, lines: 3),
      DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Discount Type', prefixIcon: Icon(Icons.discount_rounded)), items: const [DropdownMenuItem(value: 'percentage', child: Text('Percentage')), DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount'))], onChanged: _saving ? null : (v) => setState(() => _type = v ?? 'percentage')),
      const SizedBox(height: 14),
      _field(_value, _type == 'percentage' ? 'Discount Percentage' : 'Discount Amount', Icons.savings_outlined, required: true, type: const TextInputType.numberWithOptions(decimal: true)),
      _field(_minimum, 'Minimum Order', Icons.shopping_bag_outlined, type: const TextInputType.numberWithOptions(decimal: true)),
      if (_type == 'percentage') _field(_maximum, 'Maximum Discount (optional)', Icons.money_off_csred_outlined, type: const TextInputType.numberWithOptions(decimal: true)),
      _field(_usageLimit, 'Usage Limit (optional)', Icons.people_outline_rounded, type: TextInputType.number),
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Promo Active', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Customers can use this promo while it is active.'), value: _active, onChanged: _saving ? null : (v) => setState(() => _active = v)),
      const SizedBox(height: 16),
      SizedBox(height: 52, child: ElevatedButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_editing ? Icons.save_rounded : Icons.add_rounded), label: Text(_saving ? 'Saving...' : _editing ? 'Save Changes' : 'Create Promo'))),
    ]))),
  );
}
