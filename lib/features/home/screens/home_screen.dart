import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../category/data/food_category_model.dart';
import '../../category/data/food_category_repository.dart';
import '../../category/widgets/food_category_section.dart';
import '../../restaurant/data/menu_item_model.dart';
import '../../restaurant/data/menu_repository.dart';
import '../../restaurant/screens/restaurant_details_screen.dart';
import '../data/restaurant_model.dart';
import '../data/restaurant_repository.dart';

import 'package:provider/provider.dart';

import '../../cart/providers/cart_provider.dart';
import '../../cart/screens/cart_screen.dart';
import '../../profile/screens/profile_screen.dart';




class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RestaurantRepository _restaurantRepository =
      RestaurantRepository();

  final FoodCategoryRepository _categoryRepository =
      FoodCategoryRepository();

  final MenuRepository _menuRepository = MenuRepository();

  final TextEditingController _searchController =
      TextEditingController();

  late Future<List<Restaurant>> _restaurantsFuture;
  late Future<List<FoodCategory>> _categoriesFuture;

  String? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _loadRestaurants();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRestaurants() {
    _restaurantsFuture =
        _restaurantRepository.getRestaurants();
  }

  void _loadCategories() {
    _categoriesFuture =
        _categoryRepository.getCategories();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadRestaurants();
      _loadCategories();
    });

    await Future.wait([
      _restaurantsFuture,
      _categoriesFuture,
    ]);
  }

  void _selectCategory(FoodCategory category) {
    setState(() {
      if (_selectedCategoryId == category.id) {
        _selectedCategoryId = null;
      } else {
        _selectedCategoryId = category.id;
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  bool _matchesSearch(
    Restaurant restaurant,
    List<MenuItem> menuItems,
  ) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final restaurantName =
        restaurant.name.toLowerCase();

    final description =
        restaurant.description.toLowerCase();

    final address =
        restaurant.address.toLowerCase();

    final city =
        restaurant.city.toLowerCase();

    final province =
        restaurant.province.toLowerCase();

    if (restaurantName.contains(_searchQuery) ||
        description.contains(_searchQuery) ||
        address.contains(_searchQuery) ||
        city.contains(_searchQuery) ||
        province.contains(_searchQuery)) {
      return true;
    }

    return menuItems.any(
      (item) =>
          item.name
              .toLowerCase()
              .contains(_searchQuery) ||
          item.description
              .toLowerCase()
              .contains(_searchQuery),
    );
  }
bool _matchesCategory(
  FoodCategory category,
  List<MenuItem> menuItems,
) {
  return menuItems.any(
    (item) => item.foodCategoryIds.contains(
      category.id,
    ),
  );
}















  Future<List<MenuItem>> _getMenuItems(
    String restaurantId,
  ) {
    return _menuRepository.getMenuItems(
      restaurantId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HALAL Food',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
actions: [
  Consumer<CartProvider>(
    builder: (context, cart, _) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CartScreen(
                    cart: cart,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.shopping_cart_outlined,
            ),
          ),

          if (cart.itemCount > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  cart.itemCount > 99
                      ? '99+'
                      : '${cart.itemCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  ),

  IconButton(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
    },
    icon: const Icon(
      Icons.person_outline_rounded,
    ),
  ),
],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Restaurant>>(
          future: _restaurantsFuture,
          builder: (
            context,
            restaurantSnapshot,
          ) {
            if (restaurantSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (restaurantSnapshot.hasError) {
              return _ErrorView(
                message:
                    restaurantSnapshot.error.toString(),
                onRetry: () {
                  setState(() {
                    _loadRestaurants();
                  });
                },
              );
            }

            final restaurants =
                restaurantSnapshot.data ?? [];

  return FutureBuilder<List<FoodCategory>>(
  future: _categoriesFuture,
  builder: (
    context,
    categorySnapshot,
  ) {
    if (categorySnapshot.hasError) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 80),

          const Icon(
            Icons.error_outline_rounded,
            size: 60,
            color: Colors.red,
          ),

          const SizedBox(height: 16),

          const Text(
            'Category Error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            categorySnapshot.error.toString(),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

final categories =
    categorySnapshot.data ?? [];



    return _HomeContent(
      restaurants: restaurants,
      categories: categories,
      selectedCategoryId:
          _selectedCategoryId,
      searchController:
          _searchController,
      searchQuery:
          _searchQuery,
      onSearchChanged:
          _onSearchChanged,
      onClearSearch:
          _clearSearch,
      onCategorySelected:
          _selectCategory,
      getMenuItems:
          _getMenuItems,
      matchesSearch:
          _matchesSearch,
      matchesCategory:
          _matchesCategory,
    );
  },
);
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final List<Restaurant> restaurants;
  final List<FoodCategory> categories;
  final String? selectedCategoryId;

  final TextEditingController searchController;
  final String searchQuery;

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  final ValueChanged<FoodCategory>
      onCategorySelected;

  final Future<List<MenuItem>> Function(
    String restaurantId,
  ) getMenuItems;

  final bool Function(
    Restaurant restaurant,
    List<MenuItem> menuItems,
  ) matchesSearch;

  final bool Function(
    FoodCategory category,
    List<MenuItem> menuItems,
  ) matchesCategory;

  const _HomeContent({
    required this.restaurants,
    required this.categories,
    required this.selectedCategoryId,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onCategorySelected,
    required this.getMenuItems,
    required this.matchesSearch,
    required this.matchesCategory,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCategory =
        categories.where(
      (category) =>
          category.id == selectedCategoryId,
    );

    final category =
        selectedCategory.isEmpty
            ? null
            : selectedCategory.first;

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32,
      ),
      children: [
        const Text(
          'Find Halal Food',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: HalalFoodTheme.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Discover trusted halal restaurants near you.',
          style: TextStyle(
            fontSize: 15,
            color: HalalFoodTheme.textSecondary,
          ),
        ),

        const SizedBox(height: 20),

        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search restaurants or food',
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
          ),
        ),

        const SizedBox(height: 28),

        if (categories.isNotEmpty) ...[
          FoodCategorySection(
            categories: categories,
            selectedCategoryId:
                selectedCategoryId,
            onCategorySelected:
                onCategorySelected,
          ),

          const SizedBox(height: 30),
        ],

        FutureBuilder<List<_RestaurantWithMenu>>(
          future: _loadRestaurantMenus(),
          builder: (
            context,
            snapshot,
          ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 40,
                ),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message:
                    snapshot.error.toString(),
                onRetry: () {},
              );
            }

            final restaurantMenus =
                snapshot.data ?? [];

            final filtered =
                restaurantMenus.where(
              (entry) {
                final searchMatch =
                    matchesSearch(
                  entry.restaurant,
                  entry.menuItems,
                );

                final categoryMatch =
                    category == null ||
                        matchesCategory(
                          category,
                          entry.menuItems,
                        );

                return searchMatch &&
                    categoryMatch;
              },
            ).toList();

            final featured =
                filtered
                    .where(
                      (entry) =>
                          entry.restaurant
                              .isFeatured,
                    )
                    .toList();

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (searchQuery.isNotEmpty ||
                    selectedCategoryId != null)
                  _FilterResultHeader(
                    searchQuery: searchQuery,
                    selectedCategory:
                        category,
                    resultCount:
                        filtered.length,
                  ),

                if (featured.isNotEmpty) ...[
                  const _SectionTitle(
                    title:
                        'Featured Restaurants',
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 250,
                    child:
                        ListView.separated(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount:
                          featured.length,
                      separatorBuilder:
                          (_, _) =>
                              const SizedBox(
                        width: 14,
                      ),
                      itemBuilder:
                          (context, index) {
                        final restaurant =
                            featured[index]
                                .restaurant;

                        return _FeaturedRestaurantCard(
                          restaurant:
                              restaurant,
                          onTap: () {
                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RestaurantDetailsScreen(
                                  restaurant:
                                      restaurant,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),
                ],

                const _SectionTitle(
                  title:
                      'Nearby Restaurants',
                ),

                const SizedBox(height: 14),

                if (filtered.isEmpty)
                  const _NoResultsView()
                else
                  ...filtered.map(
                    (entry) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: _RestaurantCard(
                        restaurant:
                            entry.restaurant,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<List<_RestaurantWithMenu>>
      _loadRestaurantMenus() async {
    final result =
        <_RestaurantWithMenu>[];

    for (final restaurant
        in restaurants) {
      final menuItems =
          await getMenuItems(
        restaurant.id,
      );

      result.add(
        _RestaurantWithMenu(
          restaurant: restaurant,
          menuItems: menuItems,
        ),
      );
    }

    return result;
  }
}

class _RestaurantWithMenu {
  final Restaurant restaurant;
  final List<MenuItem> menuItems;

  const _RestaurantWithMenu({
    required this.restaurant,
    required this.menuItems,
  });
}

class _FilterResultHeader
    extends StatelessWidget {
  final String searchQuery;
  final FoodCategory? selectedCategory;
  final int resultCount;

  const _FilterResultHeader({
    required this.searchQuery,
    required this.selectedCategory,
    required this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    String text;

    if (searchQuery.isNotEmpty) {
      text =
          'Results for "$searchQuery"';
    } else if (selectedCategory != null) {
      text =
          '${selectedCategory!.icon ?? ''} ${selectedCategory!.name}';
    } else {
      text = 'Results';
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color:
                    HalalFoodTheme.textPrimary,
              ),
            ),
          ),
          Text(
            '$resultCount found',
            style: const TextStyle(
              fontSize: 13,
              color:
                  HalalFoodTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color:
            HalalFoodTheme.textPrimary,
      ),
    );
  }
}

class _FeaturedRestaurantCard
    extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _FeaturedRestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior:
            Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RestaurantImage(
                  imageUrl:
                      restaurant
                              .coverImageUrl ??
                          restaurant
                              .logoUrl,
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .star_rounded,
                          size: 18,
                          color:
                              Colors.amber,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          restaurant
                              .averageRating
                              .toStringAsFixed(
                            1,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          '(${restaurant.reviewCount})',
                          style:
                              const TextStyle(
                            color:
                                HalalFoodTheme
                                    .textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    _HalalBadge(
                      status:
                          restaurant
                              .halalStatus,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantCard
    extends StatelessWidget {
  final Restaurant restaurant;

  const _RestaurantCard({
    required this.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  RestaurantDetailsScreen(
                restaurant:
                    restaurant,
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 130,
              child: _RestaurantImage(
                imageUrl:
                    restaurant
                            .coverImageUrl ??
                        restaurant
                            .logoUrl,
              ),
            ),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .star_rounded,
                          size: 17,
                          color:
                              Colors.amber,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          restaurant
                              .averageRating
                              .toStringAsFixed(
                            1,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          '(${restaurant.reviewCount})',
                          style:
                              const TextStyle(
                            color:
                                HalalFoodTheme
                                    .textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      '${restaurant.city}, ${restaurant.province}',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            HalalFoodTheme
                                .textSecondary,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _HalalBadge(
                      status:
                          restaurant
                              .halalStatus,
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

class _RestaurantImage
    extends StatelessWidget {
  final String? imageUrl;

  const _RestaurantImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null ||
        imageUrl!.trim().isEmpty) {
      return Container(
        color:
            HalalFoodTheme
                .primaryGreen
                .withValues(
          alpha: 0.08,
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_rounded,
            size: 42,
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
      width: double.infinity,
      height: double.infinity,
      errorBuilder:
          (_, _, _) {
        return Container(
          color:
              HalalFoodTheme
                  .primaryGreen
                  .withValues(
            alpha: 0.08,
          ),
          child: const Center(
            child: Icon(
              Icons.restaurant_rounded,
              size: 42,
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

class _HalalBadge
    extends StatelessWidget {
  final String status;

  const _HalalBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized =
        status.toLowerCase();

    String label;
    IconData icon;

    if (normalized.contains(
      'certified',
    )) {
      label = 'Certified Halal';
      icon =
          Icons.verified_rounded;
    } else if (normalized.contains(
      'muslim',
    )) {
      label = 'Muslim-Owned';
      icon =
          Icons.person_rounded;
    } else {
      label = 'Halal Verified';
      icon =
          Icons.verified_user_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
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
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                HalalFoodTheme
                    .primaryGreen,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color:
                  HalalFoodTheme
                      .primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsView
    extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color:
                HalalFoodTheme
                    .primaryGreen,
          ),
          SizedBox(
            height: 20,
          ),
          Text(
            'No restaurants found.',
            style:
                TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          SizedBox(
            height: 6,
          ),
          Text(
            'Try another search or category.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  HalalFoodTheme
                      .textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Unable to load restaurants.',
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
              maxLines: 4,
              overflow:
                  TextOverflow.ellipsis,
            ),

            const SizedBox(
              height: 20,
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