import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class AdminPaymentManagementScreen extends StatefulWidget {
  const AdminPaymentManagementScreen({super.key});

  @override
  State<AdminPaymentManagementScreen> createState() => _AdminPaymentManagementScreenState();
}

class _AdminPaymentManagementScreenState extends State<AdminPaymentManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'all';
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await _supabase.from('payments').select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _payments = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered => _payments.where((p) {
    final q = _search.toLowerCase();
    final order = p['order_id']?.toString().toLowerCase() ?? '';
    final customer = p['customer_id']?.toString().toLowerCase() ?? '';
    final reference = p['transaction_reference']?.toString().toLowerCase() ?? '';
    final status = p['status']?.toString() ?? 'pending';
    return (q.isEmpty || order.contains(q) || customer.contains(q) || reference.contains(q)) &&
        (_filter == 'all' || status == _filter);
  }).toList();

  int _count(String status) => _payments.where((p) => p['status'] == status).length;

  double _total(String status) => _payments
      .where((p) => status == 'all' || p['status'] == status)
      .fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '') ?? 0));

  Future<void> _updateStatus(Map<String, dynamic> payment, String status) async {
    try {
      await _supabase.from('payments').update({'status': status}).eq('id', payment['id']);
      await _load();
      if (mounted) _message('Payment marked as ${_statusLabel(status)}.');
    } catch (e) {
      if (mounted) _message('Unable to update payment: $e');
    }
  }

  void _showDetails(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.payments_rounded, size: 28),
              const SizedBox(width: 10),
              const Expanded(child: Text('Payment Details', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
              _StatusBadge(p['status']?.toString() ?? 'pending'),
            ]),
            const SizedBox(height: 16),
            _Detail('Amount', '₱${_money(p['amount'])}'),
            _Detail('Method', _methodLabel(p['payment_method']?.toString() ?? 'online')),
            _Detail('Order ID', p['order_id']?.toString() ?? 'Not linked'),
            _Detail('Customer ID', p['customer_id']?.toString() ?? 'Not linked'),
            _Detail('Reference', p['transaction_reference']?.toString() ?? 'None'),
            _Detail('Created', _date(p['created_at'])),
            if ((p['notes']?.toString() ?? '').isNotEmpty) _Detail('Notes', p['notes'].toString()),
            const SizedBox(height: 14),
            if (p['status'] != 'paid')
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(sheetContext); _updateStatus(p, 'paid'); }, icon: const Icon(Icons.check_circle_rounded), label: const Text('Mark as Paid'))),
            if (p['status'] != 'refunded' && p['status'] == 'paid')
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(sheetContext); _updateStatus(p, 'refunded'); }, icon: const Icon(Icons.undo_rounded), label: const Text('Refund Payment'))),
          ]),
        ),
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
    'paid' => 'Paid', 'failed' => 'Failed', 'refunded' => 'Refunded', 'cancelled' => 'Cancelled', _ => 'Pending'
  };
  String _methodLabel(String value) => switch (value) {
    'cash_on_delivery' => 'Cash on Delivery', 'gcash' => 'GCash', 'card' => 'Card', _ => 'Online Payment'
  };
  String _money(dynamic value) => (double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2);
  String _date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? 'Unknown' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  void _message(String text) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F8F7),
    appBar: AppBar(title: const Text('Payments & Transactions', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh')]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _ErrorView(message: _error!, onRetry: _load) : RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      _Summary(payments: _payments, total: _total('all'), paid: _total('paid')),
      const SizedBox(height: 14),
      TextField(controller: _searchController, onChanged: (v) => setState(() => _search = v.trim()), decoration: InputDecoration(hintText: 'Search order, customer or reference...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _search.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _search = ''); }, icon: const Icon(Icons.clear_rounded)))),
      const SizedBox(height: 12),
      SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [for (final item in const [('All','all'),('Pending','pending'),('Paid','paid'),('Failed','failed'),('Refunded','refunded'),('Cancelled','cancelled')]) Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(item.$1), selected: _filter == item.$2, onSelected: (_) => setState(() => _filter = item.$2)))])),
      const SizedBox(height: 14),
      Text('${_filtered.length} transaction${_filtered.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700, color: HalalFoodTheme.textSecondary)),
      const SizedBox(height: 8),
      if (_filtered.isEmpty) const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: Text('No payment transactions found.')))
      else ..._filtered.map(_paymentCard),
    ])),
  );

  Widget _paymentCard(Map<String, dynamic> p) => Card(margin: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () => _showDetails(p), borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Icon(Icons.receipt_long_rounded, size: 24), const SizedBox(width: 10), Expanded(child: Text('₱${_money(p['amount'])}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))), _StatusBadge(p['status']?.toString() ?? 'pending')]),
    const SizedBox(height: 9),
    Text('Order: ${p['order_id']?.toString() ?? 'Not linked'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 3),
    Text('${_methodLabel(p['payment_method']?.toString() ?? 'online')} • ${_date(p['created_at'])}', style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
    if ((p['transaction_reference']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Ref: ${p['transaction_reference']}', style: const TextStyle(fontSize: 11))),
  ]))));
}

class _Summary extends StatelessWidget { final List<Map<String,dynamic>> payments; final double total; final double paid; const _Summary({required this.payments,required this.total,required this.paid}); @override Widget build(BuildContext context) { final pending=payments.where((p)=>p['status']=='pending').length; final refunded=payments.where((p)=>p['status']=='refunded').length; return Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [_Metric('Transactions','${payments.length}',Icons.receipt_long_rounded),_Metric('Volume','₱${total.toStringAsFixed(0)}',Icons.payments_rounded),_Metric('Paid','₱${paid.toStringAsFixed(0)}',Icons.check_circle_rounded),_Metric('Pending','$pending',Icons.pending_rounded),_Metric('Refunded','$refunded',Icons.undo_rounded)]))); } }
class _Metric extends StatelessWidget { final String label,value; final IconData icon; const _Metric(this.label,this.value,this.icon); @override Widget build(BuildContext context)=>Expanded(child: Column(children:[Icon(icon,size:19,color:HalalFoodTheme.primaryGreen),const SizedBox(height:4),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),Text(label,style:const TextStyle(fontSize:9,color:HalalFoodTheme.textSecondary))])); }
class _StatusBadge extends StatelessWidget { final String status; const _StatusBadge(this.status); @override Widget build(BuildContext context){final c=switch(status){ 'paid'=>Colors.green,'failed'=>Colors.red,'refunded'=>Colors.orange,'cancelled'=>Colors.grey,_=>Colors.blue}; return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:c.withValues(alpha:.10),borderRadius:BorderRadius.circular(8)),child:Text(status[0].toUpperCase()+status.substring(1),style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:c)));} }
class _Detail extends StatelessWidget { final String label,value; const _Detail(this.label,this.value); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:90,child:Text(label,style:const TextStyle(fontSize:12,color:HalalFoodTheme.textSecondary)),),Expanded(child:Text(value,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700))) ])); }
class _ErrorView extends StatelessWidget { final String message; final VoidCallback onRetry; const _ErrorView({required this.message,required this.onRetry}); @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline_rounded,size:54,color:Colors.redAccent),const SizedBox(height:12),const Text('Unable to load payments',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(message,textAlign:TextAlign.center,maxLines:5,overflow:TextOverflow.ellipsis),const SizedBox(height:16),ElevatedButton(onPressed:onRetry,child:const Text('Try Again'))]))); }
