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

class CheckoutScreen extends StatefulWidget {
  final CartProvider cart;

  const CheckoutScreen({super.key, required this.cart});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AddressRepository _addressRepository = AddressRepository();

  final OrderRepository _orderRepository = OrderRepository();

  final RestaurantRepository _restaurantRepository = RestaurantRepository();

  late Future<List<Address>> _addressesFuture;

  Address? _selectedAddress;

  Restaurant? _restaurant;

  double? _deliveryDistanceKm;
  double? _deliveryFee;

  bool _isCalculatingDelivery = false;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();

    _loadAddresses();
    _loadRestaurant();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _addressesFuture = _addressRepository.getAddresses();
    });
  }

  Future<void> _loadRestaurant() async {
    final restaurantId = widget.cart.restaurantId;

    if (restaurantId == null || restaurantId.trim().isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCalculatingDelivery = true;
      });
    }

    try {
      final restaurant = await _restaurantRepository.getRestaurantById(
        restaurantId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _restaurant = restaurant;
      });

      _calculateDelivery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load restaurant location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingDelivery = false;
        });
      }
    }
  }

  void _calculateDelivery() {
    final address = _selectedAddress;
    final restaurant = _restaurant;

    print('========== DELIVERY DEBUG ==========');
    print('Selected Address: $address');
    print('Customer Latitude: ${address?.latitude}');
    print('Customer Longitude: ${address?.longitude}');
    print('Restaurant: ${restaurant?.name}');
    print('Restaurant Latitude: ${restaurant?.latitude}');
    print('Restaurant Longitude: ${restaurant?.longitude}');

    if (address == null ||
        restaurant == null ||
        address.latitude == null ||
        address.longitude == null ||
        restaurant.latitude == null ||
        restaurant.longitude == null) {
      print('DELIVERY CALCULATION STOPPED: Missing coordinates');
      print('===================================');
      return;
    }

    final distance = DistanceUtils.distanceInKm(
      latitude1: address.latitude!,
      longitude1: address.longitude!,
      latitude2: restaurant.latitude!,
      longitude2: restaurant.longitude!,
    );

    final fee = DistanceUtils.deliveryFee(distanceKm: distance);

    print('Distance: ${distance.toStringAsFixed(2)} km');
    print('Delivery Fee: ₱${fee.toStringAsFixed(2)}');
    print('===================================');

    if (!mounted) {
      return;
    }

    setState(() {
      _deliveryDistanceKm = distance;
      _deliveryFee = fee;
    });
  }

  void _selectDefaultAddress(List<Address> addresses) {
    if (_selectedAddress != null) {
      return;
    }

    if (addresses.isEmpty) {
      return;
    }

    final defaultAddress = addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => addresses.first,
    );

    _selectedAddress = defaultAddress;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _calculateDelivery();
    });
  }

  Future<void> _placeOrder() async {
    if (_isPlacingOrder) {
      return;
    }

    final address = _selectedAddress;

    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address.')),
      );
      return;
    }

    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }

    final restaurantId = widget.cart.restaurantId;

    if (restaurantId == null || restaurantId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant information is missing.')),
      );
      return;
    }

    final deliveryFee = _deliveryFee;

    if (deliveryFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee is not available yet.')),
      );
      return;
    }

    if (deliveryFee.isInfinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This restaurant is outside the current delivery area.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final orderId = await _orderRepository.createOrder(
        address: address,
        restaurantId: restaurantId,
        items: widget.cart.items,
        subtotal: widget.cart.total,
        deliveryFee: deliveryFee,
      );

      if (!mounted) {
        return;
      }

      widget.cart.clearCart();

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to place order: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  String _addressTitle(Address address) {
    final label = address.label?.trim();

    if (label != null && label.isNotEmpty) {
      return label;
    }

    return 'Delivery Address';
  }

  String _addressDetails(Address address) {
    final parts = <String>[
      address.addressLine,
      if (address.barangay != null && address.barangay!.trim().isNotEmpty)
        address.barangay!.trim(),
      if (address.city != null && address.city!.trim().isNotEmpty)
        address.city!.trim(),
      if (address.province != null && address.province!.trim().isNotEmpty)
        address.province!.trim(),
    ];

    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cart.total;

    final deliveryFee = _deliveryFee ?? 0.0;

    final total = subtotal + deliveryFee;

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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load addresses.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _addressesFuture = _addressRepository
                                .getAddresses();
                          });
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final addresses = snapshot.data ?? [];

            _selectDefaultAddress(addresses);

            if (addresses.isEmpty) {
              return _NoAddressView(
                onAddAddress: () {
                  Navigator.of(context).pop();
                },
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 10),

                ...addresses.map((address) {
                  final selected = _selectedAddress?.id == address.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AddressOption(
                      address: address,
                      selected: selected,
                      title: _addressTitle(address),
                      details: _addressDetails(address),
                      onTap: () {
                        setState(() {
                          _selectedAddress = address;
                          _isCalculatingDelivery = true;
                        });

                        _calculateDelivery();

                        if (mounted) {
                          setState(() {
                            _isCalculatingDelivery = false;
                          });
                        }
                      },
                    ),
                  );
                }),

                const SizedBox(height: 24),

                const Text(
                  'Your Order',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 12),

                _OrderItemsCard(items: widget.cart.items),

                const SizedBox(height: 24),

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

                const SizedBox(height: 24),

                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 12),

                _OrderSummaryCard(
                  subtotal: subtotal,
                  deliveryFee: deliveryFee,
                  total: total,
                  isCalculating: _isCalculatingDelivery || _deliveryFee == null,
                ),

                const SizedBox(height: 28),

                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isPlacingOrder ||
                            _isCalculatingDelivery ||
                            _deliveryFee == null ||
                            _deliveryFee!.isInfinite
                        ? null
                        : _placeOrder,
                    child: _isPlacingOrder
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
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
            );
          },
        ),
      ),
    );
  }
}

class _AddressOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? HalalFoodTheme.primaryGreen
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? HalalFoodTheme.primaryGreen
                  : HalalFoodTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (address.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HalalFoodTheme.primaryGreen.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: HalalFoodTheme.primaryGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.recipientName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (address.phone != null && address.phone!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        address.phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: HalalFoodTheme.textSecondary,
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

class _DeliveryInfoCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isCalculating) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Calculating delivery fee...',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
          padding: EdgeInsets.all(18),
          child: Text('Restaurant location is unavailable.'),
        ),
      );
    }

    final restaurantLatitude = restaurant!.latitude;

    final restaurantLongitude = restaurant!.longitude;

    if (restaurantLatitude == null || restaurantLongitude == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.restaurant_outlined),
              SizedBox(width: 12),
              Expanded(child: Text('Restaurant coordinates are unavailable.')),
            ],
          ),
        ),
      );
    }

    if (address == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined),
              SizedBox(width: 12),
              Expanded(child: Text('Please select a delivery address.')),
            ],
          ),
        ),
      );
    }

    final addressLatitude = address!.latitude;

    final addressLongitude = address!.longitude;

    if (addressLatitude == null || addressLongitude == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text('Delivery location coordinates are unavailable.'),
              ),
            ],
          ),
        ),
      );
    }

    if (distanceKm == null || deliveryFee == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Unable to calculate delivery fee.'),
        ),
      );
    }

    if (deliveryFee!.isInfinite) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.delivery_dining_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This restaurant is ${distanceKm!.toStringAsFixed(2)} km away and is outside the current delivery area.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_outlined,
                    color: HalalFoodTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Delivery Fee',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '₱${deliveryFee!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Distance',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${distanceKm!.toStringAsFixed(2)} km',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  final List<CartItem> items;

  const _OrderItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...items.map((cartItem) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: HalalFoodTheme.primaryGreen.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      child: const Icon(
                        Icons.restaurant_outlined,
                        color: HalalFoodTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cartItem.item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${cartItem.quantity} × ₱${cartItem.item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HalalFoodTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '₱${cartItem.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double total;
  final bool isCalculating;

  const _OrderSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.isCalculating,
  });

  Widget _row(String label, double value, {bool totalRow = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: totalRow ? 16 : 14,
                fontWeight: totalRow ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₱${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: totalRow ? 17 : 14,
              fontWeight: totalRow ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Subtotal', subtotal),
            if (isCalculating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delivery Fee',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
              )
            else
              _row('Delivery Fee', deliveryFee),
            const Divider(height: 18),
            _row('Total', total, totalRow: true),
          ],
        ),
      ),
    );
  }
}

class _NoAddressView extends StatelessWidget {
  final VoidCallback onAddAddress;

  const _NoAddressView({required this.onAddAddress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 60,
              color: HalalFoodTheme.primaryGreen,
            ),
            const SizedBox(height: 18),
            const Text(
              'No delivery address',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add a delivery address before placing your order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAddAddress,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Address'),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Order Confirmed',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 58,
                  color: HalalFoodTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Placed!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your order has been successfully placed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Order ID: $orderId',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
