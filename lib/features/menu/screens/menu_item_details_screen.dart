import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../cart/data/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../restaurant/data/menu_item_model.dart';

import '../../cart/screens/cart_screen.dart';

class MenuItemDetailsScreen extends StatelessWidget {
  final MenuItem item;
  final List<Map<String, dynamic>> foodCategories;

  const MenuItemDetailsScreen({
    super.key,
    required this.item,
    required this.foodCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
SliverAppBar(
  expandedHeight: 300,
  pinned: true,
  backgroundColor: HalalFoodTheme.primaryGreen,
  iconTheme: const IconThemeData(
    color: Colors.white,
  ),

  actions: [
    ListenableBuilder(
      listenable: context.read<CartProvider>(),
      builder: (context, _) {
        final cart = context.read<CartProvider>();
        final count = cart.itemCount;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Cart',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CartScreen(
                        cart: context.read<CartProvider>(),
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                ),
              ),

              if (count > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: HalalFoodTheme.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ],

  flexibleSpace: FlexibleSpaceBar(
    background: _FoodImage(
      imageUrl: item.imageUrl,
    ),
  ),
),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                22,
                20,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FOOD NAME
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: HalalFoodTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // PRICE
                  Text(
                    '₱${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: HalalFoodTheme.primaryGreen,
                    ),
                  ),

                  // FOOD CATEGORIES
                  if (item.foodCategoryIds.isNotEmpty) ...[
                    const SizedBox(height: 18),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          item.foodCategoryIds.map((categoryId) {
                        Map<String, dynamic>? category;

                        for (final foodCategory
                            in foodCategories) {
                          if (foodCategory['id']?.toString() ==
                              categoryId) {
                            category = foodCategory;
                            break;
                          }
                        }

                        final name =
                            category?['name']?.toString() ??
                                'Unknown';

                        final icon =
                            category?['icon']?.toString() ??
                                '🍽️';

                        return _CategoryBadge(
                          label: '$icon $name',
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // HALAL + AVAILABILITY
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const _StatusBadge(
                        icon: Icons.verified_rounded,
                        label: 'Halal Food',
                      ),

                      _StatusBadge(
                        icon: item.isAvailable
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        label: item.isAvailable
                            ? 'Available'
                            : 'Unavailable',
                      ),
                    ],
                  ),

                  // FEATURED
                  if (item.isFeatured) ...[
                    const SizedBox(height: 10),

                    const _StatusBadge(
                      icon: Icons.star_rounded,
                      label: 'Featured',
                    ),
                  ],

                  // DESCRIPTION
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 30),

                    const Text(
                      'About this food',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: HalalFoodTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: HalalFoodTheme.textSecondary,
                      ),
                    ),
                  ],

                  // PRICE SECTION
                  const SizedBox(height: 30),

                  const Text(
                    'Price',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: HalalFoodTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                          HalalFoodTheme.primaryGreen.withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color:
                              HalalFoodTheme.primaryGreen,
                          size: 28,
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Text(
                            'Regular Price',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        Text(
                          '₱${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color:
                                HalalFoodTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ADD TO CART
                


// ADD TO CART
SizedBox(
  width: double.infinity,
  height: 54,
  child: ElevatedButton.icon(
    onPressed: item.isAvailable
        ? () async {
            final cart = context.read<CartProvider>();
            final cartItem = CartItem(item: item);

            // Same restaurant or empty cart
            if (cart.canAddItem(cartItem)) {
              cart.addItem(cartItem);

              if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    duration: const Duration(seconds: 3),
    content: Text(
      '${item.name} added to cart.',
    ),
  ),
);

              return;
            }

            // Different restaurant
            final shouldReplace = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text(
                    'Different Restaurant',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: const Text(
                    'Your cart contains items from another restaurant.\n\n'
                    'Clear your existing cart and add this item instead?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: const Text('Clear & Add'),
                    ),
                  ],
                );
              },
            );

            if (shouldReplace != true) {
              return;
            }

            cart.clearCart();
            cart.addItem(cartItem);

            if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    duration: const Duration(seconds: 3),
    content: Text(
      '${item.name} added to cart.',
    ),
  ),
);
          }
        : null,
    icon: const Icon(
      Icons.shopping_cart_outlined,
    ),
    label: const Text(
      'Add to Cart',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
),










                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// FOOD IMAGE
// ---------------------------------------------------------

class _FoodImage extends StatelessWidget {
  final String? imageUrl;

  const _FoodImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Container(
        color:
            HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.10,
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 90,
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
            alpha: 0.10,
          ),
          child: const Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 90,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// FOOD CATEGORY BADGE
// ---------------------------------------------------------

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color:
            HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: HalalFoodTheme.primaryGreen,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// STATUS BADGE
// ---------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
            HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: HalalFoodTheme.primaryGreen,
          ),

          const SizedBox(width: 6),

          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}