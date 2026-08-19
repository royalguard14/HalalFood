import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/category_food_repository.dart';
import '../data/food_category_model.dart';

class CategoryFoodScreen extends StatefulWidget {
  final FoodCategory category;

  const CategoryFoodScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryFoodScreen> createState() =>
      _CategoryFoodScreenState();
}

class _CategoryFoodScreenState
    extends State<CategoryFoodScreen> {
  final CategoryFoodRepository _repository =
      CategoryFoodRepository();

  late Future<List<CategoryFoodResult>> _foodsFuture;

  @override
  void initState() {
    super.initState();

    _foodsFuture =
        _repository.getFoodsByCategory(widget.category.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _foodsFuture =
          _repository.getFoodsByCategory(
        widget.category.id,
      );
    });

    await _foodsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.category.icon ?? '🍽️'} ${widget.category.name}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CategoryFoodResult>>(
          future: _foodsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final foods = snapshot.data ?? [];

            if (foods.isEmpty) {
              return _EmptyView(
                categoryName: widget.category.name,
              );
            }

            return ListView.separated(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                32,
              ),
              itemCount: foods.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _FoodCard(
                  food: foods[index],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final CategoryFoodResult food;

  const _FoodCard({
    required this.food,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: 125,
            child: _FoodImage(
              imageUrl: food.imageUrl,
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    food.foodName,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color:
                          HalalFoodTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    food.restaurantName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme.textSecondary,
                    ),
                  ),

                  if (food.description
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      food.description,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color:
                            HalalFoodTheme.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Text(
                        '₱${food.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              HalalFoodTheme.primaryGreen,
                        ),
                      ),

                      const Spacer(),

                      if (food.isFeatured)
                        const Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: Colors.amber,
                        ),
                    ],
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

class _FoodImage extends StatelessWidget {
  final String? imageUrl;

  const _FoodImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null ||
        imageUrl!.trim().isEmpty) {
      return Container(
        color:
            HalalFoodTheme.primaryGreen
                .withValues(alpha: 0.08),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 42,
            color:
                HalalFoodTheme.primaryGreen,
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
          (context, error, stackTrace) {
        return Container(
          color:
              HalalFoodTheme.primaryGreen
                  .withValues(alpha: 0.08),
          child: const Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 42,
              color:
                  HalalFoodTheme.primaryGreen,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String categoryName;

  const _EmptyView({
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 150),

        Icon(
          Icons.restaurant_menu_outlined,
          size: 64,
          color:
              HalalFoodTheme.primaryGreen,
        ),

        const SizedBox(height: 20),

        Center(
          child: Text(
            'No $categoryName items available yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(height: 8),

        const Center(
          child: Text(
            'Check again later for available food.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  HalalFoodTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load food items.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow:
                  TextOverflow.ellipsis,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: onRetry,
              child:
                  const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}