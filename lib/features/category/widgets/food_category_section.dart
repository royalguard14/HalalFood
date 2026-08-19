import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/food_category_model.dart';

class FoodCategorySection extends StatelessWidget {
  final List<FoodCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<FoodCategory> onCategorySelected;

  const FoodCategorySection({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Explore Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: HalalFoodTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 105,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];

              final isSelected =
                  category.id == selectedCategoryId;

              return _CategoryCard(
                category: category,
                isSelected: isSelected,
                onTap: () {
                  onCategorySelected(category);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final FoodCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = category.icon?.trim();

    return SizedBox(
      width: 82,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: isSelected
                    ? HalalFoodTheme.primaryGreen
                    : HalalFoodTheme.primaryGreen
                        .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? HalalFoodTheme.primaryGreen
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  icon == null || icon.isEmpty ? '🍽️' : icon,
                  style: TextStyle(
                    fontSize: 30,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? HalalFoodTheme.primaryGreen
                    : HalalFoodTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}