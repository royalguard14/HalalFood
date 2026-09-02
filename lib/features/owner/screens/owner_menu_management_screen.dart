import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerMenuManagementScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerMenuManagementScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerMenuManagementScreen> createState() =>
      _OwnerMenuManagementScreenState();
}

class _OwnerMenuManagementScreenState extends State<OwnerMenuManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String _search = '';
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, int> _monthlySalesByItem = {};
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _monthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> _loadMenu() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesResponse = await _supabase
          .from('menu_categories')
          .select('id, restaurant_id, name, description, sort_order, is_active')
          .eq('restaurant_id', widget.restaurantId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final itemsResponse = await _supabase
          .from('menu_items')
          .select(
            'id, restaurant_id, category_id, name, description, price, image_url, is_available, is_featured',
          )
          .eq('restaurant_id', widget.restaurantId)
          .order('name', ascending: true);

      final orders = await _supabase
          .from('orders')
          .select('id')
          .eq('restaurant_id', widget.restaurantId)
          .eq('status', 'delivered')
          .gte('created_at', _monthStart().toIso8601String());

      final orderIds = (orders as List)
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .toList();

      final sales = <String, int>{};
      if (orderIds.isNotEmpty) {
        final orderItems = await _supabase
            .from('order_items')
            .select('menu_item_id, quantity')
            .inFilter('order_id', orderIds);

        for (final row in (orderItems as List)) {
          final itemId = row['menu_item_id']?.toString();
          if (itemId == null) continue;
          sales[itemId] =
              (sales[itemId] ?? 0) + ((row['quantity'] as num?)?.toInt() ?? 0);
        }
      }

      if (!mounted) return;

      final categories = (categoriesResponse as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final items = (itemsResponse as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final categoryIds = categories
          .map((category) => category['id']?.toString())
          .whereType<String>()
          .toSet();

      setState(() {
        _categories = categories;
        _items = items;
        _monthlySalesByItem = sales;
        _isLoading = false;
        _isSaving = false;
        if (_selectedCategoryId != null &&
            !categoryIds.contains(_selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSaving = false;
        _error = e.toString();
      });
    }
  }

  String _categoryName(String? id) {
    for (final category in _categories) {
      if (category['id']?.toString() == id) {
        return category['name']?.toString() ?? 'Category';
      }
    }
    return 'Uncategorized';
  }

  int _soldThisMonth(String? id) =>
      id == null ? 0 : (_monthlySalesByItem[id] ?? 0);

  int get _bestSellerCount => _monthlySalesByItem.values.isEmpty
      ? 0
      : _monthlySalesByItem.values.reduce((a, b) => a > b ? a : b);

  bool _isBestSeller(String? id) {
    final sold = _soldThisMonth(id);
    return sold > 0 && sold == _bestSellerCount;
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _search.trim().toLowerCase();
    return _items.where((item) {
      if (_selectedCategoryId != null &&
          item['category_id']?.toString() != _selectedCategoryId) {
        return false;
      }
      if (query.isEmpty) return true;

      final name = item['name']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final category =
          _categoryName(item['category_id']?.toString()).toLowerCase();
      return name.contains(query) ||
          description.contains(query) ||
          category.contains(query);
    }).toList();
  }

  Future<XFile?> _pickFoodPhoto() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (e) {
      if (mounted) _showError('Unable to choose photo:\n$e');
      return null;
    }
  }

  Future<String> _uploadFoodPhoto(String menuItemId, XFile file) async {
    final bytes = await file.readAsBytes();
    final path =
        '${widget.restaurantId}/$menuItemId-${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage.from('menu-item-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    return _supabase.storage.from('menu-item-images').getPublicUrl(path);
  }

  Future<_Draft?> _dialog({
    required String title,
    String? categoryId,
    String name = '',
    String description = '',
    String price = '',
    bool available = true,
    String? imageUrl,
  }) async {
    String itemName = name;
    String itemDescription = description;
    String itemPrice = price;
    String? selectedCategory = categoryId;
    bool isAvailable = available;
    XFile? selectedPhoto;
    bool removePhoto = false;

    if (!_categories.any(
      (category) => category['id']?.toString() == selectedCategory,
    )) {
      selectedCategory = _categories.isEmpty
          ? null
          : _categories.first['id']?.toString();
    }

    return showDialog<_Draft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PhotoPickerBox(
                  imageUrl: imageUrl,
                  selectedPhoto: selectedPhoto,
                  onPick: () async {
                    final photo = await _pickFoodPhoto();
                    if (photo == null) return;
                    setDialogState(() {
                      selectedPhoto = photo;
                      removePhoto = false;
                    });
                  },
                  onRemove: imageUrl != null || selectedPhoto != null
                      ? () {
                          setDialogState(() {
                            selectedPhoto = null;
                            removePhoto = true;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Food photo is optional. If none is added, customers will see NO PHOTO.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: name,
                  onChanged: (value) => itemName = value,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  onChanged: (value) => itemDescription = value,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional item description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: price,
                  onChanged: (value) => itemPrice = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Menu Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    final id = category['id']?.toString();
                    if (id == null) return null;
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        category['name']?.toString() ?? 'Category',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).whereType<DropdownMenuItem<String>>().toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  subtitle: const Text('Customers can order this item'),
                  value: isAvailable,
                  onChanged: (value) {
                    setDialogState(() => isAvailable = value);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Best Seller is automatic and is based on completed purchases this month. Featured is controlled separately from the item menu.',
                      style: TextStyle(
                        fontSize: 12,
                        color: HalalFoodTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsedPrice = double.tryParse(itemPrice.trim());
                if (itemName.trim().isEmpty ||
                    parsedPrice == null ||
                    parsedPrice < 0 ||
                    selectedCategory == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid name, price, and menu category.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _Draft(
                    name: itemName.trim(),
                    description: itemDescription.trim(),
                    price: parsedPrice,
                    categoryId: selectedCategory!,
                    available: isAvailable,
                    photo: selectedPhoto,
                    removePhoto: removePhoto,
                  ),
                );
              },
              child: Text(title == 'Add Menu Item' ? 'Add Item' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    if (_isSaving || _categories.isEmpty) return;

    final draft = await _dialog(
      title: 'Add Menu Item',
      categoryId: _selectedCategoryId,
    );
    if (draft == null || !mounted) return;

    try {
      setState(() => _isSaving = true);

      final inserted = await _supabase
          .from('menu_items')
          .insert({
            'restaurant_id': widget.restaurantId,
            'category_id': draft.categoryId,
            'name': draft.name,
            'description':
                draft.description.isEmpty ? null : draft.description,
            'price': draft.price,
            'image_url': null,
            'is_available': draft.available,
            'is_featured': false,
          })
          .select('id')
          .single();

      final id = inserted['id']?.toString();
      if (id != null && draft.photo != null) {
        final url = await _uploadFoodPhoto(id, draft.photo!);
        await _supabase
            .from('menu_items')
            .update({'image_url': url})
            .eq('id', id)
            .eq('restaurant_id', widget.restaurantId);
      }

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to add menu item:\n$e');
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    if (_isSaving) return;
    final id = item['id']?.toString();
    if (id == null) return;

    final oldImage = item['image_url']?.toString();
    final draft = await _dialog(
      title: 'Edit Menu Item',
      categoryId: item['category_id']?.toString(),
      name: item['name']?.toString() ?? '',
      description: item['description']?.toString() ?? '',
      price: ((item['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      available: item['is_available'] == true,
      imageUrl: oldImage,
    );
    if (draft == null || !mounted) return;

    try {
      setState(() => _isSaving = true);

      await _supabase
          .from('menu_items')
          .update({
            'category_id': draft.categoryId,
            'name': draft.name,
            'description':
                draft.description.isEmpty ? null : draft.description,
            'price': draft.price,
            'is_available': draft.available,
          })
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);

      if (draft.photo != null) {
        final url = await _uploadFoodPhoto(id, draft.photo!);
        await _supabase
            .from('menu_items')
            .update({'image_url': url})
            .eq('id', id)
            .eq('restaurant_id', widget.restaurantId);
      } else if (draft.removePhoto) {
        await _supabase
            .from('menu_items')
            .update({'image_url': null})
            .eq('id', id)
            .eq('restaurant_id', widget.restaurantId);
      }

      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to update menu item:\n$e');
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item) async {
    if (_isSaving) return;
    final id = item['id']?.toString();
    if (id == null) return;
    final current = item['is_available'] == true;

    try {
      setState(() => _isSaving = true);
      await _supabase
          .from('menu_items')
          .update({'is_available': !current})
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to change availability:\n$e');
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> item) async {
    if (_isSaving) return;
    final id = item['id']?.toString();
    if (id == null) return;
    final current = item['is_featured'] == true;

    try {
      setState(() => _isSaving = true);
      await _supabase
          .from('menu_items')
          .update({'is_featured': !current})
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to change featured status:\n$e');
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    if (_isSaving) return;
    final id = item['id']?.toString();
    if (id == null) return;
    final name = item['name']?.toString() ?? 'this item';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Remove Menu Item?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Permanently remove "$name"? This is different from Available/Unavailable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isSaving = true);
      final references = await _supabase
          .from('order_items')
          .select('id')
          .eq('menu_item_id', id)
          .limit(1);

      if ((references as List).isNotEmpty) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        _showError(
          'This item is already in an order. Use Available/Unavailable instead.',
        );
        return;
      }

      await _supabase
          .from('menu_item_categories')
          .delete()
          .eq('menu_item_id', id);
      await _supabase
          .from('menu_items')
          .delete()
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to remove menu item:\n$e');
    }
  }

  Future<void> _manageCategories() async {
    if (_isSaving) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Manage Categories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add Category',
                      onPressed: () async {
                        await _addCategory();
                        if (sheetContext.mounted) setSheetState(() {});
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create, rename, reorder, or remove categories. Categories with menu items cannot be deleted.',
                  style: TextStyle(
                    color: HalalFoodTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                if (_categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No categories yet.')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final itemCount = _items
                            .where((item) =>
                                item['category_id']?.toString() ==
                                category['id']?.toString())
                            .length;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: HalalFoodTheme.primaryGreen
                                .withValues(alpha: .10),
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            category['name']?.toString() ?? 'Category',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text('$itemCount item(s)'),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Move up',
                                onPressed: index == 0
                                    ? null
                                    : () async {
                                        await _moveCategory(index, index - 1);
                                        if (sheetContext.mounted) {
                                          setSheetState(() {});
                                        }
                                      },
                                icon: const Icon(
                                    Icons.keyboard_arrow_up_rounded),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                onPressed: index == _categories.length - 1
                                    ? null
                                    : () async {
                                        await _moveCategory(index, index + 1);
                                        if (sheetContext.mounted) {
                                          setSheetState(() {});
                                        }
                                      },
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () async {
                                  await _editCategory(category);
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () async {
                                  await _deleteCategory(category);
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (mounted) await _loadMenu();
  }

  Future<void> _addCategory() async {
    final draft = await _categoryDialog(title: 'Add Category');
    if (draft == null || !mounted) return;

    try {
      setState(() => _isSaving = true);
      await _supabase.from('menu_categories').insert({
        'restaurant_id': widget.restaurantId,
        'name': draft.name,
        'description': draft.description.isEmpty ? null : draft.description,
        'sort_order': _categories.length,
        'is_active': true,
      });
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to add category:\n$e');
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    if (id == null) return;

    final draft = await _categoryDialog(
      title: 'Edit Category',
      name: category['name']?.toString() ?? '',
      description: category['description']?.toString() ?? '',
    );
    if (draft == null || !mounted) return;

    try {
      setState(() => _isSaving = true);
      await _supabase
          .from('menu_categories')
          .update({
            'name': draft.name,
            'description':
                draft.description.isEmpty ? null : draft.description,
          })
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to update category:\n$e');
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    final name = category['name']?.toString() ?? 'this category';
    if (id == null) return;

    final itemCount = _items
        .where((item) => item['category_id']?.toString() == id)
        .length;
    if (itemCount > 0) {
      _showError(
        'Cannot delete "$name" because it contains $itemCount menu item(s). Move or remove the items first.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Delete Category?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Delete "$name" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isSaving = true);
      await _supabase
          .from('menu_categories')
          .delete()
          .eq('id', id)
          .eq('restaurant_id', widget.restaurantId);
      if (_selectedCategoryId == id) _selectedCategoryId = null;
      await _loadMenu();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Unable to delete category:\n$e');
    }
  }

  Future<void> _moveCategory(int from, int to) async {
    if (_isSaving || from == to) return;

    final reordered = List<Map<String, dynamic>>.from(_categories);
    final moved = reordered.removeAt(from);
    reordered.insert(to, moved);

    try {
      setState(() {
        _isSaving = true;
        _categories = reordered;
      });

      for (var index = 0; index < reordered.length; index++) {
        final id = reordered[index]['id']?.toString();
        if (id == null) continue;
        await _supabase
            .from('menu_categories')
            .update({'sort_order': index})
            .eq('id', id)
            .eq('restaurant_id', widget.restaurantId);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _loadMenu();
      _showError('Unable to reorder categories:\n$e');
    }
  }

  Future<_CategoryDraft?> _categoryDialog({
    required String title,
    String name = '',
    String description = '',
  }) async {
    String categoryName = name;
    String categoryDescription = description;

    return showDialog<_CategoryDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              onChanged: (value) => categoryName = value,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Rice Meals, Drinks, Desserts',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: description,
              onChanged: (value) => categoryDescription = value,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (categoryName.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a category name.')),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                _CategoryDraft(
                  name: categoryName.trim(),
                  description: categoryDescription.trim(),
                ),
              );
            },
            child: Text(title == 'Add Category' ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Menu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Categories',
            onPressed: _isLoading || _isSaving ? null : _manageCategories,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMenu,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _categories.isEmpty || _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load menu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMenu,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Menu',
                  style: TextStyle(
                    fontSize: 13,
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.restaurantName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.restaurant_menu_rounded,
                        label: 'Items',
                        value: '${_items.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.category_outlined,
                        label: 'Categories',
                        value: '${_categories.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_rounded,
                        label: 'Featured',
                        value:
                            '${_items.where((item) => item['is_featured'] == true).length}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Search menu item or category...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_categories.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.category_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Create your first menu category',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Items must belong to a category before they can be added.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HalalFoodTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _addCategory,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Category'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _buildCategoryFilter(),
            const SizedBox(height: 18),
            _buildMenuList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Categories',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : _manageCategories,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _categoryFilterChip(
                  label: 'All',
                  selected: _selectedCategoryId == null,
                  onTap: () => setState(() => _selectedCategoryId = null),
                );
              }
              final category = _categories[index - 1];
              final id = category['id']?.toString();
              if (id == null) return const SizedBox.shrink();
              return _categoryFilterChip(
                label: category['name']?.toString() ?? 'Category',
                selected: _selectedCategoryId == id,
                onTap: () => setState(() => _selectedCategoryId = id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onTap(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : HalalFoodTheme.textPrimary,
      ),
      selectedColor: HalalFoodTheme.primaryGreen,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected
            ? HalalFoodTheme.primaryGreen
            : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      showCheckmark: false,
    );
  }

  Widget _buildMenuList() {
    final items = _filteredItems;
    if (items.isEmpty) {
      final message = _search.trim().isNotEmpty
          ? 'No menu items match "${_search.trim()}".'
          : _selectedCategoryId == null
              ? 'No menu items have been added yet.'
              : 'No menu items in ${_categoryName(_selectedCategoryId)}.';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                size: 52,
                color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap Add Item to create a menu item.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HalalFoodTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 20,
                  color: HalalFoodTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (_selectedCategoryId != null)
                  Text(
                    _categoryName(_selectedCategoryId),
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.asMap().entries.map(
            (entry) => Column(
              children: [
                _itemTile(entry.value),
                if (entry.key != items.length - 1)
                  const Divider(height: 1, indent: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString();
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final available = item['is_available'] == true;
    final featured = item['is_featured'] == true;
    final soldThisMonth = _soldThisMonth(id);
    final bestSeller = _isBestSeller(id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      onTap: _isSaving ? null : () => _edit(item),
      leading: _ItemImage(imageUrl: imageUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (bestSeller) _badge('BEST SELLER', Colors.orange),
          if (featured) _badge('FEATURED', HalalFoodTheme.primaryGreen),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(
          spacing: 7,
          runSpacing: 4,
          children: [
            Text(
              _categoryName(item['category_id']?.toString()),
              style: const TextStyle(
                color: HalalFoodTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description.isNotEmpty)
              Text(
                '• ${description.length > 35 ? '${description.substring(0, 35)}…' : description}',
                style: const TextStyle(
                  color: HalalFoodTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            Text(
              '• $soldThisMonth sold this month',
              style: TextStyle(
                color: soldThisMonth > 0
                    ? HalalFoodTheme.primaryGreen
                    : HalalFoodTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              available ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: available ? Colors.green : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '₱${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _edit(item);
              if (value == 'availability') _toggleAvailability(item);
              if (value == 'featured') _toggleFeatured(item);
              if (value == 'remove') _remove(item);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Item'),
              ),
              PopupMenuItem(
                value: 'availability',
                child: Text(
                    available ? 'Mark Unavailable' : 'Mark Available'),
              ),
              PopupMenuItem(
                value: 'featured',
                child: Text(
                    featured ? 'Remove Featured' : 'Mark Featured'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove Permanently'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _PhotoPickerBox extends StatelessWidget {
  final String? imageUrl;
  final XFile? selectedPhoto;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const _PhotoPickerBox({
    required this.imageUrl,
    required this.selectedPhoto,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 170,
            child: selectedPhoto != null
                ? Image.file(
                    File(selectedPhoto!.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(),
                  )
                : imageUrl != null && imageUrl!.trim().isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholder(),
                      )
                    : _placeholder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                    imageUrl == null && selectedPhoto == null
                        ? 'Add Photo'
                        : 'Change Photo'),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove Photo',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fastfood_outlined,
            size: 48,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            'NO PHOTO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemImage extends StatelessWidget {
  final String? imageUrl;

  const _ItemImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.fastfood_rounded,
        color: HalalFoodTheme.primaryGreen,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: HalalFoodTheme.primaryGreen),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Draft {
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final bool available;
  final XFile? photo;
  final bool removePhoto;

  const _Draft({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.available,
    required this.photo,
    required this.removePhoto,
  });
}

class _CategoryDraft {
  final String name;
  final String description;

  const _CategoryDraft({
    required this.name,
    required this.description,
  });
}
