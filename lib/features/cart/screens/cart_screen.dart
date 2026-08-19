import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../data/cart_item.dart';
import '../providers/cart_provider.dart';

class CartScreen extends StatelessWidget {
  final CartProvider cart;

  const CartScreen({
    super.key,
    required this.cart,
  });

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
        listenable: cart,
        builder: (context, _) {
          if (cart.items.isEmpty) {
            return const _EmptyCartView();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            children: [
              ...cart.items.map(
                (cartItem) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: _CartItemCard(
                    cartItem: cartItem,
                    cart: cart,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _OrderSummary(
                cart: cart,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Checkout will be available soon.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                  ),
                  label: const Text(
                    'Proceed to Checkout',
                    style: TextStyle(
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
                          HalalFoodTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          cart.updateQuantity(
                            item.id,
                            cartItem.quantity - 1,
                          );
                        },
                      ),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        child: Text(
                          '${cartItem.quantity}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      _QuantityButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          cart.updateQuantity(
                            item.id,
                            cartItem.quantity + 1,
                          );
                        },
                      ),

                      const Spacer(),

                      Text(
                        '₱${cartItem.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              HalalFoodTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            IconButton(
              onPressed: () {
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

class _QuantityButton extends StatelessWidget {
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color:
              HalalFoodTheme.primaryGreen.withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: HalalFoodTheme.primaryGreen,
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final CartProvider cart;

  const _OrderSummary({
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    const deliveryFee = 0.0;
    final total = cart.total + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
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
              fontSize: isTotal ? 17 : 14,
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
            fontSize: isTotal ? 19 : 14,
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

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color:
                  HalalFoodTheme.primaryGreen
                      .withValues(alpha: 0.55),
            ),

            const SizedBox(height: 18),

            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Add some delicious halal food to your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    HalalFoodTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemImage extends StatelessWidget {
  final String? imageUrl;

  const _CartItemImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null ||
        imageUrl!.trim().isEmpty) {
      return Container(
        color:
            HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.08,
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 36,
            color: HalalFoodTheme.primaryGreen,
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
          color:
              HalalFoodTheme.primaryGreen.withValues(
            alpha: 0.08,
          ),
          child: const Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 36,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
        );
      },
    );
  }
}