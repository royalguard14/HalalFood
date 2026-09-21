import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/distance_utils.dart';
import '../../address/data/address_model.dart';
import '../../address/data/address_repository.dart';
import '../../cart/data/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../home/data/restaurant_model.dart';
import '../../home/data/restaurant_repository.dart';
import '../data/order_repository.dart';
import '../data/promo_code_repository.dart';

class CheckoutScreen extends StatefulWidget {
  final CartProvider cart;

  const CheckoutScreen({
    super.key,
    required this.cart,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AddressRepository _addressRepository =
      AddressRepository();

  final OrderRepository _orderRepository =
      OrderRepository();

  final RestaurantRepository _restaurantRepository =
      RestaurantRepository();

  final PromoCodeRepository _promoCodeRepository =
      PromoCodeRepository();

  late Future<List<Address>> _addressesFuture;

  Address? _selectedAddress;
  Restaurant? _restaurant;

  // Customer must explicitly choose Pick-up or Delivery.
  String? _fulfillmentType;

  double? _deliveryDistanceKm;
  double? _deliveryFee;
  double _pickupDownpaymentPercent = 50.0;

  List<PromoCode> _availablePromos = const [];
  PromoCode? _selectedPromo;
  bool _isLoadingPromos = false;

  bool _isCalculatingDelivery = false;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();

    _addressesFuture =
        _addressRepository.getAddresses();

    _loadRestaurant();
    _loadPickupDownpaymentPercent();
    _loadPromos();
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  void _reloadAddresses() {
    setState(() {
      _addressesFuture =
          _addressRepository.getAddresses();
    });
  }

  void _selectDefaultAddress(
    List<Address> addresses,
  ) {
    if (_selectedAddress != null) {
      return;
    }

    if (addresses.isEmpty) {      return;
    }

    final defaultAddress =
        addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => addresses.first,
    );

    _selectedAddress = defaultAddress;    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (mounted) {
        _calculateDelivery();
      }
    });
  }

  void _selectAddress(Address address) {
    if (_isPlacingOrder) {
      return;
    }

    setState(() {
      _selectedAddress = address;
      _deliveryDistanceKm = null;
      _deliveryFee = null;
    });

    if (_fulfillmentType == 'delivery') {
      _calculateDelivery();
    }
  }

  void _selectFulfillment(String? value) {
    if (value == null) return;
    if (_isPlacingOrder || _fulfillmentType == value) return;

    setState(() {
      _fulfillmentType = value;
      _selectedAddress = null;
      _deliveryDistanceKm = null;
      _deliveryFee = null;
    });

    if (value == 'delivery') {
      _addressesFuture.then((addresses) {
        if (!mounted || _fulfillmentType != 'delivery') return;
        _selectDefaultAddress(addresses);
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _loadPickupDownpaymentPercent() async {
    try {
      final value = await _orderRepository.getPickupDownpaymentPercent();
      if (!mounted) return;
      setState(() => _pickupDownpaymentPercent = value);
    } catch (_) {
      // Keep the database default of 50% if the setting cannot be loaded.
    }
  }

  // ============================================================
  // RESTAURANT
  // ============================================================

  Future<void> _loadRestaurant() async {
    final restaurantId =
        widget.cart.restaurantId;    if (restaurantId == null ||
        restaurantId.trim().isEmpty) {      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isCalculatingDelivery = true;
        });
      }

      final restaurant =
          await _restaurantRepository
              .getRestaurantById(
        restaurantId,
      );      if (!mounted) {
        return;
      }

      setState(() {
        _restaurant = restaurant;
      });

      if (_fulfillmentType == 'delivery') {
        _calculateDelivery();
      } else if (mounted) {
        setState(() => _isCalculatingDelivery = false);
      }
    } catch (e) {      if (!mounted) {
        return;
      }

      setState(() {
        _isCalculatingDelivery = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load restaurant location: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELIVERY CALCULATION
  // ============================================================

  void _calculateDelivery() {
    final address = _selectedAddress;
    final restaurant = _restaurant;    if (address == null ||
        restaurant == null ||
        address.latitude == null ||
        address.longitude == null ||
        restaurant.latitude == null ||
        restaurant.longitude == null) {      if (mounted) {
        setState(() {
          _isCalculatingDelivery = false;
        });
      }      return;
    }

    setState(() {
      _isCalculatingDelivery = true;
    });

    try {
      final distance =
          DistanceUtils.distanceInKm(
        latitude1: address.latitude!,
        longitude1: address.longitude!,
        latitude2: restaurant.latitude!,
        longitude2: restaurant.longitude!,
      );

      final fee =
          DistanceUtils.deliveryFee(
        distanceKm: distance,
      );      if (!mounted) {
        return;
      }

      setState(() {
        _deliveryDistanceKm = distance;
        _deliveryFee = fee;
        _isCalculatingDelivery = false;
      });
    } catch (e) {      if (!mounted) {
        return;
      }

      setState(() {
        _deliveryDistanceKm = null;
        _deliveryFee = null;
        _isCalculatingDelivery = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to calculate delivery fee: $e',
          ),
        ),
      );
    }  }

  // ============================================================
  // PROMOS
  // ============================================================

  Future<void> _loadPromos() async {
    final restaurantId = widget.cart.restaurantId;
    if (restaurantId == null || restaurantId.trim().isEmpty) return;

    setState(() => _isLoadingPromos = true);

    try {
      final promos = await _promoCodeRepository.getAvailablePromos(
        restaurantId: restaurantId,
      );
      if (!mounted) return;
      setState(() {
        _availablePromos = promos;
        if (_selectedPromo != null &&
            !promos.any((promo) => promo.id == _selectedPromo!.id)) {
          _selectedPromo = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load promo codes: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPromos = false);
    }
  }

  void _selectPromo(PromoCode? promo) {
    if (_isPlacingOrder) return;
    setState(() => _selectedPromo = promo);
  }

  double get _promoDiscount {
    final promo = _selectedPromo;
    if (promo == null) return 0;
    return promo.calculateDiscount(widget.cart.total);
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> _placeOrder() async {
    if (_isPlacingOrder) return;

    final fulfillmentType = _fulfillmentType;
    if (fulfillmentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose Pick-up or Delivery first.')),
      );
      return;
    }

    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    final restaurantId = widget.cart.restaurantId;
    if (restaurantId == null || restaurantId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant information is missing.')),
      );
      return;
    }

    final address = _selectedAddress;
    final pickupPayableSubtotal =
        (widget.cart.total - _promoDiscount).clamp(0.0, double.infinity);
    final pickupDownpayment = fulfillmentType == 'pickup'
        ? pickupPayableSubtotal * (_pickupDownpaymentPercent / 100)
        : 0.0;
    final deliveryFee =
        fulfillmentType == 'delivery' ? _deliveryFee : 0.0;

    if (fulfillmentType == 'delivery') {
      if (address == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a delivery address.')),
        );
        return;
      }
      if (address.latitude == null || address.longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected address is missing GPS coordinates.')),
        );
        return;
      }
      if (deliveryFee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery fee is not available yet.')),
        );
        return;
      }
      if (deliveryFee.isInfinite) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This restaurant is outside the current delivery area.')),
        );
        return;
      }
      if (deliveryFee.isNaN) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to calculate delivery fee.')),
        );
        return;
      }
    }

    setState(() => _isPlacingOrder = true);

    try {
      final orderId = await _orderRepository.createOrder(
        address: fulfillmentType == 'delivery' ? address : null,
        restaurantId: restaurantId,
        items: widget.cart.items,
        subtotal: widget.cart.total,
        deliveryFee: deliveryFee ?? 0.0,
        fulfillmentType: fulfillmentType,
        promoCode: _selectedPromo?.code,
        pickupDownpaymentPercent: _pickupDownpaymentPercent,
        pickupDownpaymentAmount: pickupDownpayment,
      );

      if (!mounted) return;

      widget.cart.clearCart();

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  // ============================================================
  // ADDRESS DISPLAY
  // ============================================================

  String _addressTitle(
    Address address,
  ) {
    final label =
        address.label?.trim();

    if (label != null &&
        label.isNotEmpty) {
      return label;
    }

    return 'Delivery Address';
  }

  String _addressDetails(
    Address address,
  ) {
    final parts = <String>[
      address.addressLine,
      if (address.barangay != null &&
          address.barangay!
              .trim()
              .isNotEmpty)
        address.barangay!.trim(),
      if (address.city != null &&
          address.city!
              .trim()
              .isNotEmpty)
        address.city!.trim(),
      if (address.province != null &&
          address.province!
              .trim()
              .isNotEmpty)
        address.province!.trim(),
    ];

    return parts.join(', ');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cart.total;
    final deliveryFee =
        _fulfillmentType == 'delivery' ? (_deliveryFee ?? 0.0) : 0.0;
    final promoDiscount = _promoDiscount;
    final total = subtotal + deliveryFee - promoDiscount;
    final pickupPayableSubtotal = (subtotal - promoDiscount).clamp(0.0, double.infinity);
    final pickupDownpayment = _fulfillmentType == 'pickup'
        ? pickupPayableSubtotal * (_pickupDownpaymentPercent / 100)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Address>>(
          future: _addressesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _AddressErrorView(
                error: snapshot.error.toString(),
                onRetry: _reloadAddresses,
              );
            }

            final addresses = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const Text(
                  'How would you like to receive your order?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Card(
                  child: RadioGroup<String>(
                    groupValue: _fulfillmentType,
                    onChanged: (String? value) {
                      if (!_isPlacingOrder) {
                        _selectFulfillment(value);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          value: 'pickup',
                          title: Text(
                            'Pick-up',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Pick up your order directly from the restaurant.',
                          ),
                          secondary: Icon(Icons.storefront_outlined),
                        ),
                        RadioListTile<String>(
                          value: 'delivery',
                          title: Text(
                            'Delivery',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Have your order delivered to your saved address.',
                          ),
                          secondary: Icon(Icons.delivery_dining_outlined),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'Your Order',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _OrderItemsCard(items: widget.cart.items),

                if (_fulfillmentType == 'delivery') ...[
                  const SizedBox(height: 26),
                  const Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Where should we deliver your order?',
                    style: TextStyle(
                      fontSize: 13,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (addresses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_off_outlined),
                            const SizedBox(height: 10),
                            const Text(
                              'No delivery address',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please add a delivery address before placing a delivery order.',
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ...addresses.map((address) {
                      final selected = _selectedAddress?.id == address.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AddressOption(
                          address: address,
                          selected: selected,
                          title: _addressTitle(address),
                          details: _addressDetails(address),
                          onTap: () => _selectAddress(address),
                        ),
                      );
                    }),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isPlacingOrder ? null : _reloadAddresses,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh Addresses'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),
                  const Text(
                    'Delivery',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _DeliveryInfoCard(
                    distanceKm: _deliveryDistanceKm,
                    deliveryFee: _deliveryFee,
                    isCalculating: _isCalculatingDelivery,
                    restaurant: _restaurant,
                    address: _selectedAddress,
                  ),
                ],

                if (_fulfillmentType != null) ...[
                  const SizedBox(height: 26),
                  _PromoSection(
                    promos: _availablePromos,
                    selectedPromo: _selectedPromo,
                    promoDiscount: promoDiscount,
                    subtotal: subtotal,
                    isLoading: _isLoadingPromos,
                    onSelect: _selectPromo,
                    onRefresh: _loadPromos,
                  ),
                ],

                if (_fulfillmentType == 'pickup') ...[
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_clock_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup downpayment: ${_pickupDownpaymentPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Required before the restaurant processes a pickup order. Amount: ₱${pickupDownpayment.toStringAsFixed(2)}. This downpayment is non-refundable under the pickup no-show rule.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: HalalFoodTheme.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_fulfillmentType != null) ...[
                  const SizedBox(height: 26),
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _OrderSummaryCard(
                    subtotal: subtotal,
                    deliveryFee: deliveryFee,
                    promoDiscount: promoDiscount,
                    total: total,
                    showDeliveryFee: _fulfillmentType == 'delivery',
                    isCalculating: _fulfillmentType == 'delivery' &&
                        (_isCalculatingDelivery || _deliveryFee == null),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPlacingOrder ||
                              (_fulfillmentType == 'delivery' &&
                                  (_isCalculatingDelivery ||
                                      _deliveryFee == null ||
                                      _deliveryFee!.isInfinite ||
                                      _deliveryFee!.isNaN ||
                                      _selectedAddress == null))
                          ? null
                          : _placeOrder,
                      child: _isPlacingOrder
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Place Order • ₱${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

}

// ============================================================
// PROMO SECTION
// ============================================================

class _PromoSection extends StatelessWidget {
  final List<PromoCode> promos;
  final PromoCode? selectedPromo;
  final double promoDiscount;
  final double subtotal;
  final bool isLoading;
  final ValueChanged<PromoCode?> onSelect;
  final VoidCallback onRefresh;

  const _PromoSection({
    required this.promos,
    required this.selectedPromo,
    required this.promoDiscount,
    required this.subtotal,
    required this.isLoading,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedPromo;
    final selectedMeetsMinimum =
        selected == null || subtotal >= selected.minimumOrder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Promo / Coupon',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose an available promo for this order.',
          style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (promos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('No available promo codes for this restaurant.'),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: DropdownButtonFormField<String>(
                initialValue: selected?.id ?? '__none__',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Promo / Coupon',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '__none__',
                    child: Text('No promo'),
                  ),
                  ...promos.map((promo) {
                    final meetsMinimum = subtotal >= promo.minimumOrder;
                    return DropdownMenuItem<String>(
                      value: promo.id,
                      enabled: meetsMinimum,
                      child: Text(
                        '${promo.title} • ${promo.code} • ${promo.discountLabel}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (id) {
                  if (id == '__none__') {
                    onSelect(null);
                    return;
                  }

                  final promo = promos.firstWhere(
                    (item) => item.id == id,
                  );

                  if (subtotal < promo.minimumOrder) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Minimum order for ${promo.code} is '
                          '₱${promo.minimumOrder.toStringAsFixed(2)}.',
                        ),
                      ),
                    );
                    return;
                  }

                  onSelect(promo);
                },
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          size: 20,
                          color: HalalFoodTheme.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selected.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          selected.discountLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: HalalFoodTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selected.code,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (selected.description != null &&
                        selected.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        selected.description!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      selected.minimumOrder > 0
                          ? 'Minimum order: ₱${selected.minimumOrder.toStringAsFixed(2)}'
                          : 'No minimum order',
                      style: TextStyle(
                        fontSize: 12,
                        color: selectedMeetsMinimum
                            ? HalalFoodTheme.textSecondary
                            : Colors.redAccent,
                      ),
                    ),
                    if (promoDiscount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Discount: -₱${promoDiscount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: HalalFoodTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ============================================================
// ADDRESS OPTION
// ============================================================

class _AddressOption
    extends StatelessWidget {
  final Address address;
  final bool selected;
  final String title;
  final String details;
  final VoidCallback onTap;

  const _AddressOption({
    required this.address,
    required this.selected,
    required this.title,
    required this.details,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? HalalFoodTheme
                    .primaryGreen
                : Theme.of(context)
                    .dividerColor,
            width:
                selected ? 2 : 1,
          ),
          color: selected
              ? HalalFoodTheme
                  .primaryGreen
                  .withValues(
                  alpha: 0.04,
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons
                      .radio_button_checked
                  : Icons
                      .radio_button_off,
              color: selected
                  ? HalalFoodTheme
                      .primaryGreen
                  : HalalFoodTheme
                      .textSecondary,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              const TextStyle(
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ),

                      if (address
                          .isDefault)
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                8,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                HalalFoodTheme
                                    .primaryGreen
                                    .withValues(
                              alpha:
                                  0.10,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                          ),
                          child:
                              const Text(
                            'Default',
                            style:
                                TextStyle(
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  HalalFoodTheme
                                      .primaryGreen,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    address.recipientName,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  if (address.phone !=
                          null &&
                      address.phone!
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top: 3,
                      ),
                      child: Text(
                        address.phone!
                            .trim(),
                        style:
                            const TextStyle(
                          fontSize:
                              12,
                          color:
                              HalalFoodTheme
                                  .textSecondary,
                        ),
                      ),
                    ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    details,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DELIVERY INFO
// ============================================================

class _DeliveryInfoCard
    extends StatelessWidget {
  final double? distanceKm;
  final double? deliveryFee;
  final bool isCalculating;
  final Restaurant? restaurant;
  final Address? address;

  const _DeliveryInfoCard({
    required this.distanceKm,
    required this.deliveryFee,
    required this.isCalculating,
    required this.restaurant,
    required this.address,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isCalculating) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              const Expanded(
                child: Text(
                  'Calculating delivery fee...',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (restaurant == null) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons
                    .restaurant_outlined,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restaurant location is unavailable.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (restaurant!.latitude ==
            null ||
        restaurant!.longitude ==
            null) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons
                    .location_off_outlined,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restaurant coordinates are unavailable.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (address == null) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons
                    .location_off_outlined,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select a delivery address.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (address!.latitude ==
            null ||
        address!.longitude ==
            null) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons
                    .location_off_outlined,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delivery location coordinates are unavailable.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (distanceKm == null ||
        deliveryFee == null) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(18),
          child: Text(
            'Unable to calculate delivery fee.',
          ),
        ),
      );
    }

    if (deliveryFee!.isInfinite) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons
                    .delivery_dining_outlined,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  'This restaurant is '
                  '${distanceKm!.toStringAsFixed(2)} km away and is outside the current delivery area.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .delivery_dining_outlined,
                    color:
                        HalalFoodTheme
                            .primaryGreen,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Expanded(
                  child: Text(
                    'Delivery Fee',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                Text(
                  '₱${deliveryFee!.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            const Divider(
              height: 1,
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 20,
                ),

                const SizedBox(
                  width: 8,
                ),

                const Text(
                  'Distance',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const Spacer(),

                Text(
                  '${distanceKm!.toStringAsFixed(2)} km',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
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

// ============================================================
// ORDER ITEMS
// ============================================================

class _OrderItemsCard
    extends StatelessWidget {
  final List<CartItem> items;

  const _OrderItemsCard({
    required this.items,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            ...items.map(
              (cartItem) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                          color:
                              HalalFoodTheme
                                  .primaryGreen
                                  .withValues(
                            alpha: 0.08,
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .restaurant_outlined,
                          color:
                              HalalFoodTheme
                                  .primaryGreen,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              cartItem
                                  .item
                                  .name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              '${cartItem.quantity} × ₱${cartItem.item.price.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                color:
                                    HalalFoodTheme
                                        .textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Text(
                        '₱${cartItem.subtotal.toStringAsFixed(2)}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ORDER SUMMARY
// ============================================================

class _OrderSummaryCard
    extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double promoDiscount;
  final double total;
  final bool showDeliveryFee;
  final bool isCalculating;

  const _OrderSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.promoDiscount,
    required this.total,
    required this.showDeliveryFee,
    required this.isCalculating,
  });

  Widget _row(
    String label,
    double value, {
    bool totalRow = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize:
                    totalRow
                        ? 16
                        : 14,
                fontWeight:
                    totalRow
                        ? FontWeight.w800
                        : FontWeight.w500,
              ),
            ),
          ),

          Text(
            '₱${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize:
                  totalRow
                      ? 17
                      : 14,
              fontWeight:
                  totalRow
                      ? FontWeight.w800
                      : FontWeight.w600,
              color: totalRow
                  ? HalalFoodTheme
                      .primaryGreen
                  : HalalFoodTheme
                      .textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(
              'Subtotal',
              subtotal,
            ),

            if (showDeliveryFee && isCalculating)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delivery Fee',
                        style:
                            TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              )
            else if (showDeliveryFee)
              _row(
                'Delivery Fee',
                deliveryFee,
              ),

            if (promoDiscount > 0)
              _row(
                'Promo Discount',
                -promoDiscount,
              ),

            const Divider(
              height: 18,
            ),

            _row(
              'Total',
              total,
              totalRow: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NO ADDRESS
// ============================================================

class _NoAddressView
    extends StatelessWidget {
  final VoidCallback onAddAddress;

  const _NoAddressView({
    required this.onAddAddress,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .location_off_outlined,
              size: 60,
              color:
                  HalalFoodTheme
                      .primaryGreen,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'No delivery address',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Please add a delivery address before placing your order.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
                  onAddAddress,
              icon: const Icon(
                Icons
                    .add_location_alt_outlined,
              ),
              label:
                  const Text(
                'Add Address',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADDRESS ERROR
// ============================================================

class _AddressErrorView
    extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _AddressErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 52,
              color: Colors.redAccent,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Unable to load addresses.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              error,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 13,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            ElevatedButton(
              onPressed: onRetry,
              child:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ORDER SUCCESS
// ============================================================

class OrderSuccessScreen
    extends StatelessWidget {
  final String orderId;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        title: const Text(
          'Order Confirmed',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      HalalFoodTheme
                          .primaryGreen
                          .withValues(
                    alpha: 0.10,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .check_circle_rounded,
                  size: 58,
                  color:
                      HalalFoodTheme
                          .primaryGreen,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'Order Placed!',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Your order has been successfully placed.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color:
                      HalalFoodTheme
                          .textSecondary,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              Text(
                'Order ID: $orderId',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      HalalFoodTheme
                          .textSecondary,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).popUntil(
                      (route) =>
                          route.isFirst,
                    );
                  },
                  child:
                      const Text(
                    'Back to Home',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}