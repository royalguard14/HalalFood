import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class FoodCategoryManagementScreen extends StatefulWidget {
  const FoodCategoryManagementScreen({
    super.key,
  });

  @override
  State<FoodCategoryManagementScreen> createState() =>
      _FoodCategoryManagementScreenState();
}

class _FoodCategoryManagementScreenState
    extends State<FoodCategoryManagementScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _error;

  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();

    _loadCategories();
  }

  // ============================================================
  // LOAD CATEGORIES
  // ============================================================

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('food_categories')
          .select(
            'id, name, slug, icon, is_active, sort_order',
          )
          .order(
            'sort_order',
            ascending: true,
          )
          .order(
            'name',
            ascending: true,
          );

      if (!mounted) return;

      setState(() {
        _categories = (response as List)
            .map(
              (item) =>
                  Map<String, dynamic>.from(item),
            )
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // ADD CATEGORY
  // ============================================================

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final iconController = TextEditingController();

    bool isActive = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Add Food Category',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Burgers',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: slugController,
                      decoration:
                          const InputDecoration(
                        labelText: 'Slug',
                        hintText: 'e.g. burgers',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: iconController,
                      decoration:
                          const InputDecoration(
                        labelText: 'Icon',
                        hintText: 'e.g. burger',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Active',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child:
                      const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name =
                        nameController.text
                            .trim();

                    final slug =
                        slugController.text
                            .trim()
                            .toLowerCase();

                    final icon =
                        iconController.text
                            .trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a category name.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (slug.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a slug.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (_isSaving) return;

                    setDialogState(() {
                      _isSaving = true;
                    });

                    try {
                      final existing =
                          await _supabase
                              .from(
                                'food_categories',
                              )
                              .select('id')
                              .eq(
                                'slug',
                                slug,
                              )
                              .maybeSingle();

                      if (existing != null) {
                        throw Exception(
                          'A category with this slug already exists.',
                        );
                      }

                      final maxResponse =
                          await _supabase
                              .from(
                                'food_categories',
                              )
                              .select(
                                'sort_order',
                              )
                              .order(
                                'sort_order',
                                ascending: false,
                              )
                              .limit(1);

                      int nextSortOrder = 0;

                      if (
                          maxResponse.isNotEmpty) {
                        final current =
                            maxResponse.first[
                                'sort_order'];

                        if (current is num) {
                          nextSortOrder =
                              current.toInt() + 1;
                        }
                      }

                      await _supabase
                          .from(
                            'food_categories',
                          )
                          .insert({
                        'name': name,
                        'slug': slug,
                        'icon': icon.isEmpty
                            ? null
                            : icon,
                        'is_active': isActive,
                        'sort_order':
                            nextSortOrder,
                      });

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      setDialogState(() {
                        _isSaving = false;
                      });

                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Unable to add category:\n$e',
                          ),
                        ),
                      );
                    }
                  },
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Add Category',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    slugController.dispose();
    iconController.dispose();

    if (result == true) {
      await _loadCategories();
    }
  }

  // ============================================================
  // EDIT CATEGORY
  // ============================================================

  Future<void> _editCategory(
    Map<String, dynamic> category,
  ) async {
    final id =
        category['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final nameController =
        TextEditingController(
      text:
          category['name']?.toString() ?? '',
    );

    final slugController =
        TextEditingController(
      text:
          category['slug']?.toString() ?? '',
    );

    final iconController =
        TextEditingController(
      text:
          category['icon']?.toString() ?? '',
    );

    bool isActive =
        category['is_active'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Edit Food Category',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText: 'Category Name',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: slugController,
                      decoration:
                          const InputDecoration(
                        labelText: 'Slug',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: iconController,
                      decoration:
                          const InputDecoration(
                        labelText: 'Icon',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Active',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child:
                      const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name =
                        nameController.text
                            .trim();

                    final slug =
                        slugController.text
                            .trim()
                            .toLowerCase();

                    final icon =
                        iconController.text
                            .trim();

                    if (name.isEmpty ||
                        slug.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Category name and slug are required.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (_isSaving) return;

                    setDialogState(() {
                      _isSaving = true;
                    });

                    try {
                      final duplicate =
                          await _supabase
                              .from(
                                'food_categories',
                              )
                              .select('id')
                              .eq(
                                'slug',
                                slug,
                              )
                              .neq(
                                'id',
                                id,
                              )
                              .maybeSingle();

                      if (duplicate != null) {
                        throw Exception(
                          'A category with this slug already exists.',
                        );
                      }

                      await _supabase
                          .from(
                            'food_categories',
                          )
                          .update({
                        'name': name,
                        'slug': slug,
                        'icon': icon.isEmpty
                            ? null
                            : icon,
                        'is_active': isActive,
                      })
                          .eq(
                        'id',
                        id,
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      setDialogState(() {
                        _isSaving = false;
                      });

                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Unable to update category:\n$e',
                          ),
                        ),
                      );
                    }
                  },
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    slugController.dispose();
    iconController.dispose();

    if (result == true) {
      await _loadCategories();
    }
  }

  // ============================================================
  // TOGGLE ACTIVE
  // ============================================================

  Future<void> _toggleCategory(
    Map<String, dynamic> category,
  ) async {
    final id =
        category['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final current =
        category['is_active'] == true;

    try {
      await _supabase
          .from('food_categories')
          .update({
        'is_active': !current,
      })
          .eq(
        'id',
        id,
      );

      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update category:\n$e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  IconData _categoryIcon(
    String? icon,
  ) {
    switch (
        icon?.toLowerCase()) {
      case 'burger':
      case 'burgers':
        return Icons
            .lunch_dining_rounded;

      case 'pizza':
        return Icons
            .local_pizza_rounded;

      case 'chicken':
        return Icons
            .restaurant_rounded;

      case 'rice':
      case 'rice_meals':
        return Icons
            .rice_bowl_rounded;

      case 'seafood':
      case 'fish':
        return Icons
            .set_meal_rounded;

      case 'dessert':
      case 'desserts':
        return Icons
            .cake_rounded;

      case 'drinks':
      case 'drink':
        return Icons
            .local_drink_rounded;

      case 'coffee':
        return Icons
            .coffee_rounded;

      case 'noodles':
        return Icons
            .ramen_dining_rounded;

      default:
        return Icons
            .restaurant_menu_rounded;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Food Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoading
                    ? null
                    : _loadCategories,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _isLoading ? null : _addCategory,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Category',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons
                      .error_outline_rounded,
                  size: 60,
                  color:
                      Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load food categories',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        HalalFoodTheme
                            .textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed:
                      _loadCategories,
                  child:
                      const Text(
                    'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons
                      .restaurant_menu_rounded,
                  size: 64,
                  color:
                      HalalFoodTheme
                          .primaryGreen
                          .withValues(
                    alpha: 0.55,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'No food categories yet',
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
                  'Create the first food category for restaurants to use.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
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
                      _addCategory,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Create Category',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        100,
      ),
      itemCount:
          _categories.length,
      itemBuilder:
          (context, index) {
        final category =
            _categories[index];

        return _buildCategoryCard(
          category,
        );
      },
    );
  }

  Widget _buildCategoryCard(
    Map<String, dynamic> category,
  ) {
    final name =
        category['name']?.toString() ??
            'Unnamed';

    final slug =
        category['slug']?.toString() ??
            '';

    final icon =
        category['icon']?.toString();

    final isActive =
        category['is_active'] == true;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration:
              BoxDecoration(
            color: HalalFoodTheme
                .primaryGreen
                .withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            _categoryIcon(icon),
            color:
                HalalFoodTheme
                    .primaryGreen,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 4,
          ),
          child: Row(
            children: [
              Text(
                slug,
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      HalalFoodTheme
                          .textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration:
                    BoxDecoration(
                  color: isActive
                      ? Colors.green
                          .withValues(
                          alpha: 0.10,
                        )
                      : Colors.red
                          .withValues(
                          alpha: 0.10,
                        ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                ),
                child: Text(
                  isActive
                      ? 'Active'
                      : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                    color: isActive
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing:
            PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editCategory(
                  category,
                );
                break;

              case 'toggle':
                _toggleCategory(
                  category,
                );
                break;
            }
          },
          itemBuilder:
              (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                  ),
                  SizedBox(width: 10),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons
                            .visibility_off_rounded
                        : Icons
                            .visibility_rounded,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(
                    isActive
                        ? 'Deactivate'
                        : 'Activate',
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