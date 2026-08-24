
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerMenuManagementScreen extends StatefulWidget {
  const OwnerMenuManagementScreen({
    super.key,
  });

  @override
  State<OwnerMenuManagementScreen> createState() =>
      _OwnerMenuManagementScreenState();
}

class _OwnerMenuManagementScreenState
    extends State<OwnerMenuManagementScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _error;
  String? _restaurantId;
  String? _restaurantName;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _menuItems = [];


  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  // ============================================================
  // LOAD MENU
  // ============================================================

  Future<void> _loadMenu() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'User is not authenticated.',
        );
      }

      final restaurantResponse = await _supabase
          .from('restaurants')
          .select('id, name')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (restaurantResponse == null) {
        throw Exception(
          'No restaurant is linked to this account.',
        );
      }

      final restaurantId =
          restaurantResponse['id'].toString();

      final restaurantName =
          restaurantResponse['name']?.toString() ?? '';

      final categoriesResponse = await _supabase
          .from('menu_categories')
          .select(
            'id, restaurant_id, name, description, '
            'sort_order, is_active, created_at',
          )
          .eq(
            'restaurant_id',
            restaurantId,
          )
          .order(
            'sort_order',
            ascending: true,
          );

      final menuItemsResponse = await _supabase
          .from('menu_items')
          .select(
            'id, restaurant_id, category_id, name, '
            'description, price, image_url, '
            'is_available, is_featured, '
            'created_at, updated_at',
          )
          .eq(
            'restaurant_id',
            restaurantId,
          )
          .order(
            'is_featured',
            ascending: false,
          )
          .order(
            'name',
            ascending: true,
          );



      if (!mounted) return;

      setState(() {
        _restaurantId = restaurantId;
        _restaurantName = restaurantName;

        _categories =
            (categoriesResponse as List)
                .map(
                  (item) =>
                      Map<String, dynamic>.from(item),
                )
                .toList();

        _menuItems =
            (menuItemsResponse as List)
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
    if (_restaurantId == null) return;

    final nameController =
        TextEditingController();

    final descriptionController =
        TextEditingController();

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Menu Category',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration:
                    const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Rice Meals',
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller:
                    descriptionController,
                maxLines: 3,
                decoration:
                    const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'Optional description',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ],
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
              onPressed: () {
                final name =
                    nameController.text
                        .trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    final name =
        nameController.text.trim();

    final description =
        descriptionController.text.trim();

    nameController.dispose();
    descriptionController.dispose();

    if (name.isEmpty) return;

    try {
      setState(() {
        _isSaving = true;
      });

      final nextSortOrder =
          _categories.length;

      await _supabase
          .from('menu_categories')
          .insert({
        'restaurant_id': _restaurantId,
        'name': name,
        'description':
            description.isEmpty
                ? null
                : description,
        'sort_order': nextSortOrder,
        'is_active': true,
      });

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to add category:\n$e',
      );
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

    final descriptionController =
        TextEditingController(
      text:
          category['description']
                  ?.toString() ??
              '',
    );

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit Category',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(
                  labelText: 'Category Name',
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller:
                    descriptionController,
                maxLines: 3,
                decoration:
                    const InputDecoration(
                  labelText: 'Description',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ],
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
              onPressed: () {
                if (nameController.text
                    .trim()
                    .isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    final name =
        nameController.text.trim();

    final description =
        descriptionController.text.trim();

    nameController.dispose();
    descriptionController.dispose();

    if (name.isEmpty) return;

    try {
      setState(() {
        _isSaving = true;
      });

      await _supabase
          .from('menu_categories')
          .update({
        'name': name,
        'description':
            description.isEmpty
                ? null
                : description,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update category:\n$e',
      );
    }
  }

  // ============================================================
  // TOGGLE CATEGORY
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
      setState(() {
        _isSaving = true;
      });

      await _supabase
          .from('menu_categories')
          .update({
        'is_active': !current,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update category:\n$e',
      );
    }
  }

  // ============================================================
  // ADD MENU ITEM
  // ============================================================

  Future<void> _addMenuItem({
    String? initialCategoryId,
  }) async {
    if (_restaurantId == null) return;

    if (_categories.isEmpty) {
      _showError(
        'Please create a menu category first.',
      );
      return;
    }

    final nameController =
        TextEditingController();

    final descriptionController =
        TextEditingController();

    final priceController =
        TextEditingController();

    String? selectedCategoryId =
        initialCategoryId;

    if (selectedCategoryId == null ||
        !_categories.any(
          (category) =>
              category['id']
                  ?.toString() ==
              selectedCategoryId,
        )) {
      selectedCategoryId =
          _categories.first['id']
              ?.toString();
    }

    bool isFeatured = false;
    bool isAvailable = true;

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Add Menu Item',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          nameController,
                      autofocus: true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Item Name',
                        hintText:
                            'e.g. Chicken Rice',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          descriptionController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Description',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          priceController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Price',
                        prefixText:
                            '₱ ',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          selectedCategoryId,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Menu Category',
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          _categories
                              .map(
                        (
                          category,
                        ) {
                          final id =
                              category[
                                  'id']
                                  ?.toString();

                          final name =
                              category[
                                      'name']
                                  ?.toString() ??
                                  '';

                          if (id ==
                              null) {
                            return null;
                          }

                          return DropdownMenuItem<
                              String>(
                            value: id,
                            child: Text(
                              name,
                            ),
                          );
                        },
                      )
                              .whereType<
                                  DropdownMenuItem<
                                      String>>()
                              .toList(),
                      onChanged:
                          (value) {
                        setDialogState(() {
                          selectedCategoryId =
                              value;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Available',
                      ),
                      value:
                          isAvailable,
                      onChanged:
                          (value) {
                        setDialogState(() {
                          isAvailable =
                              value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Featured',
                      ),
                      value:
                          isFeatured,
                      onChanged:
                          (value) {
                        setDialogState(() {
                          isFeatured =
                              value;
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
                      const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name =
                        nameController
                            .text
                            .trim();

                    final price =
                        double.tryParse(
                      priceController
                          .text
                          .trim(),
                    );

                    if (name.isEmpty ||
                        price == null ||
                        price < 0 ||
                        selectedCategoryId ==
                            null) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child:
                      const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      descriptionController.dispose();
      priceController.dispose();
      return;
    }

    final name =
        nameController.text.trim();

    final description =
        descriptionController.text.trim();

    final price =
        double.tryParse(
      priceController.text.trim(),
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();

    if (name.isEmpty ||
        price == null ||
        price < 0 ||
        selectedCategoryId == null) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _supabase
          .from('menu_items')
          .insert({
        'restaurant_id': _restaurantId,
        'category_id':
            selectedCategoryId,
        'name': name,
        'description':
            description.isEmpty
                ? null
                : description,
        'price': price,
        'image_url': null,
        'is_available':
            isAvailable,
        'is_featured':
            isFeatured,
      });

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to add menu item:\n$e',
      );
    }
  }

  // ============================================================
  // EDIT MENU ITEM
  // ============================================================

  Future<void> _editMenuItem(
    Map<String, dynamic> item,
  ) async {
    final id =
        item['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final nameController =
        TextEditingController(
      text:
          item['name']?.toString() ?? '',
    );

    final descriptionController =
        TextEditingController(
      text:
          item['description']
                  ?.toString() ??
              '',
    );

    final priceController =
        TextEditingController(
      text:
          ((item['price'] as num?)
                      ?.toDouble() ??
                  0)
              .toStringAsFixed(2),
    );

    String? selectedCategoryId =
        item['category_id']?.toString();

    if (selectedCategoryId == null ||
        !_categories.any(
          (category) =>
              category['id']
                  ?.toString() ==
              selectedCategoryId,
        )) {
      selectedCategoryId =
          _categories.isNotEmpty
              ? _categories.first['id']
                  ?.toString()
              : null;
    }

    bool isAvailable =
        item['is_available'] == true;

    bool isFeatured =
        item['is_featured'] == true;

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Edit Menu Item',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          nameController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Item Name',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          descriptionController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Description',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    TextField(
                      controller:
                          priceController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Price',
                        prefixText:
                            '₱ ',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          selectedCategoryId,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Menu Category',
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          _categories
                              .map(
                        (
                          category,
                        ) {
                          final categoryId =
                              category[
                                  'id']
                                  ?.toString();

                          final categoryName =
                              category[
                                      'name']
                                  ?.toString() ??
                                  '';

                          if (categoryId ==
                              null) {
                            return null;
                          }

                          return DropdownMenuItem<
                              String>(
                            value:
                                categoryId,
                            child:
                                Text(
                              categoryName,
                            ),
                          );
                        },
                      )
                              .whereType<
                                  DropdownMenuItem<
                                      String>>()
                              .toList(),
                      onChanged:
                          (value) {
                        setDialogState(() {
                          selectedCategoryId =
                              value;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Available',
                      ),
                      value:
                          isAvailable,
                      onChanged:
                          (value) {
                        setDialogState(() {
                          isAvailable =
                              value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Featured',
                      ),
                      value:
                          isFeatured,
                      onChanged:
                          (value) {
                        setDialogState(() {
                          isFeatured =
                              value;
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
                      const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name =
                        nameController
                            .text
                            .trim();

                    final price =
                        double.tryParse(
                      priceController
                          .text
                          .trim(),
                    );

                    if (name.isEmpty ||
                        price == null ||
                        price < 0 ||
                        selectedCategoryId ==
                            null) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child:
                      const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      descriptionController.dispose();
      priceController.dispose();
      return;
    }

    final name =
        nameController.text.trim();

    final description =
        descriptionController.text.trim();

    final price =
        double.tryParse(
      priceController.text.trim(),
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();

    if (name.isEmpty ||
        price == null ||
        price < 0 ||
        selectedCategoryId == null) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _supabase
          .from('menu_items')
          .update({
        'category_id':
            selectedCategoryId,
        'name': name,
        'description':
            description.isEmpty
                ? null
                : description,
        'price': price,
        'is_available':
            isAvailable,
        'is_featured':
            isFeatured,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update menu item:\n$e',
      );
    }
  }

  // ============================================================
  // TOGGLE MENU ITEM
  // ============================================================

  Future<void> _toggleMenuItem(
    Map<String, dynamic> item,
  ) async {
    final id =
        item['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final current =
        item['is_available'] == true;

    try {
      setState(() {
        _isSaving = true;
      });

      await _supabase
          .from('menu_items')
          .update({
        'is_available': !current,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update menu item:\n$e',
      );
    }
  }

  // ============================================================
  // DELETE / DEACTIVATE MENU ITEM
  // ============================================================

  Future<void> _deleteMenuItem(
    Map<String, dynamic> item,
  ) async {
    final id =
        item['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final name =
        item['name']?.toString() ??
            'this item';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove Menu Item?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "$name" from the menu?',
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
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _supabase
          .from('menu_items')
          .update({
        'is_available': false,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to remove menu item:\n$e',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================



  List<Map<String, dynamic>>
      _itemsForCategory(
    String categoryId,
  ) {
    return _menuItems
        .where(
          (item) =>
              item['category_id']
                  ?.toString() ==
              categoryId,
        )
        .toList();
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Menu',
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
                    : _loadMenu,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton:
          _isLoading ||
                  _restaurantId == null
              ? null
              : FloatingActionButton.extended(
                  onPressed:
                      _isSaving
                          ? null
                          : () =>
                              _addMenuItem(),
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add Item',
                  ),
                ),
      body: _buildBody(),
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
      return RefreshIndicator(
        onRefresh: _loadMenu,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(
              height: 150,
            ),
            Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 60,
                    color:
                        Colors.redAccent,
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  const Text(
                    'Unable to load menu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    _error!,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  ElevatedButton(
                    onPressed:
                        _loadMenu,
                    child:
                        const Text(
                      'Try Again',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100,
        ),
        children: [
          _buildRestaurantHeader(),

          const SizedBox(
            height: 20,
          ),

          _buildSummaryCard(),

          const SizedBox(
            height: 24,
          ),

          _buildCategoryHeader(),

          const SizedBox(
            height: 12,
          ),

          if (_categories.isEmpty)
            _buildNoCategories()
          else
            ..._categories
                .where(
              (category) =>
                  category['is_active'] !=
                  false,
            )
                .map(
              (category) =>
                  _buildCategorySection(
                category,
              ),
            ),

          _buildInactiveCategories(),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeader() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme
            .primaryGreen
            .withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color: HalalFoodTheme
                  .primaryGreen
                  .withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 28,
              color:
                  HalalFoodTheme
                      .primaryGreen,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Menu',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        HalalFoodTheme
                            .textSecondary,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  _restaurantName ??
                      '',
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final availableCount =
        _menuItems
            .where(
              (item) =>
                  item['is_available'] ==
                  true,
            )
            .length;

    final featuredCount =
        _menuItems
            .where(
              (item) =>
                  item['is_featured'] ==
                  true,
            )
            .length;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon:
                    Icons.restaurant_menu_rounded,
                title: 'Items',
                value:
                    _menuItems.length
                        .toString(),
              ),
            ),
            Expanded(
              child: _SummaryItem(
                icon:
                    Icons.check_circle_outline_rounded,
                title: 'Available',
                value:
                    availableCount
                        .toString(),
              ),
            ),
            Expanded(
              child: _SummaryItem(
                icon:
                    Icons.star_outline_rounded,
                title: 'Featured',
                value:
                    featuredCount
                        .toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Menu Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed:
              _isSaving
                  ? null
                  : _addCategory,
          icon: const Icon(
            Icons.add_rounded,
            size: 18,
          ),
          label:
              const Text('Category'),
        ),
      ],
    );
  }

  Widget _buildNoCategories() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons
                  .category_outlined,
              size: 54,
              color: HalalFoodTheme
                  .primaryGreen
                  .withValues(
                alpha: 0.55,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'No menu categories yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              'Create your first category before adding menu items.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            ElevatedButton.icon(
              onPressed:
                  _isSaving
                      ? null
                      : _addCategory,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text(
                'Add Category',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    Map<String, dynamic> category,
  ) {
    final categoryId =
        category['id']?.toString() ?? '';

    final items =
        _itemsForCategory(
      categoryId,
    );

    final categoryName =
        category['name']
                ?.toString() ??
            'Category';

    final description =
        category['description']
                ?.toString() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
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
                  12,
                ),
              ),
              child: const Icon(
                Icons.category_rounded,
                color:
                    HalalFoodTheme
                        .primaryGreen,
              ),
            ),
            title: Text(
              categoryName,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            subtitle:
                description.isEmpty
                    ? Text(
                        '${items.length} item${items.length == 1 ? '' : 's'}',
                      )
                    : Text(
                        description,
                      ),
            trailing: PopupMenuButton<
                String>(
              onSelected:
                  (value) {
                if (value ==
                    'edit') {
                  _editCategory(
                    category,
                  );
                } else if (value ==
                    'toggle') {
                  _toggleCategory(
                    category,
                  );
                }
              },
              itemBuilder:
                  (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Edit',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .visibility_off_outlined,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Deactivate',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
          ),
          if (items.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Column(
                children: [
                  const Text(
                    'No items in this category.',
                    style: TextStyle(
                      color:
                          HalalFoodTheme
                              .textSecondary,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextButton.icon(
                    onPressed:
                        _isSaving
                            ? null
                            : () =>
                                _addMenuItem(
                              initialCategoryId:
                                  categoryId,
                            ),
                    icon: const Icon(
                      Icons.add_rounded,
                    ),
                    label:
                        const Text(
                      'Add Item',
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map(
              (item) =>
                  _buildMenuItemTile(
                item,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile(
    Map<String, dynamic> item,
  ) {
    final name =
        item['name']?.toString() ??
            '';

    final description =
        item['description']
                ?.toString() ??
            '';

    final price =
        (item['price'] as num?)
                ?.toDouble() ??
            0;

    final imageUrl =
        item['image_url']?.toString();

    final isAvailable =
        item['is_available'] == true;

    final isFeatured =
        item['is_featured'] == true;

    return InkWell(
      onTap:
          _isSaving
              ? null
              : () =>
                  _editMenuItem(item),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          8,
          12,
        ),
        child: Row(
          children: [
            _buildItemImage(
              imageUrl,
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style:
                              const TextStyle(
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isFeatured)
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            left: 6,
                          ),
                          child: Icon(
                            Icons.star_rounded,
                            size: 17,
                            color:
                                Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  if (description
                      .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top: 3,
                      ),
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              HalalFoodTheme
                                  .textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    '₱${price.toStringAsFixed(2)}',
                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          HalalFoodTheme
                              .primaryGreen,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          (isAvailable
                                  ? Colors
                                      .green
                                  : Colors
                                      .red)
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
                      isAvailable
                          ? 'Available'
                          : 'Unavailable',
                      style:
                          TextStyle(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            isAvailable
                                ? Colors
                                    .green
                                : Colors
                                    .red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected:
                  (value) {
                if (value ==
                    'edit') {
                  _editMenuItem(item);
                } else if (value ==
                    'toggle') {
                  _toggleMenuItem(
                    item,
                  );
                } else if (value ==
                    'remove') {
                  _deleteMenuItem(
                    item,
                  );
                }
              },
              itemBuilder:
                  (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .edit_outlined,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Edit',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        item['is_available'] ==
                                true
                            ? Icons
                                .visibility_off_outlined
                            : Icons
                                .visibility_outlined,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        item['is_available'] ==
                                true
                            ? 'Make Unavailable'
                            : 'Make Available',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .delete_outline_rounded,
                        color:
                            Colors.red,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Remove',
                        style:
                            TextStyle(
                          color:
                              Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(
    String? imageUrl,
  ) {
    return Container(
      width: 64,
      height: 64,
      decoration:
          BoxDecoration(
        color: HalalFoodTheme
            .primaryGreen
            .withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child:
          imageUrl != null &&
                  imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return const Icon(
                      Icons
                          .restaurant_rounded,
                      color:
                          HalalFoodTheme
                              .primaryGreen,
                    );
                  },
                )
              : const Icon(
                  Icons
                      .restaurant_rounded,
                  color:
                      HalalFoodTheme
                          .primaryGreen,
                ),
    );
  }

  Widget _buildInactiveCategories() {
    final inactive =
        _categories
            .where(
              (category) =>
                  category[
                      'is_active'] ==
                  false,
            )
            .toList();

    if (inactive.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin:
          const EdgeInsets.only(
        top: 10,
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.visibility_off_outlined,
        ),
        title: Text(
          'Inactive Categories (${inactive.length})',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        children:
            inactive.map(
          (category) {
            final name =
                category['name']
                        ?.toString() ??
                    'Category';

            return ListTile(
              title: Text(
                name,
              ),
              trailing:
                  TextButton(
                onPressed:
                    _isSaving
                        ? null
                        : () =>
                            _toggleCategory(
                          category,
                        ),
                child:
                    const Text(
                  'Activate',
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}

class _SummaryItem
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color:
              HalalFoodTheme
                  .primaryGreen,
        ),
        const SizedBox(
          height: 6,
        ),
        Text(
          value,
          style:
              const TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 11,
            color:
                HalalFoodTheme
                    .textSecondary,
          ),
        ),
      ],
    );
  }
}

