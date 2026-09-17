import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSubscriptionPaymentReviewScreen extends StatefulWidget {
  const AdminSubscriptionPaymentReviewScreen({super.key});

  @override
  State<AdminSubscriptionPaymentReviewScreen> createState() =>
      _AdminSubscriptionPaymentReviewScreenState();
}

class _AdminSubscriptionPaymentReviewScreenState
    extends State<AdminSubscriptionPaymentReviewScreen> {
  final db = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> payments = [];
  final Set<String> _processingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final rows = await db
          .from('subscription_payments')
          .select(
            '*, restaurants(id,name), restaurant_subscriptions(id,status,billing_cycle,plan_id,subscription_plans(id,name))',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => payments = List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (e) {
      if (mounted) _message('Unable to load pending payments: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _signedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await db.storage
          .from('subscription-payment-proofs')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _confirmApproval() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Payment?'),
        content: const Text(
          'This will mark the payment as paid and activate the restaurant subscription.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _approve(Map<String, dynamic> p) async {
    final paymentId = p['id']?.toString();
    final subscriptionId = p['subscription_id']?.toString() ??
        (p['restaurant_subscriptions'] is Map
            ? p['restaurant_subscriptions']['id']?.toString()
            : null);
    if (paymentId == null || subscriptionId == null) return;
    if (_processingIds.contains(paymentId)) return;

    final confirmed = await _confirmApproval();
    if (!confirmed || !mounted) return;

    setState(() => _processingIds.add(paymentId));
    try {
      final sub = p['restaurant_subscriptions'];
      final cycle = sub is Map && sub['billing_cycle']?.toString() == 'annual'
          ? 'annual'
          : 'monthly';
      final now = DateTime.now().toUtc();
      final end = cycle == 'annual'
          ? DateTime.utc(now.year + 1, now.month, now.day)
          : DateTime.utc(now.year, now.month + 1, now.day);

      final paymentUpdated = await db
          .from('subscription_payments')
          .update({
            'status': 'paid',
            'paid_at': now.toIso8601String(),
            'billing_period_start': now.toIso8601String(),
            'billing_period_end': end.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', paymentId)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();

      if (paymentUpdated == null) {
        await _load();
        if (mounted) _message('This payment was already processed.');
        return;
      }

      try {
        final subscriptionUpdated = await db
            .from('restaurant_subscriptions')
            .update({
              'status': 'active',
              'started_at': now.toIso8601String(),
              'current_period_start': now.toIso8601String(),
              'current_period_end': end.toIso8601String(),
              'next_billing_at': end.toIso8601String(),
              'cancelled_at': null,
              'suspended_at': null,
            })
            .eq('id', subscriptionId)
            .eq('status', 'pending')
            .select('id')
            .maybeSingle();

        if (subscriptionUpdated == null) {
          await db
              .from('subscription_payments')
              .update({
                'status': 'pending',
                'paid_at': null,
                'billing_period_start': null,
                'billing_period_end': null,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', paymentId)
              .eq('status', 'paid');
          await _load();
          if (mounted) {
            _message('Subscription was already processed. Payment returned to pending.');
          }
          return;
        }
      } catch (e) {
        await db
            .from('subscription_payments')
            .update({
              'status': 'pending',
              'paid_at': null,
              'billing_period_start': null,
              'billing_period_end': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', paymentId)
            .eq('status', 'paid');
        rethrow;
      }

      await _load();
      if (mounted) _message('Payment approved and subscription activated.');
    } catch (e) {
      if (mounted) _message('Unable to approve payment: $e');
    } finally {
      if (mounted) setState(() => _processingIds.remove(paymentId));
    }
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    final paymentId = p['id']?.toString();
    final subscriptionId = p['subscription_id']?.toString() ??
        (p['restaurant_subscriptions'] is Map
            ? p['restaurant_subscriptions']['id']?.toString()
            : null);
    if (paymentId == null || subscriptionId == null) return;
    if (_processingIds.contains(paymentId)) return;

    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      reason.dispose();
      return;
    }

    final trimmedReason = reason.text.trim();
    if (trimmedReason.isEmpty) {
      reason.dispose();
      _message('Please provide a rejection reason.');
      return;
    }

    setState(() => _processingIds.add(paymentId));
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final paymentUpdated = await db
          .from('subscription_payments')
          .update({
            'status': 'rejected',
            'notes': trimmedReason,
            'updated_at': now,
          })
          .eq('id', paymentId)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();

      if (paymentUpdated == null) {
        await _load();
        if (mounted) _message('This payment was already processed.');
        return;
      }

      try {
        await db
            .from('restaurant_subscriptions')
            .update({
              'status': 'cancelled',
              'cancelled_at': now,
              'notes': trimmedReason,
            })
            .eq('id', subscriptionId)
            .eq('status', 'pending');
      } catch (e) {
        await db
            .from('subscription_payments')
            .update({
              'status': 'pending',
              'notes': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', paymentId)
            .eq('status', 'rejected');
        rethrow;
      }

      await _load();
      if (mounted) _message('Payment rejected.');
    } catch (e) {
      if (mounted) _message('Unable to reject payment: $e');
    } finally {
      reason.dispose();
      if (mounted) setState(() => _processingIds.remove(paymentId));
    }
  }

  void _message(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Subscription Payments',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: payments.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(child: Text('No pending subscription payments.')),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        itemBuilder: (_, i) => _card(payments[i]),
                      ),
              ),
      );

  Widget _card(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'pending';
    final paymentId = p['id']?.toString() ?? '';
    final processing = _processingIds.contains(paymentId);
    final restaurant = p['restaurants'];
    final sub = p['restaurant_subscriptions'];
    final plan = sub is Map ? sub['subscription_plans'] : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    restaurant is Map
                        ? restaurant['name']?.toString() ?? 'Restaurant'
                        : 'Restaurant',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text(status.toUpperCase())),
              ],
            ),
            Text(
              'Plan: ${plan is Map ? plan['name']?.toString() ?? 'Plan' : 'Plan'} • ${sub is Map ? sub['billing_cycle']?.toString() ?? 'monthly' : 'monthly'}',
            ),
            Text(
              'Amount: ₱${double.tryParse(p['amount']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'}',
            ),
            Text('Method: ${p['payment_method'] ?? 'Not specified'}'),
            Text(
              'Reference: ${p['transaction_reference'] ?? 'Not specified'}',
            ),
            if ((p['notes']?.toString() ?? '').isNotEmpty)
              Text('Notes: ${p['notes']}'),
            const SizedBox(height: 12),
            FutureBuilder<String?>(
              future: _signedUrl(p['proof_path']?.toString()),
              builder: (context, snap) => snap.data == null
                  ? const Text('Payment proof unavailable.')
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        snap.data!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: processing ? null : () => _reject(p),
                      icon: processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: processing ? null : () => _approve(p),
                      icon: processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
