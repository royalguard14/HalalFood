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

class _OwnerOrderDetailsScreenState
    extends State<OwnerOrderDetailsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _items = [];

  bool _isLoading = true;
  bool _isUpdating = false;
  String? _receiptUrl;
  String? _pickupPaymentState;
  bool _showReceipt = false;
  bool _pickupFinalPaymentPaid = false;

  String? _error;

  late String _status;

  @override
  void initState() {
    super.initState();

    _status =
        widget.order['status']?.toString() ?? 'pending';
    _pickupPaymentState =
        widget.order['pickup_downpayment_status']?.toString() ?? 'pending';
    _pickupFinalPaymentPaid =
        widget.order['payment_status']?.toString() == 'paid';

    _loadOrderItems();
    _loadPickupReceipt();
  }

  Future<void> _loadPickupReceipt() async {
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) return;

      final freshOrder = await _supabase
          .from('orders')
          .select('pickup_receipt_path,pickup_receipt_submitted_at,pickup_downpayment_status,payment_status')
          .eq('id', orderId)
          .maybeSingle();

      final freshState =
          freshOrder?['pickup_downpayment_status']?.toString();
      final freshPaymentStatus =
          freshOrder?['payment_status']?.toString();
      if (mounted && freshState != null && freshState.isNotEmpty) {
        setState(() {
          _pickupPaymentState = freshState;
          _pickupFinalPaymentPaid = freshPaymentStatus == 'paid';
        });
      }

      final path = freshOrder?['pickup_receipt_path']?.toString().trim();
      if (path == null || path.isEmpty) {
        debugPrint('OWNER RECEIPT: no pickup_receipt_path for order $orderId');
        return;
      }

      final url = await _supabase.storage
          .from('payment-receipts')
          .createSignedUrl(path, 900);

      if (mounted) {
        setState(() => _receiptUrl = url);
      }
    } catch (e) {
      debugPrint('OWNER RECEIPT ERROR: $e');
    }
  }

  Future<void> _confirmPickupReceipt() async {
    await _updatePickupPayment('paid');
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _updatePickupPayment('receipt_rejected', reason: reason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Future<void> _updatePickupPayment(String state, {String? reason}) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final orderId = widget.order['id']?.toString();
      if (orderId == null || orderId.isEmpty) throw Exception('Invalid order ID.');
      final data = <String, dynamic>{'pickup_downpayment_status': state};
      if (state == 'paid') {
        data['payment_status'] = 'paid';
        data['status'] = 'preparing';
      }
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
        _status = state == 'paid'
            ? 'preparing'
            : (widget.order['status']?.toString() ?? _status);
        if (state == 'receipt_rejected') {
          _receiptUrl = null;
          _showReceipt = false;
        }
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state == 'paid' ? 'Receipt accepted. The order can now be processed.' : 'Receipt rejected. Customer can upload another receipt.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update payment: $e')));
      }
    }
  }

  Future<void> _loadOrderItems() async {
    try {
      final orderId =
          widget.order['id']?.toString();

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
            .map(
              (item) =>
                  Map<String, dynamic>.from(item),
            )
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

  Future<void> _updateStatus(
    String newStatus,
  ) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final orderId =
          widget.order['id']?.toString();

      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID.');
      }

      final isPickup =
          widget.order['fulfillment_type']?.toString().toLowerCase() == 'pickup';

      if (isPickup && newStatus == 'ready_to_pick_up') {
        // order_status has no custom pickup value; `ready` is the database state.
        newStatus = 'ready';
      } else if (isPickup && newStatus == 'full_payment') {
        // Final pickup payment is represented by payment_status, not order_status.
        await _supabase
            .from('orders')
            .update({'payment_status': 'paid'})
            .eq('id', orderId);
        if (!mounted) return;
        setState(() {
          _pickupFinalPaymentPaid = true;
          _isUpdating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Final payment marked as paid. Order is ready to be claimed.')),
        );
        return;
      } else if (isPickup && newStatus == 'claimed') {
        // `delivered` is the terminal order_status used for completed pickup orders.
        newStatus = 'delivered';
      }

      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      if (!mounted) return;

      setState(() {
        _status = newStatus;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to ${_displayStatus(newStatus)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update order: $e',
          ),
        ),
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
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}'
                      '${word.substring(1)}',
            )
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

  String _shortOrderId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    final orderId =
        widget.order['id']?.toString() ?? '';

    final total =
        (widget.order['total_amount'] as num?)
                ?.toDouble() ??
            0;

    final subtotal =
        (widget.order['subtotal'] as num?)
                ?.toDouble() ??
            0;

    final deliveryFee =
        (widget.order['delivery_fee'] as num?)
                ?.toDouble() ??
            0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '#${_shortOrderId(orderId)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        _buildStatusCard(),

        if (widget.order['fulfillment_type']?.toString() == 'pickup') _buildPickupPaymentCard(),

        const SizedBox(height: 24),

        const Text(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        if (_items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No order items found.',
              ),
            ),
          )
        else
          ..._items.map(
            (item) => _buildItemCard(item),
          ),

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
    final amount = (widget.order['pickup_downpayment_amount'] as num?)?.toDouble() ?? 0;
    final submitted = state == 'receipt_submitted';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pickup Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Downpayment: ₱'+amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Payment: '+_displayStatus(state), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_receiptUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showReceipt = !_showReceipt),
                icon: Icon(_showReceipt ? Icons.visibility_off_rounded : Icons.receipt_long_rounded),
                label: Text(_showReceipt ? 'Hide Receipt' : 'View Receipt'),
              ),
            ),
            if (_showReceipt) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _receiptUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('Unable to load receipt.'),
                ),
              ),
            ],
          ],
          if (submitted) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _isUpdating ? null : _rejectPickupReceipt, icon: const Icon(Icons.close_rounded), label: const Text('Reject'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: _isUpdating ? null : _confirmPickupReceipt, icon: const Icon(Icons.check_rounded), label: const Text('Accept'))),
            ]),
          ] else if (state == 'receipt_rejected')
            const Padding(padding: EdgeInsets.only(top: 10), child: Text('Waiting for customer to upload a new receipt.')),
        ]),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _statusColor(_status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 13,
                color:
                    HalalFoodTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color:
                    color.withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                _displayStatus(_status),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
  ) {
    final name =
        item['item_name']?.toString() ??
            'Item';

    final quantity =
        (item['quantity'] as num?)
                ?.toInt() ??
            0;

    final unitPrice =
        (item['unit_price'] as num?)
                ?.toDouble() ??
            0;

    final itemSubtotal =
        (item['subtotal'] as num?)
                ?.toDouble() ??
            quantity * unitPrice;

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
                color:
                    HalalFoodTheme.primaryGreen
                        .withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color:
                    HalalFoodTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$quantity × ₱${unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₱${itemSubtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Subtotal',
              value:
                  '₱${subtotal.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Delivery Fee',
              value:
                  '₱${deliveryFee.toStringAsFixed(2)}',
            ),
            const Padding(
              padding:
                  EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            _SummaryRow(
              label: 'Total',
              value:
                  '₱${total.toStringAsFixed(2)}',
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
      final pickupPaymentState =
          _pickupPaymentState ??
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
                onPressed: _isUpdating
                    ? null
                    : () => _updateStatus('claimed'),
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
              onPressed: _isUpdating
                  ? null
                  : () => _updateStatus('full_payment'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text(
                'Payment Complete',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );

        case 'full_payment':
        case 'payment_due':
          return SizedBox.shrink();

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
                : () => _updateStatus(
                      'preparing',
                    ),
            icon: _isUpdating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.restaurant_rounded,
                  ),
            label: const Text(
              'Accept & Start Preparing',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
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
                : () => _updateStatus(
                      'ready',
                    ),
            icon: const Icon(
              Icons.check_circle_outline_rounded,
            ),
            label: const Text(
              'Mark as Ready',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

      case 'ready':
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isUpdating
                ? null
                : () => _updateStatus(
                      'delivered',
                    ),
            icon: const Icon(
              Icons.done_all_rounded,
            ),
            label: const Text(
              'Mark as Completed',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

      case 'completed':
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This order has been completed.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
                Icon(
                  Icons.cancel_rounded,
                  color: Colors.red,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This order has been cancelled.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
              fontWeight: isTotal
                  ? FontWeight.w800
                  : FontWeight.w500,
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
