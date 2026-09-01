import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class AdminSubscriptionManagementScreen extends StatefulWidget {
  const AdminSubscriptionManagementScreen({super.key});

  @override
  State<AdminSubscriptionManagementScreen> createState() => _AdminSubscriptionManagementScreenState();
}

class _AdminSubscriptionManagementScreenState extends State<AdminSubscriptionManagementScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'all';
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchController.dispose(); _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _supabase.from('restaurant_subscriptions').select('*, restaurants(id,name), subscription_plans(id,name,monthly_price,annual_price)').order('created_at', ascending: false),
        _supabase.from('subscription_plans').select().order('sort_order'),
      ]);
      if (!mounted) return;
      setState(() {
        _subscriptions = List<Map<String, dynamic>>.from(results[0] as List);
        _plans = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered => _subscriptions.where((s) {
    final restaurant = s['restaurants'] is Map ? Map<String, dynamic>.from(s['restaurants']) : <String, dynamic>{};
    final plan = s['subscription_plans'] is Map ? Map<String, dynamic>.from(s['subscription_plans']) : <String, dynamic>{};
    final q = _search.toLowerCase();
    final name = restaurant['name']?.toString().toLowerCase() ?? '';
    final planName = plan['name']?.toString().toLowerCase() ?? '';
    final status = s['status']?.toString() ?? 'active';
    return (q.isEmpty || name.contains(q) || planName.contains(q) || s['id'].toString().toLowerCase().contains(q)) && (_filter == 'all' || status == _filter);
  }).toList();

  int _count(String status) => _subscriptions.where((s) => s['status'] == status).length;
  double get _monthlyRecurring => _subscriptions.where((s) => s['status'] == 'active').fold(0, (sum, s) {
    final plan = s['subscription_plans'];
    if (plan is Map) return sum + (double.tryParse(plan['monthly_price']?.toString() ?? '') ?? 0);
    return sum;
  });

  Future<void> _updateStatus(Map<String, dynamic> subscription, String status) async {
    try {
      final values = <String, dynamic>{'status': status};
      if (status == 'cancelled') values['cancelled_at'] = DateTime.now().toUtc().toIso8601String();
      if (status == 'suspended') values['suspended_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('restaurant_subscriptions').update(values).eq('id', subscription['id']);
      await _load();
      if (mounted) _message('Subscription marked as ${_statusLabel(status)}.');
    } catch (e) { if (mounted) _message('Unable to update subscription: $e'); }
  }

  void _showDetails(Map<String, dynamic> s) {
    final restaurant = s['restaurants'] is Map ? Map<String, dynamic>.from(s['restaurants']) : <String, dynamic>{};
    final plan = s['subscription_plans'] is Map ? Map<String, dynamic>.from(s['subscription_plans']) : <String, dynamic>{};
    showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.workspace_premium_rounded, size: 30), const SizedBox(width: 10), Expanded(child: Text(restaurant['name']?.toString() ?? 'Restaurant Subscription', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))), _StatusBadge(s['status']?.toString() ?? 'active')]),
      const SizedBox(height: 16),
      _Detail('Plan', plan['name']?.toString() ?? 'Unknown'),
      _Detail('Monthly Price', '₱${_money(plan['monthly_price'])}'),
      _Detail('Billing', _cycleLabel(s['billing_cycle']?.toString() ?? 'monthly')),
      _Detail('Status', _statusLabel(s['status']?.toString() ?? 'active')),
      _Detail('Started', _date(s['started_at'])),
      _Detail('Current Period', '${_dateOnly(s['current_period_start'])} – ${_dateOnly(s['current_period_end'])}'),
      _Detail('Next Billing', _date(s['next_billing_at'])),
      if ((s['grace_period_end']?.toString() ?? '').isNotEmpty) _Detail('Grace Period', _date(s['grace_period_end'])),
      if ((s['notes']?.toString() ?? '').isNotEmpty) _Detail('Notes', s['notes'].toString()),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (s['status'] != 'active') _ActionButton('Activate', Icons.check_circle_rounded, Colors.green, () { Navigator.pop(sheetContext); _updateStatus(s, 'active'); }),
        if (s['status'] == 'active') _ActionButton('Past Due', Icons.warning_amber_rounded, Colors.orange, () { Navigator.pop(sheetContext); _updateStatus(s, 'past_due'); }),
        if (s['status'] == 'past_due') _ActionButton('Grace Period', Icons.timelapse_rounded, Colors.deepOrange, () { Navigator.pop(sheetContext); _updateStatus(s, 'grace_period'); }),
        if (s['status'] != 'suspended' && s['status'] != 'cancelled') _ActionButton('Suspend', Icons.pause_circle_rounded, Colors.red, () { Navigator.pop(sheetContext); _updateStatus(s, 'suspended'); }),
        if (s['status'] != 'cancelled') _ActionButton('Cancel', Icons.cancel_rounded, Colors.grey, () { Navigator.pop(sheetContext); _updateStatus(s, 'cancelled'); }),
      ]),
    ]))));
  }

  Future<void> _showPlanDialog([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final price = TextEditingController(text: existing?['monthly_price']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final features = TextEditingController(text: existing?['features'] is List ? (existing!['features'] as List).join(', ') : '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(existing == null ? 'Add Subscription Plan' : 'Edit Subscription Plan'), content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Plan name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null), TextFormField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly price (PHP)'), validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Enter a valid price' : null), TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description')), TextFormField(controller: features, maxLines: 2, decoration: const InputDecoration(labelText: 'Features (comma separated)'))]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), ElevatedButton(onPressed: () async { if (!formKey.currentState!.validate()) return; try { final featureList = features.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(); final values = {'name': name.text.trim(), 'monthly_price': double.parse(price.text.trim()), 'description': description.text.trim(), 'features': featureList}; if (existing == null) await _supabase.from('subscription_plans').insert(values); else await _supabase.from('subscription_plans').update(values).eq('id', existing['id']); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (e) { if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Unable to save plan: $e'))); } }, child: const Text('Save'))]));
    name.dispose(); price.dispose(); description.dispose(); features.dispose();
    if (saved == true) await _load();
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    try { await _supabase.from('subscription_plans').delete().eq('id', plan['id']); await _load(); if (mounted) _message('Subscription plan deleted.'); }
    catch (e) { if (mounted) _message('Unable to delete plan: $e'); }
  }

  String _statusLabel(String v) => switch (v) { 'trial' => 'Trial', 'active' => 'Active', 'past_due' => 'Past Due', 'grace_period' => 'Grace Period', 'suspended' => 'Suspended', 'cancelled' => 'Cancelled', 'expired' => 'Expired', _ => 'Unknown' };
  String _cycleLabel(String v) => v == 'annual' ? 'Annual' : 'Monthly';
  String _money(dynamic v) => (double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2);
  String _date(dynamic v) { final d = DateTime.tryParse(v?.toString() ?? ''); return d == null ? 'Not set' : '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; }
  String _dateOnly(dynamic v) { final d = DateTime.tryParse(v?.toString() ?? ''); return d == null ? 'Not set' : '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}'; }
  void _message(String text) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFF6F8F7), appBar: AppBar(title: const Text('SaaS Subscriptions', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh')], bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Subscriptions'), Tab(text: 'Plans')])), body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _ErrorView(message: _error!, onRetry: _load) : TabBarView(controller: _tabs, children: [_subscriptionTab(), _plansTab()]));

  Widget _subscriptionTab() => RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16,16,16,32), children: [
    _Summary(active: _count('active'), pastDue: _count('past_due'), suspended: _count('suspended'), cancelled: _count('cancelled'), mrr: _monthlyRecurring),
    const SizedBox(height: 14),
    TextField(controller: _searchController, onChanged: (v) => setState(() => _search = v.trim()), decoration: InputDecoration(hintText: 'Search restaurant or plan...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _search.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _search = ''); }, icon: const Icon(Icons.clear_rounded)))),
    const SizedBox(height: 12),
    SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [for (final item in const [('All','all'),('Active','active'),('Past Due','past_due'),('Grace','grace_period'),('Suspended','suspended'),('Cancelled','cancelled')]) Padding(padding: const EdgeInsets.only(right:8), child: FilterChip(label: Text(item.$1), selected: _filter == item.$2, onSelected: (_) => setState(() => _filter = item.$2)))])),
    const SizedBox(height: 14),
    Text('${_filtered.length} subscription${_filtered.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700, color: HalalFoodTheme.textSecondary)), const SizedBox(height: 8),
    if (_filtered.isEmpty) const Padding(padding: EdgeInsets.only(top:70), child: Center(child: Text('No restaurant subscriptions found.'))) else ..._filtered.map(_subscriptionCard),
  ]));

  Widget _subscriptionCard(Map<String,dynamic> s) { final restaurant=s['restaurants'] is Map ? Map<String,dynamic>.from(s['restaurants']) : <String,dynamic>{}; final plan=s['subscription_plans'] is Map ? Map<String,dynamic>.from(s['subscription_plans']) : <String,dynamic>{}; return Card(margin: const EdgeInsets.only(bottom:10), child: InkWell(onTap:()=>_showDetails(s), borderRadius:BorderRadius.circular(16), child:Padding(padding:const EdgeInsets.all(14), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:HalalFoodTheme.primaryGreen.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.storefront_rounded,color:HalalFoodTheme.primaryGreen)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(restaurant['name']?.toString() ?? 'Unknown Restaurant',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text('${plan['name']?.toString() ?? 'Unknown Plan'} • ₱${_money(plan['monthly_price'])}/month',style:const TextStyle(fontSize:11,color:HalalFoodTheme.textSecondary))])),_StatusBadge(s['status']?.toString() ?? 'active')]),const SizedBox(height:10),Row(children:[Expanded(child:Text('Next billing: ${_dateOnly(s['next_billing_at'])}',style:const TextStyle(fontSize:11))),const Icon(Icons.chevron_right_rounded,size:20)])])))); }

  Widget _plansTab() => RefreshIndicator(onRefresh:_load, child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,16,16,32),children:[Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Subscription Plans',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),SizedBox(height:3),Text('Control what restaurants receive with each SaaS tier.',style:TextStyle(fontSize:12,color:HalalFoodTheme.textSecondary))])),ElevatedButton.icon(onPressed:()=>_showPlanDialog(),icon:const Icon(Icons.add_rounded),label:const Text('Add Plan'))]),const SizedBox(height:14),if(_plans.isEmpty)const Padding(padding:EdgeInsets.only(top:70),child:Center(child:Text('No subscription plans found.')))else..._plans.map((p)=>Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(p['name']?.toString()??'Plan',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),Text('₱${_money(p['monthly_price'])}/mo',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:HalalFoodTheme.primaryGreen))]),if((p['description']?.toString()??'').isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Text(p['description'].toString(),style:const TextStyle(fontSize:12,color:HalalFoodTheme.textSecondary))),if(p['features'] is List)Padding(padding:const EdgeInsets.only(top:10),child:Wrap(spacing:6,runSpacing:6,children:(p['features'] as List).map((f)=>_FeatureChip(f.toString())).toList())),const SizedBox(height:10),Row(mainAxisAlignment:MainAxisAlignment.end,children:[IconButton(tooltip:'Edit plan',onPressed:()=>_showPlanDialog(p),icon:const Icon(Icons.edit_rounded)),IconButton(tooltip:'Delete plan',onPressed:()=>_deletePlan(p),icon:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent))])]))))]));
}

class _Summary extends StatelessWidget { final int active,pastDue,suspended,cancelled; final double mrr; const _Summary({required this.active,required this.pastDue,required this.suspended,required this.cancelled,required this.mrr}); @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Wrap(alignment:WrapAlignment.spaceAround,runSpacing:12,children:[_Metric('Active','$active',Icons.check_circle_rounded,Colors.green),_Metric('Past Due','$pastDue',Icons.warning_amber_rounded,Colors.orange),_Metric('Suspended','$suspended',Icons.pause_circle_rounded,Colors.red),_Metric('MRR','₱${mrr.toStringAsFixed(0)}',Icons.payments_rounded,HalalFoodTheme.primaryGreen),_Metric('Cancelled','$cancelled',Icons.cancel_rounded,Colors.grey)]))); }
class _Metric extends StatelessWidget { final String label,value; final IconData icon; final Color color; const _Metric(this.label,this.value,this.icon,this.color); @override Widget build(BuildContext context)=>SizedBox(width:100,child:Column(children:[Icon(icon,size:19,color:color),const SizedBox(height:4),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),Text(label,style:const TextStyle(fontSize:9,color:HalalFoodTheme.textSecondary))])); }
class _StatusBadge extends StatelessWidget { final String status; const _StatusBadge(this.status); @override Widget build(BuildContext context){final c=switch(status){ 'active'=>Colors.green,'trial'=>Colors.blue,'past_due'=>Colors.orange,'grace_period'=>Colors.deepOrange,'suspended'=>Colors.red,'cancelled'=>Colors.grey,'expired'=>Colors.grey,_=>Colors.blueGrey}; final label=switch(status){'past_due'=>'Past Due','grace_period'=>'Grace','active'=>'Active','cancelled'=>'Cancelled','suspended'=>'Suspended','expired'=>'Expired','trial'=>'Trial',_=>status}; return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:c.withValues(alpha:.10),borderRadius:BorderRadius.circular(8)),child:Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:c)));} }
class _FeatureChip extends StatelessWidget { final String text; const _FeatureChip(this.text); @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:HalalFoodTheme.primaryGreen.withValues(alpha:.08),borderRadius:BorderRadius.circular(8)),child:Text(text,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w600))); }
class _ActionButton extends StatelessWidget { final String label; final IconData icon; final Color color; final VoidCallback onTap; const _ActionButton(this.label,this.icon,this.color,this.onTap); @override Widget build(BuildContext context)=>OutlinedButton.icon(onPressed:onTap,icon:Icon(icon,size:17,color:color),label:Text(label)); }
class _Detail extends StatelessWidget { final String label,value; const _Detail(this.label,this.value); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:105,child:Text(label,style:const TextStyle(fontSize:12,color:HalalFoodTheme.textSecondary))),Expanded(child:Text(value,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700))) ])); }
class _ErrorView extends StatelessWidget { final String message; final VoidCallback onRetry; const _ErrorView({required this.message,required this.onRetry}); @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline_rounded,size:54,color:Colors.redAccent),const SizedBox(height:12),const Text('Unable to load subscriptions',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(message,textAlign:TextAlign.center,maxLines:5,overflow:TextOverflow.ellipsis),const SizedBox(height:16),ElevatedButton(onPressed:onRetry,child:const Text('Try Again'))]))); }
