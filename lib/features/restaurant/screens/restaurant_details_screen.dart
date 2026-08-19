import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../home/data/restaurant_model.dart';
import '../data/menu_category_model.dart';
import '../data/menu_item_model.dart';
import '../data/menu_repository.dart';

import '../../menu/screens/menu_item_details_screen.dart';



class RestaurantDetailsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailsScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState
    extends State<RestaurantDetailsScreen> {
  final MenuRepository _menuRepository = MenuRepository();

  late Future<_RestaurantMenuData> _menuFuture;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  void _loadMenu() {
    _menuFuture = _getMenu();
  }



Future<_RestaurantMenuData> _getMenu() async {
  final results = await Future.wait([
    _menuRepository.getCategories(
      widget.restaurant.id,
    ),
    _menuRepository.getMenuItems(
      widget.restaurant.id,
    ),
    _menuRepository.getFoodCategories(),
  ]);

  return _RestaurantMenuData(
    categories:
        results[0] as List<MenuCategory>,
    items:
        results[1] as List<MenuItem>,
    foodCategories:
        results[2] as List<Map<String, dynamic>>,
  );
}








  Future<void> _refreshMenu() async {
    setState(() {
      _loadMenu();
    });

    await _menuFuture;
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshMenu,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: HalalFoodTheme.primaryGreen,
              iconTheme: const IconThemeData(
                color: Colors.white,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _CoverImage(
                  imageUrl:
                      restaurant.coverImageUrl ?? restaurant.logoUrl,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: HalalFoodTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 22,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          restaurant.averageRating
                              .toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${restaurant.reviewCount} reviews',
                          style: const TextStyle(
                            color: HalalFoodTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _HalalStatusBadge(
                      status: restaurant.halalStatus,
                    ),

                    if (restaurant.description.isNotEmpty) ...[
                      const SizedBox(height: 24),

                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: HalalFoodTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        restaurant.description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: HalalFoodTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: restaurant.address.isNotEmpty
                          ? restaurant.address
                          : '${restaurant.city}, ${restaurant.province}',
                    ),

                    if (restaurant.address.isNotEmpty &&
                        (restaurant.city.isNotEmpty ||
                            restaurant.province.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.location_city_outlined,
                        text:
                            '${restaurant.city}, ${restaurant.province}',
                      ),
                    ],

                    const SizedBox(height: 30),

                    const Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: HalalFoodTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 14),

                    FutureBuilder<_RestaurantMenuData>(
                      future: _menuFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _MenuLoadingView();
                        }

                        if (snapshot.hasError) {
                          return _MenuErrorView(
                            message: snapshot.error.toString(),
                            onRetry: () {
                              setState(() {
                                _loadMenu();
                              });
                            },
                          );
                        }

                        final menu = snapshot.data;

                        if (menu == null || menu.items.isEmpty) {
                          return const _EmptyMenuView();
                        }

return _MenuView(
  categories: menu.categories,
  items: menu.items,
  foodCategories: menu.foodCategories,
);


                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _RestaurantMenuData {
  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final List<Map<String, dynamic>> foodCategories;

  const _RestaurantMenuData({
    required this.categories,
    required this.items,
    required this.foodCategories,
  });
}



class _MenuView extends StatelessWidget {
  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final List<Map<String, dynamic>> foodCategories;

  const _MenuView({
    required this.foodCategories,
    required this.categories,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final categorizedItems = <String, List<MenuItem>>{};

    for (final item in items) {
      final categoryId = item.categoryId;

      categorizedItems.putIfAbsent(
        categoryId,
        () => [],
      );

      categorizedItems[categoryId]!.add(item);
    }

    final widgets = <Widget>[];

    for (final category in categories) {
      final categoryItems =
          categorizedItems[category.id] ?? [];

      if (categoryItems.isEmpty) {
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            category.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: HalalFoodTheme.textPrimary,
            ),
          ),
        ),
      );

      for (final item in categoryItems) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MenuItemCard(
              item: item,
              foodCategories: foodCategories,
            ),
          ),
        );
      }

      widgets.add(
        const SizedBox(height: 10),
      );
    }

    final uncategorizedItems =
        categorizedItems['uncategorized'] ?? [];

    if (uncategorizedItems.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Other Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: HalalFoodTheme.textPrimary,
            ),
          ),
        ),
      );

      for (final item in uncategorizedItems) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MenuItemCard(
              item: item,
              foodCategories: foodCategories,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final List<Map<String, dynamic>> foodCategories;

  const _MenuItemCard({
  required this.item,
  required this.foodCategories,
});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MenuItemDetailsScreen(
                foodCategories: foodCategories,
                item: item,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: _MenuItemImage(
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
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 5),

                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color:
                              HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Text(
                      '₱${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color:
                            HalalFoodTheme.primaryGreen,
                      ),
                    ),

                    if (item.foodCategoryIds.isNotEmpty) ...[
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.foodCategoryIds
                            .map(
                              (id) => _FoodCategoryBadge(
                                foodCategories: foodCategories,
                                categoryId: id,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: HalalFoodTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _FoodCategoryBadge extends StatelessWidget {
  final String categoryId;
  final List<Map<String, dynamic>> foodCategories;

  const _FoodCategoryBadge({
    required this.categoryId,
    required this.foodCategories,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? category;

    for (final item in foodCategories) {
      if (item['id']?.toString() == categoryId) {
        category = item;
        break;
      }
    }

    final name =
        category?['name']?.toString() ?? 'Unknown';

    final icon =
        category?['icon']?.toString() ?? '🍽️';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$icon $name',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HalalFoodTheme.primaryGreen,
        ),
      ),
    );
  }
}




class _MenuItemImage extends StatelessWidget {
  final String? imageUrl;

  const _MenuItemImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Container(
        color: HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.08,
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 38,
            color: HalalFoodTheme.primaryGreen,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: HalalFoodTheme.primaryGreen.withValues(
            alpha: 0.08,
          ),
          child: const Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 38,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
        );
      },
    );
  }
}

class _MenuLoadingView extends StatelessWidget {
  const _MenuLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _EmptyMenuView extends StatelessWidget {
  const _EmptyMenuView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 42,
            color: HalalFoodTheme.primaryGreen,
          ),
          SizedBox(height: 10),
          Text(
            'No menu items available yet.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'This restaurant has not added any menu items.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HalalFoodTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MenuErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load menu.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String? imageUrl;

  const _CoverImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Container(
        color: HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.12,
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_rounded,
            size: 70,
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
          color: HalalFoodTheme.primaryGreen.withValues(
            alpha: 0.12,
          ),
          child: const Center(
            child: Icon(
              Icons.restaurant_rounded,
              size: 70,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
        );
      },
    );
  }
}

class _HalalStatusBadge extends StatelessWidget {
  final String status;

  const _HalalStatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    String label;
    IconData icon;

    if (normalized == 'certified_halal') {
      label = 'Certified Halal';
      icon = Icons.verified_rounded;
    } else if (normalized == 'muslim_owned') {
      label = 'Muslim-Owned';
      icon = Icons.person_rounded;
    } else if (normalized == 'halal_verified') {
      label = 'Halal Verified';
      icon = Icons.verified_user_rounded;
    } else {
      label = 'Not Yet Verified';
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: HalalFoodTheme.primaryGreen,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: HalalFoodTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 21,
          color: HalalFoodTheme.primaryGreen,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: HalalFoodTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}