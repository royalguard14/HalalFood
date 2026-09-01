import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerSubscriptionManagementScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerSubscriptionManagementScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerSubscriptionManagementScreen> createState() =>
      _OwnerSubscriptionManagementScreenState();
}

class _OwnerSubscriptionManagementScreenState
    extends State<OwnerSubscriptionManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _supabase
          .from('restaurant_subscriptions')
          .select(
            '*, subscription_plans(id,name,monthly_price,annual_price)',
          )
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _subscription = response;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not set';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String value) => switch (value.toLowerCase()) {
        'active' => 'Active',
        'trial' => 'Trial',
        'past_due' => 'Past Due',
        'grace_period' => 'Grace Period',
        'suspended' => 'Suspended',
        'cancelled' => 'Cancelled',
        'expired' => 'Expired',
        _ => 'No Active Plan',
      };

  Color _statusColor(String value) => switch (value.toLowerCase()) {
        'active' || 'trial' => Colors.green,
        'past_due' || 'grace_period' => Colors.orange,
        'suspended' || 'cancelled' || 'expired' => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Subscription',
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
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.error_outline_rounded, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load subscription',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      Center(child: ElevatedButton(onPressed: _load, child: const Text('Try Again'))),
                    ],
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final subscription = _subscription;
    if (subscription == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 70),
          const Icon(Icons.workspace_premium_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 18),
          const Text(
            'No Active Plan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your restaurant does not have a subscription yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: HalalFoodTheme.textSecondary),
          ),
        ],
      );
    }

    final plan = subscription['subscription_plans'];
    final planName = plan is Map ? plan['name']?.toString() ?? 'Subscription Plan' : 'Subscription Plan';
    final status = subscription['status']?.toString() ?? 'unknown';
    final billing = subscription['billing_cycle']?.toString() == 'annual' ? 'Annual' : 'Monthly';
    final color = _statusColor(status);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(widget.restaurantName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.workspace_premium_rounded, color: color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(planName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(billing, style: const TextStyle(color: HalalFoodTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                _row('Started', _date(subscription['started_at'])),
                _row('Current Period', '${_date(subscription['current_period_start'])} – ${_date(subscription['current_period_end'])}'),
                _row('Next Billing', _date(subscription['next_billing_at'])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: HalalFoodTheme.primaryGreen),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subscription changes are managed by the HALAL Food administrator. Contact support if your plan or expiry date is incorrect.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 115, child: Text(label, style: const TextStyle(color: HalalFoodTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
