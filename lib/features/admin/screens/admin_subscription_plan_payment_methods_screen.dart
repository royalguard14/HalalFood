import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSubscriptionPlanPaymentMethodsScreen extends StatefulWidget {
  const AdminSubscriptionPlanPaymentMethodsScreen({super.key});
  @override State<AdminSubscriptionPlanPaymentMethodsScreen> createState() => _AdminSubscriptionPlanPaymentMethodsScreenState();
}

class _AdminSubscriptionPlanPaymentMethodsScreenState extends State<AdminSubscriptionPlanPaymentMethodsScreen> {
  final db = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> methods = [];
  final Map<String, Set<String>> selected = {};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait([
        db.from('subscription_plans').select('id,name,monthly_price,annual_price').order('sort_order'),
        db.from('subscription_payment_methods').select('id,name,type,is_active').order('sort_order').order('created_at'),
      ]);
      final p = List<Map<String, dynamic>>.from(results[0] as List);
      final m = List<Map<String, dynamic>>.from(results[1] as List);
      final ids = p.map((x) => x['id'].toString()).toList();
      if (ids.isNotEmpty) {
        final links = await db.from('subscription_plan_payment_methods').select('plan_id,payment_method_id').inFilter('plan_id', ids);
        for (final row in List<Map<String, dynamic>>.from(links as List)) {
          selected.putIfAbsent(row['plan_id'].toString(), () => <String>{}).add(row['payment_method_id'].toString());
        }
      }
      if (mounted) setState(() { plans = p; methods = m; loading = false; });
    } catch (e) { if (mounted) { setState(() => loading = false); _message('Unable to load plan payment settings: $e'); } }
  }

  Future<void> _save(String planId) async {
    try {
      await db.from('subscription_plan_payment_methods').delete().eq('plan_id', planId);
      final ids = selected[planId] ?? <String>{};
      if (ids.isNotEmpty) {
        await db.from('subscription_plan_payment_methods').insert(ids.map((id) => {'plan_id': planId, 'payment_method_id': id}).toList());
      }
      if (mounted) _message('Payment methods saved for this plan.');
    } catch (e) { if (mounted) _message('Unable to save plan payment methods: $e'); }
  }

  void _message(String s) { if (!mounted) return; ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(s))); }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Payment Methods per Plan', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]), body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [const Text('Assign Payment Methods to Each SaaS Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('When an owner selects a plan, only the payment methods enabled here will be offered.'), const SizedBox(height: 16), if (methods.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Add payment methods first.'))) else ...plans.map(_planCard)]));

  Widget _planCard(Map<String, dynamic> plan) {
    final id = plan['id'].toString();
    final set = selected.putIfAbsent(id, () => <String>{});
    return Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(plan['name']?.toString() ?? 'Plan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Text('₱${plan['monthly_price'] ?? 0} / month • ₱${plan['annual_price'] ?? 0} / year'),
      const SizedBox(height: 10),
      ...methods.map((m) => CheckboxListTile(contentPadding: EdgeInsets.zero, value: set.contains(m['id'].toString()), onChanged: m['is_active'] == true ? (v) => setState(() { if (v == true) { set.add(m['id'].toString()); } else { set.remove(m['id'].toString()); } }) : null, title: Text(m['name']?.toString() ?? 'Payment Method'), subtitle: Text(m['is_active'] == true ? (m['type']?.toString() ?? 'other') : 'Disabled globally'), controlAffinity: ListTileControlAffinity.leading)),
      const SizedBox(height: 6), Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _save(id), icon: const Icon(Icons.save_rounded), label: const Text('Save'))),
    ])));
  }
}
