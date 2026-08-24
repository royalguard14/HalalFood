import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class FoodCategoryManagementScreen extends StatefulWidget {
  const FoodCategoryManagementScreen({super.key});

  @override
  State<FoodCategoryManagementScreen> createState() =>
      _FoodCategoryManagementScreenState();
}

class _FoodCategoryManagementScreenState
    extends State<FoodCategoryManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('food_categories')
          .select('id, name, slug, icon, is_active, sort_order')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _categories = (response as List)
            .map((item) => Map<String, dynamic>.from(item))
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

  Future<void> _addCategory() async {
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );

    if (result == null || !mounted) return;

    try {
      final existing = await _supabase
          .from('food_categories')
          .select('id')
          .eq('slug', result.slug)
          .maybeSingle();

      if (existing != null) {
        _showMessage('A category with this slug already exists.');
        return;
      }

      final maxResponse = await _supabase
          .from('food_categories')
          .select('sort_order')
          .order('sort_order', ascending: false)
          .limit(1);

      var nextSortOrder = 0;
      if (maxResponse.isNotEmpty) {
        final current = maxResponse.first['sort_order'];
        if (current is num) {
          nextSortOrder = current.toInt() + 1;
        }
      }

      await _supabase.from('food_categories').insert({
        'name': result.name,
        'slug': result.slug,
        'icon': result.icon.isEmpty ? null : result.icon,
        'is_active': result.isActive,
        'sort_order': nextSortOrder,
      });

      if (!mounted) return;
      await _loadCategories();
      _showMessage('Food category added successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to add category:\n$e');
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    if (id == null || id.isEmpty) return;

    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (_) => _CategoryDialog(
        initialName: category['name']?.toString() ?? '',
        initialSlug: category['slug']?.toString() ?? '',
        initialIcon: category['icon']?.toString() ?? '',
        initialIsActive: category['is_active'] == true,
        title: 'Edit Food Category',
        submitLabel: 'Save Changes',
      ),
    );

    if (result == null || !mounted) return;

    try {
      final duplicate = await _supabase
          .from('food_categories')
          .select('id')
          .eq('slug', result.slug)
          .neq('id', id)
          .maybeSingle();

      if (duplicate != null) {
        _showMessage('A category with this slug already exists.');
        return;
      }

      await _supabase.from('food_categories').update({
        'name': result.name,
        'slug': result.slug,
        'icon': result.icon.isEmpty ? null : result.icon,
        'is_active': result.isActive,
      }).eq('id', id);

      if (!mounted) return;
      await _loadCategories();
      _showMessage('Food category updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to update category:\n$e');
    }
  }

  Future<void> _toggleCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    if (id == null || id.isEmpty) return;

    final current = category['is_active'] == true;

    try {
      await _supabase
          .from('food_categories')
          .update({'is_active': !current})
          .eq('id', id);

      if (!mounted) return;
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to update category:\n$e');
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    final name = category['name']?.toString() ?? 'this category';

    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Delete Food Category',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete "$name"?\n\n'
          'Only delete a category if it is not being used by menu items.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _supabase.from('food_categories').delete().eq('id', id);

      if (!mounted) return;
      await _loadCategories();
      _showMessage('Food category deleted.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to delete category:\n$e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _categoryIcon(String? icon) {
    switch (icon?.toLowerCase()) {
      case 'burger':
      case 'burgers':
        return Icons.lunch_dining_rounded;
      case 'pizza':
        return Icons.local_pizza_rounded;
      case 'chicken':
        return Icons.restaurant_rounded;
      case 'rice':
      case 'rice_meals':
        return Icons.rice_bowl_rounded;
      case 'seafood':
      case 'fish':
        return Icons.set_meal_rounded;
      case 'dessert':
      case 'desserts':
        return Icons.cake_rounded;
      case 'drinks':
      case 'drink':
        return Icons.local_drink_rounded;
      case 'coffee':
        return Icons.coffee_rounded;
      case 'noodles':
        return Icons.ramen_dining_rounded;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Food Categories',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadCategories,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addCategory,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Category',
          style: TextStyle(fontWeight: FontWeight.w700),
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
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 260),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text(
            'Unable to load food categories',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loadCategories,
            child: const Text('Try Again'),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.category_outlined, size: 64),
          SizedBox(height: 16),
          Text(
            'No food categories yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Create the first global food category for restaurants to use.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = _categories[index];
        final name = category['name']?.toString() ?? '';
        final slug = category['slug']?.toString() ?? '';
        final icon = category['icon']?.toString();
        final isActive = category['is_active'] == true;

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              backgroundColor:
                  HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
              child: Icon(
                _categoryIcon(icon),
                color: HalalFoodTheme.primaryGreen,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('$slug • ${isActive ? 'Active' : 'Inactive'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editCategory(category);
                    break;
                  case 'toggle':
                    _toggleCategory(category);
                    break;
                  case 'delete':
                    _deleteCategory(category);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    leading: Icon(Icons.power_settings_new_rounded),
                    title: Text('Toggle Active'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryFormResult {
  final String name;
  final String slug;
  final String icon;
  final bool isActive;

  const _CategoryFormResult({
    required this.name,
    required this.slug,
    required this.icon,
    required this.isActive,
  });
}

class _CategoryDialog extends StatefulWidget {
  final String initialName;
  final String initialSlug;
  final String initialIcon;
  final bool initialIsActive;
  final String title;
  final String submitLabel;

  const _CategoryDialog({
    this.initialName = '',
    this.initialSlug = '',
    this.initialIcon = '',
    this.initialIsActive = true,
    this.title = 'Add Food Category',
    this.submitLabel = 'Add Category',
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _iconController;

  late bool _isActive;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialName);
    _slugController = TextEditingController(text: widget.initialSlug);
    _iconController = TextEditingController(text: widget.initialIcon);
    _isActive = widget.initialIsActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim().toLowerCase();
    final icon = _iconController.text.trim();

    if (name.isEmpty) {
      _showValidation('Please enter a category name.');
      return;
    }

    if (slug.isEmpty) {
      _showValidation('Please enter a slug.');
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    Navigator.of(context).pop(
      _CategoryFormResult(
        name: name,
        slug: slug,
        icon: icon,
        isActive: _isActive,
      ),
    );
  }

  void _showValidation(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Burgers',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _slugController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Slug',
                hintText: 'e.g. burgers',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _iconController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Icon',
                hintText: 'e.g. burger',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Active',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _isActive,
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
