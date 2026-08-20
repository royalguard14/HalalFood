
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../address/data/address_model.dart';
import '../../address/data/address_repository.dart';
import '../../address/screens/add_address_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../data/order_repository.dart';

class CheckoutScreen extends StatefulWidget {
  final CartProvider cart;

  const CheckoutScreen({
    super.key,
    required this.cart,
  });

  @override
  State<CheckoutScreen> createState() =>
      _CheckoutScreenState();
}

class _CheckoutScreenState
    extends State<CheckoutScreen> {
  final _addressRepository = AddressRepository();
  final _orderRepository = OrderRepository();

  List<Address> _addresses = [];
  Address? _selectedAddress;

  bool _isLoadingAddresses = true;
  bool _isPlacingOrder = false;

  static const double _deliveryFee = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses =
          await _addressRepository.getAddresses();

      if (!mounted) return;

      Address? selected;

      if (addresses.isNotEmpty) {
        selected = addresses.firstWhere(
          (address) => address.isDefault,
          orElse: () => addresses.first,
        );
      }

      setState(() {
        _addresses = addresses;
        _selectedAddress = selected;
        _isLoadingAddresses = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingAddresses = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load addresses: $e',
          ),
        ),
      );
    }
  }

  Future<void> _addAddress() async {
    final result =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddAddressScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadAddresses();
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a delivery address.',
          ),
        ),
      );
      return;
    }

    if (widget.cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your cart is empty.',
          ),
        ),
      );
      return;
    }

    final restaurantId =
        widget.cart.restaurantId;

    if (restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to determine the restaurant.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final orderId =
          await _orderRepository.createOrder(
        restaurantId: restaurantId,
        deliveryAddressId:
            _selectedAddress!.id,
        items: widget.cart.items,
        subtotal: widget.cart.total,
        deliveryFee: _deliveryFee,
      );

      if (!mounted) return;

      widget.cart.clearCart();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Order Placed!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'Your order has been placed successfully.\n\n'
              'Order ID: $orderId',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Done',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to place order: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32,
        ),
        children: [
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Where should we deliver your order?',
            style: TextStyle(
              fontSize: 13,
              color: HalalFoodTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 16),

          _buildAddressSection(),

          const SizedBox(height: 28),

          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          ...cart.items.map(
            (cartItem) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    title: Text(
                      cartItem.item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Qty: ${cartItem.quantity} × '
                      '₱${cartItem.item.price.toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      '₱${cartItem.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          _buildSummary(cart),

          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isPlacingOrder
                      ? null
                      : _placeOrder,
              icon: _isPlacingOrder
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                    ),
              label: Text(
                _isPlacingOrder
                    ? 'Placing Order...'
                    : 'Place Order',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    if (_isLoadingAddresses) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_addresses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 36,
                color: HalalFoodTheme.primaryGreen,
              ),

              const SizedBox(height: 10),

              const Text(
                'No delivery address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Please add a delivery address before placing your order.',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      HalalFoodTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addAddress,
                  icon: const Icon(
                    Icons.add_location_alt_outlined,
                  ),
                  label: const Text(
                    'Add Delivery Address',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
RadioGroup<String>(
  groupValue: _selectedAddress?.id,
  onChanged: (value) {
    if (_isPlacingOrder || value == null) {
      return;
    }

    final selected =
        _addresses.firstWhere(
      (address) => address.id == value,
    );

    setState(() {
      _selectedAddress = selected;
    });
  },
            child: Column(
              children: [
                ..._addresses.map(
                  (address) {
                    final isSelected =
                        _selectedAddress?.id ==
                            address.id;

                    return RadioListTile<String>(
                      value: address.id,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              address.label
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? address.label!
                                  : 'Delivery Address',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),

                          if (address.isDefault)
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    HalalFoodTheme
                                        .primaryGreen
                                        .withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      HalalFoodTheme
                                          .primaryGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 5,
                        ),
                        child: Text(
                          '${address.recipientName}\n'
                          '${address.addressLine}'
                          '${address.barangay != null && address.barangay!.trim().isNotEmpty ? ', ${address.barangay!.trim()}' : ''}'
                          '${address.city != null && address.city!.trim().isNotEmpty ? ', ${address.city!.trim()}' : ''}'
                          '${address.province != null && address.province!.trim().isNotEmpty ? ', ${address.province!.trim()}' : ''}'
                          '${address.phone != null && address.phone!.trim().isNotEmpty ? '\n${address.phone!.trim()}' : ''}',
                          style:
                              const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color:
                                HalalFoodTheme
                                    .textSecondary,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      activeColor:
                          HalalFoodTheme
                              .primaryGreen,
                    );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          TextButton.icon(
            onPressed:
                _isPlacingOrder
                    ? null
                    : _loadAddresses,
            icon: const Icon(
              Icons.location_on_outlined,
            ),
            label: const Text(
              'Refresh Addresses',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    CartProvider cart,
  ) {
    final total =
        cart.total + _deliveryFee;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            HalalFoodTheme.primaryGreen
                .withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Subtotal',
            value:
                '₱${cart.total.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 10),

          const _SummaryRow(
            label: 'Delivery Fee',
            value: '₱0.00',
          ),

          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 14,
            ),
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
    );
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
              fontSize:
                  isTotal ? 17 : 14,
              fontWeight:
                  isTotal
                      ? FontWeight.w800
                      : FontWeight.w500,
            ),
          ),
        ),

        Text(
          value,
          style: TextStyle(
            fontSize:
                isTotal ? 19 : 14,
            fontWeight:
                FontWeight.w800,
            color: isTotal
                ? HalalFoodTheme.primaryGreen
                : HalalFoodTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

