import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';

class OwnerSubscribeScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerSubscribeScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerSubscribeScreen> createState() => _OwnerSubscribeScreenState();
}

class _OwnerSubscribeScreenState extends State<OwnerSubscribeScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _subscribing = false;
  String? _error;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _supabase
          .from('subscription_plans')
          .select('id,name,description,monthly_price,annual_price,features')
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _plans = List<Map<String, dynamic>>.from(rows as List);
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

  Future<void> _subscribe(Map<String, dynamic> plan, bool annual) async {
    if (_subscribing) return;

    final name = plan['name']?.toString() ?? 'Subscription Plan';
    final rawPrice = annual ? plan['annual_price'] : plan['monthly_price'];
    final price = double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Subscription'),
        content: Text(
          'Subscribe ${widget.restaurantName} to $name '
          '(${annual ? 'Annual' : 'Monthly'}) for '
          '₱${price.toStringAsFixed(2)}?\n\n'
          'Payment integration will be connected in the payment phase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _subscribing = true);

    try {
      final now = DateTime.now().toUtc();
      final end = annual
          ? DateTime.utc(now.year + 1, now.month, now.day)
          : DateTime.utc(now.year, now.month + 1, now.day);

      await _supabase.from('restaurant_subscriptions').insert({
        'restaurant_id': widget.restaurantId,
        'subscription_plan_id': plan['id'],
        'status': 'active',
        'billing_cycle': annual ? 'annual' : 'monthly',
        'started_at': now.toIso8601String(),
        'current_period_start': now.toIso8601String(),
        'current_period_end': end.toIso8601String(),
        'next_billing_at': end.toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription activated successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _subscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to subscribe: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose a Subscription',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlans,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 280),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPlans,
            child: const Text('Try Again'),
          ),
        ],
      );
    }

    if (_plans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No subscription plans are available yet.')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text(
          widget.restaurantName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the plan that fits your restaurant.',
          style: TextStyle(color: HalalFoodTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ..._plans.map(_planCard),
      ],
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final features = plan['features'] is List
        ? (plan['features'] as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
        : <String>[];
    final monthly = double.tryParse(plan['monthly_price']?.toString() ?? '') ?? 0;
    final annual = double.tryParse(plan['annual_price']?.toString() ?? '') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['name']?.toString() ?? 'Plan',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            if ((plan['description']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  plan['description'].toString(),
                  style: TextStyle(color: HalalFoodTheme.textSecondary),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              '₱${monthly.toStringAsFixed(2)} / month',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
            if (annual > 0)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '₱${annual.toStringAsFixed(2)} / year',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (features.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features
                      .map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: HalalFoodTheme.primaryGreen,
                              ),
                              const SizedBox(width: 7),
                              Expanded(child: Text(feature)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _subscribing
                        ? null
                        : () => _subscribe(plan, false),
                    child: const Text('Subscribe Monthly'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _subscribing || annual <= 0
                        ? null
                        : () => _subscribe(plan, true),
                    child: const Text('Subscribe Annual'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
