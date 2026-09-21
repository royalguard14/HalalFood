import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OwnerOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<OwnerOrderDetailsScreen> createState() =>
      _OwnerOrderDetailsScreenState();
}

class _OwnerOrderDetailsScreenState extends State<OwnerOrderDetailsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _receiptUrl;
  String? _pickupPaymentState;
  bool _showReceipt = false;
  bool _pickupFinalPaymentPaid = false;
  double _gcashDownpaymentPaid = 0;
  double _cashPickupPaid = 0;
  String? _error;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.order['status']?.toString() ?? 'pending';
    _pickupPaymentState =
        widget.order['pickup_downpayment_status']?.toString() ?? 'pending';
    _pickupFinalPaymentPaid =
        widget.order['payment_status']?.toString() == 'paid';
    _loadOrderItems();
    _loadPickupReceipt();
    _loadPickupPayments();
  }

  Future<void> _loadPickupPayments() async {
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) return;
      final rows = await _supabase
          .from('payments')
          .select('amount,payment_method,status,notes,paid_at')
          .eq('order_id', orderId)
          .eq('status', 'paid');
      double gcash = 0;
      double cash = 0;
      for (final row in rows as List) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final method = row['payment_method']?.toString().toLowerCase();
        if (method == 'gcash') gcash += amount;
        if (method == 'cash_on_delivery') cash += amount;
      }
      if (mounted) {
        setState(() {
          _gcashDownpaymentPaid = gcash;
          _cashPickupPaid = cash;
        });
      }
    } catch (e) {
      debugPrint('OWNER PICKUP PAYMENTS ERROR: $e');
    }
  }

  Future<void> _loadPickupReceipt() async {
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) return;
      final freshOrder = await _supabase
          .from('orders')
          .select(
            'pickup_receipt_path,pickup_receipt_submitted_at,'
            'pickup_downpayment_status,payment_status',
          )
          .eq('id', orderId)
          .maybeSingle();

      final freshState = freshOrder?['pickup_downpayment_status']?.toString();
      final freshPaymentStatus = freshOrder?['payment_status']?.toString();
      if (mounted && freshState != null && freshState.isNotEmpty) {
        setState(() {
          _pickupPaymentState = freshState;
          _pickupFinalPaymentPaid = freshPaymentStatus == 'paid';
        });
      }

      final path = freshOrder?['pickup_receipt_path']?.toString().trim();
      if (path == null || path.isEmpty) return;
      final url = await _supabase.storage
          .from('payment-receipts')
          .createSignedUrl(path, 900);
      if (mounted) setState(() => _receiptUrl = url);
    } catch (e) {
      debugPrint('OWNER RECEIPT ERROR: $e');
    }
  }

  Future<void> _confirmPickupReceipt() async {
    final result = await _showPickupPaymentDialog(
      title: 'Confirm GCash Downpayment',
      amountLabel: 'Amount Received',
      requireReference: true,
      initialAmount:
          (widget.order['pickup_downpayment_amount'] as num?)?.toDouble(),
    );
    if (result == null) return;
    await _recordPickupPayment(
      stage: 'downpayment',
      amount: result.amount,
      reference: result.reference,
      paymentMethod: 'gcash',
    );
  }

  Future<void> _recordFinalPickupPayment() async {
    final total = (widget.order['total_amount'] as num?)?.toDouble() ?? 0;
    final downpayment =
        (widget.order['pickup_downpayment_amount'] as num?)?.toDouble() ?? 0;
    final remaining =
        (total - downpayment).clamp(0, double.infinity).toDouble();

    final result = await _showPickupPaymentDialog(
      title: 'Record Remaining Payment',
      amountLabel: 'Amount Received',
      requireReference: false,
      initialAmount: remaining,
      expectedAmount: remaining,
    );
    if (result == null) return;
    await _recordPickupPayment(
      stage: 'final',
      amount: result.amount,
      paymentMethod: 'cash_on_delivery',
    );
  }

  Future<_PickupPaymentInput?> _showPickupPaymentDialog({
    required String title,
    required String amountLabel,
    required bool requireReference,
    double? initialAmount,
    double? expectedAmount,
  }) async {
    final amountController = TextEditingController(
      text: initialAmount == null ? '' : initialAmount.toStringAsFixed(2),
    );
    final referenceController = TextEditingController();
    const paymentMethod = 'cash_on_delivery';

    final result = await showDialog<_PickupPaymentInput>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: amountLabel,
                  prefixText: '₱ ',
                ),
              ),
              if (requireReference) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Payment Method: Cash',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Date & time are recorded automatically.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (expectedAmount != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Exact remaining balance: ₱${expectedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                amountController.text.trim().replaceAll(',', ''),
              );
              final reference = referenceController.text.trim();
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid payment amount.')),
                );
                return;
              }
              if (requireReference && reference.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter the GCash reference number.'),
                  ),
                );
                return;
              }
              if (expectedAmount != null &&
                  (amount - expectedAmount).abs() > 0.005) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment must be exactly ₱${expectedAmount.toStringAsFixed(2)}.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                _PickupPaymentInput(
                  amount: amount,
                  reference: requireReference ? reference : null,
                  paymentMethod: paymentMethod,
                ),
              );
            },
            child: const Text('Accept Payment'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountController.dispose();
      referenceController.dispose();
    });
    return result;
  }

  Future<void> _recordPickupPayment({
    required String stage,
    required double amount,
    String? reference,
    required String paymentMethod,
  }) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID.');
      }
      await _supabase.rpc(
        'record_owner_pickup_payment',
        params: {
          'p_order_id': orderId,
          'p_stage': stage,
          'p_amount': amount,
          'p_reference': reference,
          'p_payment_method': paymentMethod,
        },
      );
      if (!mounted) return;
      setState(() {
        if (stage == 'downpayment') {
          _pickupPaymentState = 'paid';
          _pickupFinalPaymentPaid =
              amount >=
                  ((widget.order['total_amount'] as num?)?.toDouble() ?? 0) -
                      0.005;
          _status = 'confirmed';
        } else {
          _pickupFinalPaymentPaid = true;
        }
        _isUpdating = false;
      });
      await _loadPickupPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stage == 'downpayment'
                ? 'Downpayment accepted. Order is now Confirmed.'
                : 'Remaining payment accepted. Order is fully paid.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      final message = e is PostgrestException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _rejectPickupReceipt() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payment receipt'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Example: Amount does not match GCash transaction.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _updatePickupPayment('receipt_rejected', reason: reason);
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  Future<void> _updatePickupPayment(String state, {String? reason}) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID.');
      }
      final data = <String, dynamic>{'pickup_downpayment_status': state};
      if (state == 'paid') data['status'] = 'confirmed';
      if (state == 'receipt_rejected') {
        data['pickup_receipt_rejection_reason'] = reason;
      }
      await _supabase.from('orders').update(data).eq('id', orderId);
      if (state == 'paid') {
        await _supabase
            .from('payments')
            .update({'status': 'paid'})
            .eq('order_id', orderId)
            .eq('payment_method', 'online');
      }
      if (!mounted) return;
      setState(() {
        _pickupPaymentState = state;
        if (state == 'paid') _pickupFinalPaymentPaid = false;
        _status = state == 'paid'
            ? 'confirmed'
            : (widget.order['status']?.toString() ?? _status);
        if (state == 'receipt_rejected') {
          _receiptUrl = null;
          _showReceipt = false;
        }
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state == 'paid'
                ? 'Receipt accepted. The order can now be processed.'
                : 'Receipt rejected. Customer can upload another receipt.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update payment: $e')),
        );
      }
    }
  }

  Future<void> _loadOrderItems() async {
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID.');
      }
      final response = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);
      if (!mounted) return;
      setState(() {
        _items = (response as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID.');
      }
      final isPickup =
          widget.order['fulfillment_type']?.toString().toLowerCase() == 'pickup';
      newStatus = newStatus.trim().replaceAll("'", '');
      if (isPickup && newStatus == 'ready_to_pick_up') {
        newStatus = 'ready';
      } else if (isPickup && newStatus == 'full_payment') {
        await _recordFinalPickupPayment();
        if (mounted) setState(() => _isUpdating = false);
        return;
      } else if (isPickup && newStatus == 'claimed') {
        newStatus = 'delivered';
      }
      await _supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
      if (!mounted) return;
      setState(() {
        _status = newStatus;
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to ${_displayStatus(newStatus)}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update order: $e')),
      );
    }
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ready_to_pick_up':
      case 'ready_to_pickup':
        return 'Ready to Pick Up';
      case 'full_payment':
      case 'payment_due':
        return 'Payment Complete';
      case 'claimed':
      case 'picked_up':
      case 'pickedup':
        return 'Claimed';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'out_for_delivery':
      case 'on_the_way':
        return 'Out for Delivery';
      case 'completed':
      case 'delivered':
        return 'Completed';
      default:
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}')
            .join(' ');
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
      case 'ready_to_pick_up':
        return Colors.deepPurple;
      case 'full_payment':
        return Colors.teal;
      case 'claimed':
      case 'picked_up':
      case 'pickedup':
        return Colors.green;
      case 'out_for_delivery':
      case 'on_the_way':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return HalalFoodTheme.primaryGreen;
    }
  }

  String _shortOrderId(String id) =>
      id.length <= 8 ? id : id.substring(0, 8);

  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['id']?.toString() ?? '';
    final total = (widget.order['total_amount'] as num?)?.toDouble() ?? 0;
    final subtotal = (widget.order['subtotal'] as num?)?.toDouble() ?? total;
    final deliveryFee =
        (widget.order['delivery_fee'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '#${_shortOrderId(orderId)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
      ),
    );
  }

  Widget _buildBody({
    required double subtotal,
    required double deliveryFee,
    required double total,
  }) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildStatusCard(),
        if (widget.order['fulfillment_type']?.toString().toLowerCase() ==
            'pickup')
          _buildPickupPaymentCard(),
        const SizedBox(height: 24),
        const Text(
          'Order Items',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No order items found.'),
            ),
          )
        else
          ..._items.map((item) => _buildItemCard(item)),
        const SizedBox(height: 24),
        _buildSummaryCard(
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          total: total,
        ),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildPickupPaymentCard() {
    final state = _pickupPaymentState ??
        widget.order['pickup_downpayment_status']?.toString() ??
        'pending';
    final amount =
        (widget.order['pickup_downpayment_amount'] as num?)?.toDouble() ?? 0;
    final submitted = state == 'receipt_submitted';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Downpayment: ₱${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Payment: ${_displayStatus(state)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_receiptUrl != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showReceipt = !_showReceipt),
                  icon: Icon(
                    _showReceipt
                        ? Icons.visibility_off_rounded
                        : Icons.receipt_long_rounded,
                  ),
                  label: Text(
                    _showReceipt ? 'Hide Receipt' : 'View Receipt',
                  ),
                ),
              ),
              if (_showReceipt) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _receiptUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('Unable to load receipt.'),
                  ),
                ),
              ],
            ],
            if (submitted) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isUpdating ? null : _rejectPickupReceipt,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isUpdating ? null : _confirmPickupReceipt,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else if (state == 'receipt_rejected')
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Waiting for customer to upload a new receipt.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _statusColor(_status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 13,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _displayStatus(_status),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['item_name']?.toString() ?? 'Item';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final itemSubtotal =
        (item['subtotal'] as num?)?.toDouble() ?? quantity * unitPrice;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$quantity × ₱${unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₱${itemSubtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required double subtotal,
    required double deliveryFee,
    required double total,
  }) {
    final isPickup =
        widget.order['fulfillment_type']?.toString().toLowerCase() == 'pickup';
    final promoDiscount =
        (widget.order['promo_discount'] as num?)?.toDouble() ?? 0;
    final balance =
        (total - _gcashDownpaymentPaid - _cashPickupPaid)
            .clamp(0, double.infinity)
            .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Subtotal',
              value: '₱${subtotal.toStringAsFixed(2)}',
            ),
            if (promoDiscount > 0) ...[
              const SizedBox(height: 10),
              _SummaryRow(
                label: 'Promo',
                value: '-₱${promoDiscount.toStringAsFixed(2)}',
              ),
            ],
            const SizedBox(height: 10),
            if (isPickup) ...[
              _SummaryRow(
                label: 'GCash Downpayment',
                value: '-₱${_gcashDownpaymentPaid.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 10),
              _SummaryRow(
                label: 'Cash for Pickup',
                value: '-₱${_cashPickupPaid.toStringAsFixed(2)}',
              ),
            ] else ...[
              _SummaryRow(
                label: 'Delivery Fee',
                value: '₱${deliveryFee.toStringAsFixed(2)}',
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            _SummaryRow(
              label: 'Balance',
              value: '₱${balance.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isPickup =
        widget.order['fulfillment_type']?.toString().toLowerCase() == 'pickup';
    if (isPickup) {
      final pickupPaymentState = _pickupPaymentState ??
          widget.order['pickup_downpayment_status']?.toString() ??
          'pending';
      if (pickupPaymentState != 'paid' && _status.toLowerCase() == 'pending') {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waiting for pickup payment receipt approval.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      switch (_status.toLowerCase()) {
        case 'confirmed':
          return SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed:
                  _isUpdating ? null : () => _updateStatus('preparing'),
              icon: const Icon(Icons.restaurant_rounded),
              label: const Text(
                'Preparing',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        case 'preparing':
          return SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isUpdating
                  ? null
                  : () => _updateStatus('ready_to_pick_up'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text(
                'Ready to Pick Up',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        case 'ready':
        case 'ready_to_pick_up':
          if (_pickupFinalPaymentPaid) {
            return SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed:
                    _isUpdating ? null : () => _updateStatus('claimed'),
                icon: const Icon(Icons.done_all_rounded),
                label: const Text(
                  'Claimed',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }
          return SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _recordFinalPickupPayment,
              icon: const Icon(Icons.payments_outlined),
              label: const Text(
                'Full Payment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        case 'full_payment':
        case 'payment_due':
          return const SizedBox.shrink();
        case 'claimed':
        case 'picked_up':
        case 'pickedup':
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pickup order completed — Claimed.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    switch (_status.toLowerCase()) {
      case 'pending':
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isUpdating
                ? null
                : () => _updateStatus('preparing'),
            icon: _isUpdating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restaurant_rounded),
            label: const Text(
              'Accept & Start Preparing',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      case 'preparing':
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : () => _updateStatus('ready'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text(
              'Mark as Ready',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      case 'ready':
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : () => _updateStatus('delivered'),
            icon: const Icon(Icons.done_all_rounded),
            label: const Text(
              'Mark as Completed',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      case 'completed':
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This order has been completed.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      case 'cancelled':
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This order has been cancelled.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PickupPaymentInput {
  final double amount;
  final String? reference;
  final String paymentMethod;

  const _PickupPaymentInput({
    required this.amount,
    required this.reference,
    required this.paymentMethod,
  });
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: isTotal
                  ? HalalFoodTheme.textPrimary
                  : HalalFoodTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 13,
            fontWeight: FontWeight.w800,
            color: isTotal
                ? HalalFoodTheme.primaryGreen
                : HalalFoodTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
