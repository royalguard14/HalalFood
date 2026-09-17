import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _picker = ImagePicker();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _blockingStatus;
  List<Map<String, dynamic>> _plans = [];
  Map<String, List<Map<String, dynamic>>> _methodsByPlan = {};

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<String?> _loadBlockingSubscriptionStatus() async {
    final row = await _supabase
        .from('restaurant_subscriptions')
        .select('id,status')
        .eq('restaurant_id', widget.restaurantId)
        .inFilter('status', [
          'pending',
          'trial',
          'active',
          'past_due',
          'grace_period',
        ])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return row?['status']?.toString();
  }

  String _blockingMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Your restaurant already has a subscription payment pending admin review.';
      case 'trial':
        return 'Your restaurant already has an active trial subscription.';
      case 'active':
        return 'Your restaurant already has an active subscription.';
      case 'past_due':
        return 'Your restaurant already has a past-due subscription. Please resolve it before starting another subscription.';
      case 'grace_period':
        return 'Your restaurant already has a subscription in its grace period.';
      default:
        return 'Your restaurant already has a subscription that must be resolved before starting another one.';
    }
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
      _blockingStatus = null;
    });

    try {
      final blockingStatus = await _loadBlockingSubscriptionStatus();
      if (blockingStatus != null) {
        if (!mounted) return;
        setState(() {
          _blockingStatus = blockingStatus;
          _loading = false;
        });
        return;
      }

      final plansRaw = await _supabase
          .from('subscription_plans')
          .select(
            'id,name,description,monthly_price,annual_price,features',
          )
          .eq('is_active', true)
          .order('sort_order');

      final plans = List<Map<String, dynamic>>.from(plansRaw as List);
      final ids = plans
          .map((plan) => plan['id'])
          .whereType<String>()
          .toList();
      final methods = <String, Map<String, dynamic>>{};
      final methodsByPlan = <String, List<Map<String, dynamic>>>{};

      if (ids.isNotEmpty) {
        final linksRaw = await _supabase
            .from('subscription_plan_payment_methods')
            .select('plan_id,payment_method_id')
            .inFilter('plan_id', ids);
        final linkRows = List<Map<String, dynamic>>.from(linksRaw as List);
        final methodIds = linkRows
            .map((row) => row['payment_method_id'])
            .whereType<String>()
            .toSet()
            .toList();

        if (methodIds.isNotEmpty) {
          final methodRaw = await _supabase
              .from('subscription_payment_methods')
              .select(
                'id,name,type,account_name,account_number,instructions,qr_code_url,is_active',
              )
              .inFilter('id', methodIds)
              .eq('is_active', true);

          for (final method
              in List<Map<String, dynamic>>.from(methodRaw as List)) {
            methods[method['id'].toString()] = method;
          }
        }

        for (final link in linkRows) {
          final planId = link['plan_id']?.toString();
          final methodId = link['payment_method_id']?.toString();
          if (planId == null || methodId == null) continue;

          final method = methods[methodId];
          if (method != null) {
            (methodsByPlan[planId] ??= []).add(method);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _methodsByPlan = methodsByPlan;
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

  Future<void> _cleanupFailedSubmission({
    required String subscriptionId,
    String? proofPath,
  }) async {
    if (proofPath != null) {
      try {
        await _supabase.storage
            .from('subscription-payment-proofs')
            .remove([proofPath]);
      } catch (_) {
        // Best-effort cleanup. The database row remains the authoritative state.
      }
    }

    try {
      await _supabase
          .from('restaurant_subscriptions')
          .delete()
          .eq('id', subscriptionId)
          .eq('restaurant_id', widget.restaurantId)
          .eq('status', 'pending');
    } catch (_) {
      // Best-effort cleanup. If deletion is blocked, the pending row remains
      // visible for the owner/admin to resolve rather than being silently lost.
    }
  }

  Future<bool> _hasBlockingSubscription({bool showMessage = true}) async {
    final status = await _loadBlockingSubscriptionStatus();
    if (status == null) return false;

    if (mounted) {
      setState(() => _blockingStatus = status);
      if (showMessage) _message(_blockingMessage(status));
    }
    return true;
  }

  Future<void> _subscribe(Map<String, dynamic> plan, bool annual) async {
    if (_submitting) return;

    if (await _hasBlockingSubscription()) return;
    if (!mounted) return;

    final planId = plan['id']?.toString();
    if (planId == null) return;

    final methods = _methodsByPlan[planId] ?? [];
    if (methods.isEmpty) {
      _message(
        'This plan has no payment method configured. Please contact the administrator.',
      );
      return;
    }

    final rawPrice = annual ? plan['annual_price'] : plan['monthly_price'];
    final price = double.tryParse(rawPrice?.toString() ?? '') ?? 0;
    Map<String, dynamic>? selectedMethod;
    final referenceController = TextEditingController();
    XFile? proof;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Subscription Payment'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan['name']} • ${annual ? 'Annual' : 'Monthly'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ₱${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select payment method',
                    ),
                    items: methods
                        .map(
                          (method) => DropdownMenuItem<Map<String, dynamic>>(
                            value: method,
                            child: Text(
                              method['name']?.toString() ?? 'Payment Method',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedMethod = value),
                  ),
                  if (selectedMethod != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((selectedMethod!['account_name']
                                        ?.toString() ??
                                    '')
                                .isNotEmpty)
                              Text(
                                'Account Name: ${selectedMethod!['account_name']}',
                              ),
                            if ((selectedMethod!['account_number']
                                        ?.toString() ??
                                    '')
                                .isNotEmpty)
                              Text(
                                'Account/Number: ${selectedMethod!['account_number']}',
                              ),
                            if ((selectedMethod!['instructions']
                                        ?.toString() ??
                                    '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  selectedMethod!['instructions'].toString(),
                                ),
                              ),
                            if ((selectedMethod!['qr_code_url']?.toString() ??
                                    '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SelectableText(
                                  selectedMethod!['qr_code_url'].toString(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction / Reference Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setDialogState(() => proof = picked);
                      }
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      proof == null
                          ? 'Upload Payment Screenshot'
                          : 'Proof Selected: ${proof!.name}',
                    ),
                  ),
                  if (proof != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Payment proof is required before submission.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedMethod == null ||
                      referenceController.text.trim().isEmpty ||
                      proof == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );

    final proofFile = proof;
    final paymentMethod = selectedMethod;

    if (submitted != true ||
        paymentMethod == null ||
        proofFile == null ||
        !mounted) {
      referenceController.dispose();
      return;
    }

    setState(() => _submitting = true);

    String? subscriptionId;
    String? proofPath;

    try {
      // Re-check immediately before the insert so stale UI cannot submit a
      // second subscription after another session has already created one.
      if (await _hasBlockingSubscription()) return;

      final now = DateTime.now().toUtc();
      final periodEnd = annual
          ? DateTime.utc(now.year + 1, now.month, now.day)
          : DateTime.utc(now.year, now.month + 1, now.day);

      final sub = await _supabase
          .from('restaurant_subscriptions')
          .insert({
            'restaurant_id': widget.restaurantId,
            'plan_id': planId,
            'status': 'pending',
            'billing_cycle': annual ? 'annual' : 'monthly',
            'started_at': now.toIso8601String(),
            'current_period_start': now.toIso8601String(),
            'current_period_end': periodEnd.toIso8601String(),
          })
          .select('id')
          .single();

      subscriptionId = sub['id'].toString();
      final bytes = await proofFile.readAsBytes();
      proofPath =
          '${widget.restaurantId}/$subscriptionId-${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('subscription-payment-proofs')
          .uploadBinary(
            proofPath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      await _supabase.from('subscription_payments').insert({
        'subscription_id': subscriptionId,
        'restaurant_id': widget.restaurantId,
        'amount': price,
        'currency': 'PHP',
        'status': 'pending',
        'payment_method': paymentMethod['name']?.toString(),
        'transaction_reference': referenceController.text.trim(),
        'proof_path': proofPath,
        'billing_period_start': now.toIso8601String(),
        'billing_period_end': periodEnd.toIso8601String(),
      });

      if (!mounted) return;
      _message(
        'Payment submitted. Your subscription is pending admin verification.',
      );
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (subscriptionId != null) {
        await _cleanupFailedSubmission(
          subscriptionId: subscriptionId,
          proofPath: proofPath,
        );
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      if (e.code == '23505') {
        _message(
          'A subscription is already active or pending for this restaurant. Please refresh and check the subscription status.',
        );
      } else {
        _message('Unable to submit payment: ${e.message}');
      }
    } catch (e) {
      if (subscriptionId != null) {
        await _cleanupFailedSubmission(
          subscriptionId: subscriptionId,
          proofPath: proofPath,
        );
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      _message('Unable to submit payment: $e');
    } finally {
      referenceController.dispose();
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
          const Text(
            'Unable to load subscription plans.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPlans,
            child: const Text('Try Again'),
          ),
        ],
      );
    }

    if (_blockingStatus != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.lock_clock_rounded,
            size: 58,
            color: HalalFoodTheme.primaryGreen,
          ),
          const SizedBox(height: 16),
          const Text(
            'Subscription Already Exists',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            _blockingMessage(_blockingStatus!),
            textAlign: TextAlign.center,
            style: TextStyle(color: HalalFoodTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _loadPlans,
            child: const Text('Refresh Status'),
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
    final monthly =
        double.tryParse(plan['monthly_price']?.toString() ?? '') ?? 0;
    final annual =
        double.tryParse(plan['annual_price']?.toString() ?? '') ?? 0;
    final methods = _methodsByPlan[plan['id']?.toString()] ?? [];

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
            const SizedBox(height: 12),
            Text(
              methods.isEmpty
                  ? 'Payment method not configured'
                  : 'Payment: ${methods.map((m) => m['name']?.toString() ?? '').join(', ')}',
              style: TextStyle(
                color: methods.isEmpty
                    ? Colors.red
                    : HalalFoodTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting || methods.isEmpty
                        ? null
                        : () => _subscribe(plan, false),
                    child: const Text('Subscribe Monthly'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting || annual <= 0 || methods.isEmpty
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
