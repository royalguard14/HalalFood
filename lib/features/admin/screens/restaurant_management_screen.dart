import 'package:flutter/material.dart';

import '../../../app/theme.dart';
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
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repository.getRestaurants(),
        _restaurantRepository.getRestaurantOwners(),
      ]);
      if (!mounted) return;
      setState(() {
        _restaurants = results[0] as List<Map<String, dynamic>>;
        _owners = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
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
      final name = r['name']?.toString().toLowerCase() ?? '';
      final city = r['city']?.toString().toLowerCase() ?? '';
      final owner = _ownerName(r['owner_id']?.toString()).toLowerCase();
      final active = r['is_active'] == true;
      final q = _search.toLowerCase();

      final matchesSearch = q.isEmpty ||
          name.contains(q) || city.contains(q) || owner.contains(q);

      final matchesFilter = switch (_filter) {
        'active' => active,
        'inactive' => !active,
        'unassigned' => r['owner_id'] == null,
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
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RestaurantForm(
        owners: _owners,
        repository: _restaurantRepository,
      ),
    );
    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant added successfully.')),
        );
      }
    }
  }

  Future<void> _assignOwner(Map<String, dynamic> restaurant) async {
    String? selected = restaurant['owner_id']?.toString();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Restaurant Owner'),
          content: DropdownButtonFormField<String?>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Owner account'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Unassigned'),
              ),
              ..._owners.map((owner) => DropdownMenuItem<String?>(
                    value: owner['id']?.toString(),
                    child: Text(
                      owner['full_name']?.toString().trim().isNotEmpty == true
                          ? owner['full_name'].toString()
                          : 'Restaurant Owner',
                    ),
                  )),
            ],
            onChanged: (value) => setDialogState(() => selected = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final old = restaurant['owner_id']?.toString();
    if (result == null && old != null) return;
    if (result == old) return;

    try {
      await _restaurantRepository.assignOwner(
        restaurantId: restaurant['id'].toString(),
        ownerId: result,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to assign owner: $e')),
        );
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> restaurant) async {
    try {
      await _repository.setRestaurantActive(
        restaurantId: restaurant['id'].toString(),
        isActive: restaurant['is_active'] != true,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update status: $e')),
        );
      }
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> restaurant) async {
    try {
      await _repository.setRestaurantFeatured(
        restaurantId: restaurant['id'].toString(),
        isFeatured: restaurant['is_featured'] != true,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update featured status: $e')),
        );
      }
    }
  }

  void _showDetails(Map<String, dynamic> restaurant) {
    final halal = restaurant['halal_status']?.toString() ?? 'unverified';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
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
              const SizedBox(height: 12),
              _DetailRow(
                'Owner',
                _ownerName(restaurant['owner_id']?.toString()),
              ),
              _DetailRow('Halal Status', _halalLabel(halal)),
              _DetailRow(
                'Status',
                restaurant['is_active'] == true ? 'Active' : 'Inactive',
              ),
              _DetailRow('Rating', '${restaurant['average_rating'] ?? 0}'),
              _DetailRow('Reviews', '${restaurant['review_count'] ?? 0}'),
              _DetailRow(
                'Address',
                restaurant['address']?.toString() ?? 'Not provided',
              ),
              _DetailRow(
                'City',
                restaurant['city']?.toString() ?? 'Not provided',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _assignOwner(restaurant);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Assign Owner'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addRestaurant,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Restaurant'),
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
                            _FilterChip(
                              'All',
                              'all',
                              _filter,
                              (v) => setState(() => _filter = v),
                            ),
                            _FilterChip(
                              'Active',
                              'active',
                              _filter,
                              (v) => setState(() => _filter = v),
                            ),
                            _FilterChip(
                              'Inactive',
                              'inactive',
                              _filter,
                              (v) => setState(() => _filter = v),
                            ),
                            _FilterChip(
                              'Unassigned',
                              'unassigned',
                              _filter,
                              (v) => setState(() => _filter = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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
    final rating = r['average_rating'] ?? 0;
    final reviews = r['review_count'] ?? 0;

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
                  _Badge('★ $rating ($reviews)', Colors.amber.shade700),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _assignOwner(r),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(
                        r['owner_id'] == null
                            ? 'Assign Owner'
                            : 'Change Owner',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _toggleActive(r),
                    icon: Icon(
                      active
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleFeatured(r),
                    icon: Icon(
                      featured
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber.shade700,
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

class _RestaurantForm extends StatefulWidget {
  final List<Map<String, dynamic>> owners;
  final AdminRestaurantRepository repository;

  const _RestaurantForm({
    required this.owners,
    required this.repository,
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
  bool _active = true;
  bool _featured = false;
  bool _saving = false;

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
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
        isActive: _active,
        isFeatured: _featured,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add restaurant: $e')),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon));

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: type,
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
                const Text(
                  'Add New Restaurant',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create the restaurant first. Halal verification is managed separately.',
                  style: TextStyle(color: HalalFoodTheme.textSecondary),
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
                _field(_address, 'Address', Icons.location_on_outlined),
                _field(_city, 'City', Icons.location_city_outlined),
                _field(_province, 'Province', Icons.map_outlined),
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
                  value: _ownerId,
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
                          owner['full_name']?.toString().trim().isNotEmpty == true
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _active = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  value: _featured,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _featured = v),
                ),
                const SizedBox(height: 12),
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
                        : const Icon(Icons.add_business_rounded),
                    label: Text(
                      _saving ? 'Creating...' : 'Create Restaurant',
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 105,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
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
