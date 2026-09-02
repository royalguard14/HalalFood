import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import 'admin_subscription_payment_review_screen.dart';
import 'halal_verification_screen.dart';

class AdminActionCenterScreen extends StatefulWidget {
  const AdminActionCenterScreen({super.key});

  @override
  State<AdminActionCenterScreen> createState() => _AdminActionCenterScreenState();
}

class _AdminActionCenterScreenState extends State<AdminActionCenterScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _actions = [];
  RealtimeChannel? _verificationChannel;
  RealtimeChannel? _paymentChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _verificationChannel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _db
            .from('halal_verifications')
            .select('id, restaurant_id, status, requested_status, created_at, restaurants(name)')
            .eq('status', 'pending')
            .order('created_at', ascending: false),
        _db
            .from('subscription_payments')
            .select('id, subscription_id, amount, payment_method, transaction_reference, created_at, restaurants(name)')
            .eq('status', 'pending')
            .order('created_at', ascending: false),
      ]);

      final verificationRows = List<Map<String, dynamic>>.from(results[0] as List);
      final paymentRows = List<Map<String, dynamic>>.from(results[1] as List);
      final actions = <Map<String, dynamic>>[];

      for (final row in verificationRows) {
        final restaurant = row['restaurants'];
        actions.add({
          'type': 'verification',
          'id': row['id'],
          'title': restaurant is Map
              ? restaurant['name']?.toString() ?? 'Restaurant'
              : 'Restaurant',
          'subtitle': 'New halal verification request',
          'created_at': row['created_at'],
        });
      }

      for (final row in paymentRows) {
        final restaurant = row['restaurants'];
        final amount = double.tryParse(row['amount']?.toString() ?? '') ?? 0;
        actions.add({
          'type': 'payment',
          'id': row['id'],
          'title': restaurant is Map
              ? restaurant['name']?.toString() ?? 'Restaurant'
              : 'Restaurant',
          'subtitle': 'Subscription payment • ₱${amount.toStringAsFixed(2)}',
          'created_at': row['created_at'],
        });
      }

      actions.sort(
        (a, b) => (b['created_at']?.toString() ?? '')
            .compareTo(a['created_at']?.toString() ?? ''),
      );

      if (mounted) {
        setState(() {
          _actions = actions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _subscribe() {
    _verificationChannel = _db
        .channel('admin-action-center-verifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'halal_verifications',
          callback: (_) => _load(),
        )
        .subscribe();

    _paymentChannel = _db
        .channel('admin-action-center-payments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscription_payments',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _openAction(Map<String, dynamic> action) async {
    final type = action['type'];

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => type == 'verification'
            ? const HalalVerificationScreen()
            : const AdminSubscriptionPaymentReviewScreen(),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text(
          'Admin Action Center',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 260),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 52,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load action center',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                : _actions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          const SizedBox(height: 100),
                          Icon(
                            Icons.task_alt_rounded,
                            size: 58,
                            color: HalalFoodTheme.primaryGreen,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'You are all caught up!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'There are no pending admin reviews right now.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: HalalFoodTheme.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                        itemCount: _actions.length,
                        itemBuilder: (_, i) => _actionCard(_actions[i]),
                      ),
      ),
    );
  }

  Widget _actionCard(Map<String, dynamic> action) {
    final verification = action['type'] == 'verification';
    final color = verification ? Colors.orange : Colors.deepOrange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAction(action),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  verification
                      ? Icons.verified_rounded
                      : Icons.payments_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['title']?.toString() ?? 'Action',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action['subtitle']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HalalFoodTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      verification
                          ? 'REVIEW VERIFICATION'
                          : 'REVIEW PAYMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
