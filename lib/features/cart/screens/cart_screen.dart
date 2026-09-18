import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../checkout/screens/checkout_screen.dart';
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
  bool _isOpeningCheckout = false;

  Future<void> _goToCheckout() async {
    if (_isOpeningCheckout) return;

    setState(() => _isOpeningCheckout = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(cart: widget.cart),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.cart,
        builder: (context, _) {
          if (widget.cart.items.isEmpty) {
            return const _EmptyCartView();
          }

          final total = widget.cart.total;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    ...widget.cart.items.map(
                      (cartItem) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CartItemCard(
                          cartItem: cartItem,
                          cart: widget.cart,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HalalFoodTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: HalalFoodTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 64,
                          child: ElevatedButton.icon(
                            onPressed: _isOpeningCheckout ? null : _goToCheckout,
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text(
                              'Proceed to Checkout',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
  const _CartItemCard({
    required this.cartItem,
    required this.cart,
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