import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/distance_utils.dart';
import '../../address/data/address_model.dart';
import '../../address/data/address_repository.dart';
import '../../checkout/screens/checkout_screen.dart';
import '../../home/data/restaurant_model.dart';
import '../../home/data/restaurant_repository.dart';
import '../data/cart_item.dart';
import '../providers/cart_provider.dart';

class CartScreen extends StatefulWidget {
  final CartProvider cart;

  const CartScreen({
    super.key,
    required this.cart,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final AddressRepository _addressRepository =
      AddressRepository();

  final RestaurantRepository _restaurantRepository =
      RestaurantRepository();

  Address? _selectedAddress;
  Restaurant? _restaurant;

  double? _deliveryDistanceKm;
  double? _deliveryFee;

  bool _isCalculatingDelivery = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveryInformation();
  }

  Future<void> _loadDeliveryInformation() async {
    if (widget.cart.items.isEmpty) {
      if (mounted) {
        setState(() {
          _selectedAddress = null;
          _restaurant = null;
          _deliveryDistanceKm = null;
          _deliveryFee = null;
          _isCalculatingDelivery = false;
        });
      }
      return;
    }

    final restaurantId = widget.cart.restaurantId;

    if (restaurantId == null ||
        restaurantId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _deliveryFee = null;
          _deliveryDistanceKm = null;
          _isCalculatingDelivery = false;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isCalculatingDelivery = true;
    });

    try {
      debugPrint(
        '========== CART DELIVERY DEBUG ==========',
      );

      debugPrint(
        'Restaurant ID: $restaurantId',
      );

      // --------------------------------------------------
      // LOAD CUSTOMER ADDRESSES
      // --------------------------------------------------

      final addresses =
          await _addressRepository.getAddresses();

      if (addresses.isEmpty) {
        debugPrint(
          'No customer addresses found.',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _selectedAddress = null;
          _restaurant = null;
          _deliveryDistanceKm = null;
          _deliveryFee = null;
          _isCalculatingDelivery = false;
        });

        return;
      }

      final selectedAddress =
          addresses.firstWhere(
        (address) => address.isDefault,
        orElse: () => addresses.first,
      );

      debugPrint(
        'Customer: ${selectedAddress.recipientName}',
      );

      debugPrint(
        'Customer latitude: ${selectedAddress.latitude}',
      );

      debugPrint(
        'Customer longitude: ${selectedAddress.longitude}',
      );

      // --------------------------------------------------
      // LOAD RESTAURANT
      // --------------------------------------------------

      final restaurant =
          await _restaurantRepository
              .getRestaurantById(
        restaurantId,
      );

      debugPrint(
        'Restaurant: ${restaurant.name}',
      );

      debugPrint(
        'Restaurant latitude: ${restaurant.latitude}',
      );

      debugPrint(
        'Restaurant longitude: ${restaurant.longitude}',
      );

      // --------------------------------------------------
      // CHECK COORDINATES
      // --------------------------------------------------

      if (selectedAddress.latitude == null ||
          selectedAddress.longitude == null ||
          restaurant.latitude == null ||
          restaurant.longitude == null) {
        debugPrint(
          'Missing coordinates. Cannot calculate delivery.',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _selectedAddress = selectedAddress;
          _restaurant = restaurant;
          _deliveryDistanceKm = null;
          _deliveryFee = null;
          _isCalculatingDelivery = false;
        });

        return;
      }

      // --------------------------------------------------
      // CALCULATE DISTANCE
      // --------------------------------------------------

      final distance =
          DistanceUtils.distanceInKm(
        latitude1:
            selectedAddress.latitude!,
        longitude1:
            selectedAddress.longitude!,
        latitude2:
            restaurant.latitude!,
        longitude2:
            restaurant.longitude!,
      );

      // --------------------------------------------------
      // CALCULATE DELIVERY FEE
      // --------------------------------------------------

      final fee =
          DistanceUtils.deliveryFee(
        distanceKm: distance,
      );

      debugPrint(
        'Distance: ${distance.toStringAsFixed(2)} km',
      );

      debugPrint(
        'Delivery Fee: ₱${fee.toStringAsFixed(2)}',
      );

      debugPrint(
        '==========================================',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAddress = selectedAddress;
        _restaurant = restaurant;
        _deliveryDistanceKm = distance;
        _deliveryFee = fee;
        _isCalculatingDelivery = false;
      });
    } catch (e) {
      debugPrint(
        'CART DELIVERY ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCalculatingDelivery = false;
        _deliveryFee = null;
        _deliveryDistanceKm = null;
      });
    }
  }

  Future<void> _goToCheckout() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cart: widget.cart,
        ),
      ),
    );

    if (mounted && widget.cart.items.isNotEmpty) {
      await _loadDeliveryInformation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.cart,
        builder: (context, _) {
          if (widget.cart.items.isEmpty) {
            return const _EmptyCartView();
          }

          final subtotal = widget.cart.total;

          final deliveryFee = _deliveryFee ?? 0.0;

          final total = subtotal + deliveryFee;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            children: [
              ...widget.cart.items.map(
                (cartItem) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: _CartItemCard(
                    cartItem: cartItem,
                    cart: widget.cart,
                    onQuantityChanged:
                        _loadDeliveryInformation,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _DeliveryFeeCard(
                deliveryFee: _deliveryFee,
                distanceKm: _deliveryDistanceKm,
                address: _selectedAddress,
                restaurant: _restaurant,
                isCalculating:
                    _isCalculatingDelivery,
              ),

              const SizedBox(height: 16),

              _OrderSummary(
                subtotal: subtotal,
                deliveryFee: deliveryFee,
                total: total,
                isCalculating:
                    _isCalculatingDelivery ||
                    _deliveryFee == null,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                      _isCalculatingDelivery
                          ? null
                          : _goToCheckout,
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                  ),
                  label: Text(
                    _isCalculatingDelivery
                        ? 'Calculating Delivery...'
                        : 'Proceed to Checkout',
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
    );
  }
}

// ============================================================
// CART ITEM CARD
// ============================================================

class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final CartProvider cart;
  final Future<void> Function() onQuantityChanged;

  const _CartItemCard({
    required this.cartItem,
    required this.cart,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final item = cartItem.item;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: _CartItemImage(
                imageUrl: item.imageUrl,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '₱${item.price.toStringAsFixed(2)} each',
                    style: const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _QuantityButton(
                        icon:
                            Icons.remove_rounded,
                        onTap: () async {
                          cart.updateQuantity(
                            item.id,
                            cartItem.quantity - 1,
                          );

                          await onQuantityChanged();
                        },
                      ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                        ),
                        child: Text(
                          '${cartItem.quantity}',
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),

                      _QuantityButton(
                        icon:
                            Icons.add_rounded,
                        onTap: () async {
                          cart.updateQuantity(
                            item.id,
                            cartItem.quantity + 1,
                          );

                          await onQuantityChanged();
                        },
                      ),

                      const Spacer(),

                      Text(
                        '₱${cartItem.subtotal.toStringAsFixed(2)}',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              HalalFoodTheme
                                  .primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            IconButton(
              onPressed: () async {
                cart.removeItem(item.id);

                if (cart.items.isNotEmpty) {
                  await onQuantityChanged();
                }
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
              ),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DELIVERY FEE CARD
// ============================================================

class _DeliveryFeeCard extends StatelessWidget {
  final double? deliveryFee;
  final double? distanceKm;
  final Address? address;
  final Restaurant? restaurant;
  final bool isCalculating;

  const _DeliveryFeeCard({
    required this.deliveryFee,
    required this.distanceKm,
    required this.address,
    required this.restaurant,
    required this.isCalculating,
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
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Calculating delivery fee...',
                  style: TextStyle(
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

    if (deliveryFee == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.delivery_dining_outlined,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delivery fee is not available yet.',
                ),
              ),
              IconButton(
                onPressed: () {
                  final state =
                      context
                          .findAncestorStateOfType<
                              _CartScreenState>();

                  state?._loadDeliveryInformation();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
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
                  decoration:
                      BoxDecoration(
                    color: HalalFoodTheme
                        .primaryGreen
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_outlined,
                    color:
                        HalalFoodTheme
                            .primaryGreen,
                  ),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Delivery Fee',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                Text(
                  '₱${deliveryFee!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        HalalFoodTheme
                            .primaryGreen,
                  ),
                ),
              ],
            ),

            if (distanceKm != null) ...[
              const SizedBox(height: 14),

              const Divider(height: 1),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Distance',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${distanceKm!.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ORDER SUMMARY
// ============================================================

class _OrderSummary extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double total;
  final bool isCalculating;

  const _OrderSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.isCalculating,
  });

  Widget _row(
    String label,
    double value, {
    bool totalRow = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize:
                  totalRow ? 17 : 14,
              fontWeight: totalRow
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ),
        Text(
          '₱${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize:
                totalRow ? 19 : 14,
            fontWeight:
                FontWeight.w800,
            color: totalRow
                ? HalalFoodTheme
                    .primaryGreen
                : HalalFoodTheme
                    .textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: HalalFoodTheme
            .primaryGreen
            .withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _row(
            'Subtotal',
            subtotal,
          ),

          const SizedBox(height: 10),

          if (isCalculating)
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery Fee',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ],
            )
          else
            _row(
              'Delivery Fee',
              deliveryFee,
            ),

          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Divider(),
          ),

          _row(
            'Total',
            total,
            totalRow: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QUANTITY BUTTON
// ============================================================

class _QuantityButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration:
            BoxDecoration(
          color: HalalFoodTheme
              .primaryGreen
              .withValues(
            alpha: 0.08,
          ),
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color:
              HalalFoodTheme
                  .primaryGreen,
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY CART
// ============================================================

class _EmptyCartView
    extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: HalalFoodTheme
                  .primaryGreen
                  .withValues(
                alpha: 0.55,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Add some delicious halal food to your cart.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CART ITEM IMAGE
// ============================================================

class _CartItemImage
    extends StatelessWidget {
  final String? imageUrl;

  const _CartItemImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null ||
        imageUrl!.trim().isEmpty) {
      return Container(
        color: HalalFoodTheme
            .primaryGreen
            .withValues(
          alpha: 0.08,
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 36,
            color:
                HalalFoodTheme
                    .primaryGreen,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: HalalFoodTheme
              .primaryGreen
              .withValues(
            alpha: 0.08,
          ),
          child: const Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 36,
              color:
                  HalalFoodTheme
                      .primaryGreen,
            ),
          ),
        );
      },
    );
  }
}