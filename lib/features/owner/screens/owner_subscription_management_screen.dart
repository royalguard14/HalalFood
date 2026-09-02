import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import 'owner_subscribe_screen.dart';

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
  Map<String, dynamic>? _payment;

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
      final subscription = await _supabase
          .from('restaurant_subscriptions')
          .select(
            '*, subscription_plans(id,name,monthly_price,annual_price)',
          )
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Map<String, dynamic>? payment;
      if (subscription != null) {
        payment = await _supabase
            .from('subscription_payments')
            .select(
              'status,payment_method,transaction_reference,notes,created_at',
            )
            .eq('subscription_id', subscription['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (!mounted) return;
      setState(() {
        _subscription = subscription;
        _payment = payment;
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

  Future<void> _choosePlan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerSubscribeScreen(
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName,
        ),
      ),
    );

    if (mounted) await _load();
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not set';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'trial':
        return 'Trial';
      case 'pending':
        return 'Pending Review';
      case 'past_due':
        return 'Past Due';
      case 'grace_period':
        return 'Grace Period';
      case 'suspended':
        return 'Suspended';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return 'No Active Plan';
    }
  }

  Color _statusColor(String value) {
    switch (value.toLowerCase()) {
      case 'active':
      case 'trial':
        return Colors.green;
      case 'pending':
      case 'past_due':
      case 'grace_period':
        return Colors.orange;
      case 'suspended':
      case 'cancelled':
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 280),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? _errorView()
                : _buildContent(),
      ),
    );
  }

  Widget _errorView() {
    return ListView(
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
        Center(
          child: ElevatedButton(
            onPressed: _load,
            child: const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final subscription = _subscription;
    if (subscription == null) {
      return _noPlan(
        'Your restaurant does not have a subscription yet.',
      );
    }

    final status = subscription['status']?.toString() ?? 'unknown';
    final planData = subscription['subscription_plans'];
    final planName = planData is Map
        ? planData['name']?.toString() ?? 'Subscription Plan'
        : 'Subscription Plan';
    final billing = subscription['billing_cycle']?.toString() == 'annual'
        ? 'Annual'
        : 'Monthly';
    final color = _statusColor(status);
    final lowerStatus = status.toLowerCase();
    final canResubscribe = lowerStatus == 'cancelled' || lowerStatus == 'expired';
    final pending = lowerStatus == 'pending';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          widget.restaurantName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
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
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            billing,
                            style: TextStyle(
                              color: HalalFoodTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                _row('Started', _date(subscription['started_at'])),
                _row(
                  'Current Period',
                  '${_date(subscription['current_period_start'])} – ${_date(subscription['current_period_end'])}',
                ),
                _row('Next Billing', _date(subscription['next_billing_at'])),
              ],
            ),
          ),
        ),
        if (pending && _payment != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.orange.withValues(alpha: .08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Under Review',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Method: ${_payment!['payment_method'] ?? 'Not specified'}',
                  ),
                  Text(
                    'Reference: ${_payment!['transaction_reference'] ?? 'Not specified'}',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The administrator must verify your payment before the plan becomes active.',
                  ),
                ],
              ),
            ),
          ),
        ],
        if (canResubscribe) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _choosePlan,
              icon: const Icon(Icons.autorenew_rounded),
              label: const Text(
                'Choose a New Subscription Plan',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
        if (!canResubscribe && !pending && lowerStatus != 'active') ...[
          const SizedBox(height: 14),
          Text(
            'This subscription is not active. You may contact the administrator or wait for the current review to finish.',
            style: TextStyle(color: HalalFoodTheme.textSecondary),
          ),
        ],
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: HalalFoodTheme.primaryGreen,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Subscription activation is controlled by the HALAL Food administrator after payment verification.',
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

  Widget _noPlan(String text) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 55),
        const Icon(
          Icons.workspace_premium_outlined,
          size: 72,
          color: Colors.grey,
        ),
        const SizedBox(height: 18),
        const Text(
          'No Active Plan',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: HalalFoodTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _choosePlan,
            icon: const Icon(Icons.workspace_premium_rounded),
            label: const Text(
              'Choose a Subscription Plan',
              style: TextStyle(fontWeight: FontWeight.w800),
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
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(color: HalalFoodTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
