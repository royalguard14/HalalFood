import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../owner/screens/owner_restaurant_profile_screen.dart';
import '../data/admin_repository.dart';
import '../data/admin_restaurant_repository.dart';

class RestaurantManagementScreen extends StatefulWidget {
  const RestaurantManagementScreen({super.key});

  @override
  State<RestaurantManagementScreen> createState() =>
      _RestaurantManagementScreenState();
}

class _RestaurantManagementScreenState
    extends State<RestaurantManagementScreen> {
  final _repository = AdminRepository();
  final _restaurantRepository = AdminRestaurantRepository();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'all';
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _owners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _repository.getRestaurants(),
        _restaurantRepository.getRestaurantOwners(),
      ]);

      if (!mounted) return;

      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(results[0]);
        _owners = List<Map<String, dynamic>>.from(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _ownerName(String? id) {
    if (id == null || id.isEmpty) return 'Unassigned';

    for (final owner in _owners) {
      if (owner['id']?.toString() == id) {
        final name = owner['full_name']?.toString().trim();
        return name == null || name.isEmpty ? 'Restaurant Owner' : name;
      }
    }

    return 'Owner account';
  }

  List<Map<String, dynamic>> get _filtered {
    return _restaurants.where((r) {
      final q = _search.toLowerCase();
      final name = r['name']?.toString().toLowerCase() ?? '';
      final city = r['city']?.toString().toLowerCase() ?? '';
      final owner = _ownerName(r['owner_id']?.toString()).toLowerCase();
      final active = r['is_active'] == true;
      final halal = r['halal_status']?.toString() ?? 'unverified';

      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          city.contains(q) ||
          owner.contains(q);

      final matchesFilter = switch (_filter) {
        'active' => active,
        'inactive' => !active,
        'unassigned' => r['owner_id'] == null,
        'unverified' => halal == 'unverified',
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _halalLabel(String value) => switch (value) {
        'muslim_owned' => 'Muslim Owned',
        'halal_verified' => 'Halal Verified',
        'certified_halal' => 'Certified Halal',
        _ => 'Unverified',
      };

  Color _halalColor(String value) => switch (value) {
        'muslim_owned' => Colors.blue,
        'halal_verified' => Colors.green,
        'certified_halal' => Colors.teal,
        _ => Colors.grey,
      };

  Future<void> _addRestaurant() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RestaurantForm(
        owners: _owners,
        repository: _restaurantRepository,
      ),
    );

    if (saved == true) {
      await _load();
      if (mounted) _message('Restaurant added successfully.');
    }
  }

  Future<void> _editRestaurant(Map<String, dynamic> restaurant) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RestaurantForm(
        owners: _owners,
        repository: _restaurantRepository,
        restaurant: restaurant,
      ),
    );

    if (saved == true) {
      await _load();
      if (mounted) _message('Restaurant updated successfully.');
    }
  }

  Future<void> _manageRestaurantPhotos(Map<String, dynamic> restaurant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerRestaurantProfileScreen(
          restaurantId: restaurant['id'].toString(),
          restaurantName: restaurant['name']?.toString() ?? 'Restaurant',
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _assignOwner(Map<String, dynamic> restaurant) async {
    final selected = restaurant['owner_id']?.toString();

    final result = await showDialog<_OwnerSelectionResult>(
      context: context,
      builder: (_) => _OwnerSelectionDialog(
        owners: _owners,
        initialOwnerId: selected,
      ),
    );

    if (result == null || result.ownerId == selected) return;

    try {
      await _restaurantRepository.assignOwner(
        restaurantId: restaurant['id'].toString(),
        ownerId: result.ownerId,
      );
      await _load();
      if (mounted) _message('Restaurant owner updated.');
    } catch (e) {
      if (mounted) _message('Unable to assign owner: $e');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> restaurant) async {
    final next = restaurant['is_active'] != true;

    try {
      await _repository.setRestaurantActive(
        restaurantId: restaurant['id'].toString(),
        isActive: next,
      );
      await _load();
      if (mounted) {
        _message(next ? 'Restaurant activated.' : 'Restaurant deactivated.');
      }
    } catch (e) {
      if (mounted) _message('Unable to update status: $e');
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> restaurant) async {
    final next = restaurant['is_featured'] != true;

    try {
      await _repository.setRestaurantFeatured(
        restaurantId: restaurant['id'].toString(),
        isFeatured: next,
      );
      await _load();
      if (mounted) {
        _message(
          next
              ? 'Restaurant featured.'
              : 'Restaurant removed from featured.',
        );
      }
    } catch (e) {
      if (mounted) _message('Unable to update featured status: $e');
    }
  }

  void _showDetails(Map<String, dynamic> restaurant) {
    final halal = restaurant['halal_status']?.toString() ?? 'unverified';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant['name']?.toString() ?? 'Restaurant',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                'Owner',
                _ownerName(restaurant['owner_id']?.toString()),
              ),
              _DetailRow('Halal Status', _halalLabel(halal)),
              _DetailRow(
                'Status',
                restaurant['is_active'] == true ? 'Active' : 'Inactive',
              ),
              _DetailRow(
                'Featured',
                restaurant['is_featured'] == true ? 'Yes' : 'No',
              ),
              _DetailRow('Rating', '${restaurant['average_rating'] ?? 0}'),
              _DetailRow('Reviews', '${restaurant['review_count'] ?? 0}'),
              _DetailRow(
                'Phone',
                restaurant['phone']?.toString() ?? 'Not provided',
              ),
              _DetailRow(
                'Email',
                restaurant['email']?.toString() ?? 'Not provided',
              ),
              _DetailRow(
                'Address',
                restaurant['address']?.toString() ?? 'Not provided',
              ),
              _DetailRow(
                'City',
                restaurant['city']?.toString() ?? 'Not provided',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _manageRestaurantPhotos(restaurant);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Photos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _assignOwner(restaurant);
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Owner'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _editRestaurant(restaurant);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Restaurant Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addRestaurant,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text(
          'Add Restaurant',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _SummaryCard(restaurants: _restaurants),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _search = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search restaurants or owners...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final item in const [
                              ('All', 'all'),
                              ('Active', 'active'),
                              ('Inactive', 'inactive'),
                              ('Unassigned', 'unassigned'),
                              ('Unverified', 'unverified'),
                            ])
                              _FilterChip(
                                item.$1,
                                item.$2,
                                _filter,
                                (v) => setState(() => _filter = v),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${restaurants.length} restaurant${restaurants.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (restaurants.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 70),
                          child: Center(child: Text('No restaurants found.')),
                        )
                      else
                        ...restaurants.map(_restaurantCard),
                    ],
                  ),
                ),
    );
  }

  Widget _restaurantCard(Map<String, dynamic> r) {
    final halal = r['halal_status']?.toString() ?? 'unverified';
    final active = r['is_active'] == true;
    final featured = r['is_featured'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetails(r),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r['name']?.toString() ?? 'Unnamed Restaurant',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (featured)
                    const Icon(Icons.star_rounded, color: Colors.amber),
                ],
              ),
              if ((r['city']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    r['city'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 7),
              Text(
                'Owner: ${_ownerName(r['owner_id']?.toString())}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge(_halalLabel(halal), _halalColor(halal)),
                  _Badge(
                    active ? 'Active' : 'Inactive',
                    active ? Colors.green : Colors.grey,
                  ),
                  if (featured)
                    _Badge('Featured', Colors.amber.shade800),
                  _Badge(
                    '★ ${r['average_rating'] ?? 0} (${r['review_count'] ?? 0})',
                    Colors.amber.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RestaurantToggleButton(
                      label: active ? 'Active' : 'Inactive',
                      icon: active
                          ? Icons.check_circle_rounded
                          : Icons.pause_circle_outline_rounded,
                      color: active ? Colors.green : Colors.grey.shade700,
                      onPressed: () => _toggleActive(r),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RestaurantToggleButton(
                      label: featured ? 'Featured' : 'Feature',
                      icon: featured
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber.shade800,
                      onPressed: () => _toggleFeatured(r),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RestaurantToggleButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19, color: color),
      label: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> restaurants;

  const _SummaryCard({required this.restaurants});

  @override
  Widget build(BuildContext context) {
    final active = restaurants.where((r) => r['is_active'] == true).length;
    final inactive = restaurants.length - active;
    final verified = restaurants
        .where(
          (r) =>
              r['halal_status'] == 'halal_verified' ||
              r['halal_status'] == 'certified_halal',
        )
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                'Total',
                restaurants.length.toString(),
                Icons.restaurant_rounded,
              ),
            ),
            Expanded(
              child: _Metric(
                'Active',
                active.toString(),
                Icons.check_circle_rounded,
              ),
            ),
            Expanded(
              child: _Metric(
                'Inactive',
                inactive.toString(),
                Icons.pause_circle_rounded,
              ),
            ),
            Expanded(
              child: _Metric(
                'Halal',
                verified.toString(),
                Icons.verified_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: HalalFoodTheme.primaryGreen),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: HalalFoodTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RestaurantForm extends StatefulWidget {
  final List<Map<String, dynamic>> owners;
  final AdminRestaurantRepository repository;
  final Map<String, dynamic>? restaurant;

  const _RestaurantForm({
    required this.owners,
    required this.repository,
    this.restaurant,
  });

  @override
  State<_RestaurantForm> createState() => _RestaurantFormState();
}

class _RestaurantFormState extends State<_RestaurantForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _logo = TextEditingController();
  final _cover = TextEditingController();

  String? _ownerId;
  bool _saving = false;

  bool get _editing => widget.restaurant != null;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;

    if (r != null) {
      _name.text = r['name']?.toString() ?? '';
      _description.text = r['description']?.toString() ?? '';
      _phone.text = r['phone']?.toString() ?? '';
      _email.text = r['email']?.toString() ?? '';
      _website.text = r['website']?.toString() ?? '';
      _address.text = r['address']?.toString() ?? '';
      _city.text = r['city']?.toString() ?? '';
      _province.text = r['province']?.toString() ?? '';
      _latitude.text = r['latitude']?.toString() ?? '';
      _longitude.text = r['longitude']?.toString() ?? '';
      _logo.text = r['logo_url']?.toString() ?? '';
      _cover.text = r['cover_image_url']?.toString() ?? '';
      _ownerId = r['owner_id']?.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _phone,
      _email,
      _website,
      _address,
      _city,
      _province,
      _latitude,
      _longitude,
      _logo,
      _cover,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);

    try {
      if (_editing) {
        await widget.repository.updateRestaurant(
          restaurantId: widget.restaurant!['id'].toString(),
          name: _name.text,
          ownerId: _ownerId,
          description: _description.text,
          phone: _phone.text,
          email: _email.text,
          website: _website.text,
          address: _address.text,
          city: _city.text,
          province: _province.text,
          latitude: double.tryParse(_latitude.text.trim()),
          longitude: double.tryParse(_longitude.text.trim()),
          logoUrl: _logo.text,
          coverImageUrl: _cover.text,
        );
      } else {
        await widget.repository.createRestaurant(
          name: _name.text,
          ownerId: _ownerId,
          description: _description.text,
          phone: _phone.text,
          email: _email.text,
          website: _website.text,
          address: _address.text,
          city: _city.text,
          province: _province.text,
          latitude: double.tryParse(_latitude.text.trim()),
          longitude: double.tryParse(_longitude.text.trim()),
          logoUrl: _logo.text,
          coverImageUrl: _cover.text,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to ${_editing ? 'update' : 'add'} restaurant: $e',
          ),
        ),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: type,
        enabled: !_saving,
        decoration: _decoration(label, icon),
        validator: required
            ? (v) => v == null || v.trim().isEmpty
                ? '$label is required.'
                : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing ? 'Edit Restaurant' : 'Add New Restaurant',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _editing
                      ? 'Update restaurant information.'
                      : 'New restaurants are created inactive. You can activate them from the restaurant list.',
                  style: const TextStyle(
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                _field(
                  _name,
                  'Restaurant Name',
                  Icons.restaurant_rounded,
                  required: true,
                ),
                _field(
                  _description,
                  'Description',
                  Icons.description_outlined,
                  maxLines: 3,
                ),
                _field(
                  _phone,
                  'Phone',
                  Icons.phone_outlined,
                  type: TextInputType.phone,
                ),
                _field(
                  _email,
                  'Email',
                  Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                _field(
                  _website,
                  'Website',
                  Icons.language_rounded,
                  type: TextInputType.url,
                ),
                _field(
                  _address,
                  'Address',
                  Icons.location_on_outlined,
                ),
                _field(
                  _city,
                  'City',
                  Icons.location_city_outlined,
                ),
                _field(
                  _province,
                  'Province',
                  Icons.map_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _latitude,
                        'Latitude',
                        Icons.my_location_rounded,
                        type: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        _longitude,
                        'Longitude',
                        Icons.explore_outlined,
                        type: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                _field(
                  _logo,
                  'Logo URL',
                  Icons.image_outlined,
                  type: TextInputType.url,
                ),
                _field(
                  _cover,
                  'Cover Image URL',
                  Icons.photo_library_outlined,
                  type: TextInputType.url,
                ),
                DropdownButtonFormField<String?>(
                  initialValue: _ownerId,
                  isExpanded: true,
                  decoration: _decoration(
                    'Owner Account',
                    Icons.person_outline_rounded,
                  ),
                  hint: const Text('Unassigned'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...widget.owners.map(
                      (owner) => DropdownMenuItem<String?>(
                        value: owner['id']?.toString(),
                        child: Text(
                          owner['full_name']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? owner['full_name'].toString()
                              : 'Restaurant Owner',
                        ),
                      ),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _ownerId = v),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _editing
                                ? Icons.save_rounded
                                : Icons.add_business_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : _editing
                              ? 'Save Changes'
                              : 'Create Restaurant',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerSelectionResult {
  final String? ownerId;

  const _OwnerSelectionResult(this.ownerId);
}

class _OwnerSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> owners;
  final String? initialOwnerId;

  const _OwnerSelectionDialog({
    required this.owners,
    required this.initialOwnerId,
  });

  @override
  State<_OwnerSelectionDialog> createState() => _OwnerSelectionDialogState();
}

class _OwnerSelectionDialogState extends State<_OwnerSelectionDialog> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialOwnerId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Assign Restaurant Owner',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: DropdownButtonFormField<String?>(
        initialValue: _selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Owner account'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Unassigned'),
          ),
          ...widget.owners.map(
            (owner) => DropdownMenuItem<String?>(
              value: owner['id']?.toString(),
              child: Text(
                owner['full_name']?.toString().trim().isNotEmpty == true
                    ? owner['full_name'].toString()
                    : 'Restaurant Owner',
              ),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selected = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _OwnerSelectionResult(_selected),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip(
    this.label,
    this.value,
    this.selected,
    this.onSelected,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
              Icons.error_outline_rounded,
              size: 54,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load restaurants',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
