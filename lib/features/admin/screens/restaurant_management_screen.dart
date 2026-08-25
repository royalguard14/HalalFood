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

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _filter = 'all';

  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _owners = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getRestaurants(),
        _restaurantRepository.getRestaurantOwners(),
      ]);

      if (!mounted) return;
      setState(() {
        _restaurants = results[0] as List<Map<String, dynamic>>;
        _owners = results[1] as List<Map<String, dynamic>>;
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

  List<Map<String, dynamic>> get _filteredRestaurants {
    return _restaurants.where((restaurant) {
      final name = restaurant['name']?.toString().toLowerCase() ?? '';
      final city = restaurant['city']?.toString().toLowerCase() ?? '';
      final owner = _ownerName(restaurant['owner_id']?.toString()).toLowerCase();
      final halal = restaurant['halal_status']?.toString() ?? '';
      final active = restaurant['is_active'] == true;

      final searchMatches = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          city.contains(_searchQuery) ||
          owner.contains(_searchQuery);

      var filterMatches = true;
      switch (_filter) {
        case 'active':
          filterMatches = active;
          break;
        case 'inactive':
          filterMatches = !active;
          break;
        case 'verified':
          filterMatches = halal == 'verified';
          break;
        case 'unassigned':
          filterMatches = restaurant['owner_id'] == null;
          break;
      }

      return searchMatches && filterMatches;
    }).toList();
  }

  String _ownerName(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) return 'Unassigned';
    final owner = _owners.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id']?.toString() == ownerId,
      orElse: () => null,
    );
    final name = owner?['full_name']?.toString().trim();
    return name == null || name.isEmpty ? 'Owner account' : name;
  }

  Future<void> _showAddRestaurant() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RestaurantFormSheet(
        owners: _owners,
        repository: _restaurantRepository,
      ),
    );

    if (created == true) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant added successfully.')),
      );
    }
  }

  Future<void> _assignOwner(Map<String, dynamic> restaurant) async {
    final restaurantId = restaurant['id']?.toString();
    if (restaurantId == null) return;

    String? selectedOwnerId = restaurant['owner_id']?.toString();

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Assign Restaurant Owner',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: DropdownButtonFormField<String?>(
                value: selectedOwnerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Owner account',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                hint: const Text('Unassigned'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ..._owners.map(
                    (owner) => DropdownMenuItem<String?>(
                      value: owner['id']?.toString(),
                      child: Text(
                        owner['full_name']?.toString().trim().isNotEmpty == true
                            ? owner['full_name'].toString()
                            : 'Restaurant Owner',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedOwnerId = value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, selectedOwnerId),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null && restaurant['owner_id'] != null) return;
    if (result == restaurant['owner_id']?.toString()) return;

    try {
      await _restaurantRepository.assignOwner(
        restaurantId: restaurantId,
        ownerId: result,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'Restaurant owner removed.'
                : 'Restaurant owner assigned.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to assign owner: $e')),
      );
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> restaurant) async {
    final id = restaurant['id']?.toString();
    if (id == null) return;
    final current = restaurant['is_active'] == true;
    try {
      await _repository.setRestaurantActive(
        restaurantId: id,
        isActive: !current,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update status: $e')),
      );
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> restaurant) async {
    final id = restaurant['id']?.toString();
    if (id == null) return;
    try {
      await _repository.setRestaurantFeatured(
        restaurantId: id,
        isFeatured: restaurant['is_featured'] != true,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update featured status: $e')),
      );
    }
  }

  Future<void> _changeHalalStatus(Map<String, dynamic> restaurant) async {
    final id = restaurant['id']?.toString();
    if (id == null) return;
    final current = restaurant['halal_status']?.toString() ?? 'unverified';

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Halal Status'),
        children: [
          for (final value in ['verified', 'pending', 'unverified'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Row(
                children: [
                  Icon(
                    value == 'verified'
                        ? Icons.verified_rounded
                        : value == 'pending'
                            ? Icons.pending_outlined
                            : Icons.help_outline_rounded,
                    color: _halalColor(value),
                  ),
                  const SizedBox(width: 12),
                  Text(_halalLabel(value)),
                  if (value == current) ...[
                    const Spacer(),
                    const Icon(Icons.check_rounded),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null || selected == current) return;
    try {
      await _repository.setHalalStatus(
        restaurantId: id,
        halalStatus: selected,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update halal status: $e')),
      );
    }
  }

  void _showDetails(Map<String, dynamic> restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant['name']?.toString() ?? 'Restaurant',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _DetailRow(label: 'Owner', value: _ownerName(restaurant['owner_id']?.toString())),
                _DetailRow(label: 'Halal Status', value: _halalLabel(restaurant['halal_status']?.toString() ?? 'unverified')),
                _DetailRow(label: 'Status', value: restaurant['is_active'] == true ? 'Active' : 'Inactive'),
                _DetailRow(label: 'Phone', value: restaurant['phone']?.toString() ?? 'Not provided'),
                _DetailRow(label: 'Email', value: restaurant['email']?.toString() ?? 'Not provided'),
                _DetailRow(label: 'Website', value: restaurant['website']?.toString() ?? 'Not provided'),
                _DetailRow(label: 'Address', value: restaurant['address']?.toString() ?? 'Not provided'),
                _DetailRow(label: 'City', value: restaurant['city']?.toString() ?? 'Not provided'),
                _DetailRow(label: 'Province', value: restaurant['province']?.toString() ?? 'Not provided'),
                _DetailRow(label: 'Rating', value: (restaurant['average_rating'] ?? 0).toString()),
                _DetailRow(label: 'Reviews', value: (restaurant['review_count'] ?? 0).toString()),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _assignOwner(restaurant);
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Assign Owner'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _changeHalalStatus(restaurant);
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Manage Halal Status'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = _filteredRestaurants;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Restaurant Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddRestaurant,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Restaurant'),
      ),
      body: _buildBody(restaurants),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> restaurants) {
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
              const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Unable to load restaurants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search restaurants or owners...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: 'All', selected: _filter == 'all', onSelected: () => setState(() => _filter = 'all')),
                _FilterChip(label: 'Active', selected: _filter == 'active', onSelected: () => setState(() => _filter = 'active')),
                _FilterChip(label: 'Inactive', selected: _filter == 'inactive', onSelected: () => setState(() => _filter = 'inactive')),
                _FilterChip(label: 'Verified', selected: _filter == 'verified', onSelected: () => setState(() => _filter = 'verified')),
                _FilterChip(label: 'Unassigned', selected: _filter == 'unassigned', onSelected: () => setState(() => _filter = 'unassigned')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${restaurants.length} restaurant${restaurants.length == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: HalalFoodTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          if (restaurants.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant_outlined, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No restaurants found.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )
          else
            ...restaurants.map(_buildRestaurantCard),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final name = restaurant['name']?.toString() ?? 'Unnamed Restaurant';
    final city = restaurant['city']?.toString() ?? '';
    final halal = restaurant['halal_status']?.toString() ?? 'unverified';
    final active = restaurant['is_active'] == true;
    final featured = restaurant['is_featured'] == true;
    final owner = _ownerName(restaurant['owner_id']?.toString());
    final rating = restaurant['average_rating']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(restaurant),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  if (featured) const Icon(Icons.star_rounded, color: Colors.amber),
                ],
              ),
              if (city.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(city, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: HalalFoodTheme.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(child: Text(owner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusBadge(label: _halalLabel(halal), color: _halalColor(halal)),
                  _StatusBadge(label: active ? 'Active' : 'Inactive', color: active ? Colors.green : Colors.grey),
                  _StatusBadge(label: '★ $rating', color: Colors.amber.shade700),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _assignOwner(restaurant),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(restaurant['owner_id'] == null ? 'Assign Owner' : 'Change Owner'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: active ? 'Deactivate' : 'Activate',
                    onPressed: () => _toggleActive(restaurant),
                    icon: Icon(active ? Icons.block_rounded : Icons.check_circle_outline_rounded),
                  ),
                  IconButton(
                    tooltip: featured ? 'Remove featured' : 'Feature',
                    onPressed: () => _toggleFeatured(restaurant),
                    icon: Icon(featured ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _halalLabel(String value) {
    switch (value) {
      case 'verified':
        return 'Halal Verified';
      case 'pending':
        return 'Pending';
      default:
        return 'Unverified';
    }
  }

  Color _halalColor(String value) {
    switch (value) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _RestaurantFormSheet extends StatefulWidget {
  final List<Map<String, dynamic>> owners;
  final AdminRestaurantRepository repository;

  const _RestaurantFormSheet({
    required this.owners,
    required this.repository,
  });

  @override
  State<_RestaurantFormSheet> createState() => _RestaurantFormSheetState();
}

class _RestaurantFormSheetState extends State<_RestaurantFormSheet> {
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
  String _halalStatus = 'unverified';
  bool _isActive = true;
  bool _isFeatured = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
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
      controller.dispose();
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
        halalStatus: _halalStatus,
        isActive: _isActive,
        isFeatured: _isFeatured,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add restaurant: $e')),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _decoration(label, icon),
        validator: required
            ? (value) => value == null || value.trim().isEmpty ? '$label is required.' : null
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
                const Text('Add New Restaurant', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Create the restaurant first. Halal verification can be managed separately.', style: TextStyle(color: HalalFoodTheme.textSecondary)),
                const SizedBox(height: 20),
                _field(_name, 'Restaurant Name', Icons.restaurant_rounded, required: true),
                _field(_description, 'Description', Icons.description_outlined, maxLines: 3),
                _field(_phone, 'Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
                _field(_email, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                _field(_website, 'Website', Icons.language_rounded, keyboardType: TextInputType.url),
                _field(_address, 'Address', Icons.location_on_outlined),
                _field(_city, 'City', Icons.location_city_outlined),
                _field(_province, 'Province', Icons.map_outlined),
                Row(
                  children: [
                    Expanded(child: _field(_latitude, 'Latitude', Icons.my_location_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_longitude, 'Longitude', Icons.explore_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  ],
                ),
                _field(_logo, 'Logo URL', Icons.image_outlined, keyboardType: TextInputType.url),
                _field(_cover, 'Cover Image URL', Icons.photo_library_outlined, keyboardType: TextInputType.url),
                DropdownButtonFormField<String?>(
                  value: _ownerId,
                  isExpanded: true,
                  decoration: _decoration('Owner Account', Icons.person_outline_rounded),
                  hint: const Text('Unassigned'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    ...widget.owners.map((owner) => DropdownMenuItem<String?>(
                          value: owner['id']?.toString(),
                          child: Text(owner['full_name']?.toString().trim().isNotEmpty == true ? owner['full_name'].toString() : 'Restaurant Owner'),
                        )),
                  ],
                  onChanged: _saving ? null : (value) => setState(() => _ownerId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _halalStatus,
                  decoration: _decoration('Halal Status', Icons.verified_outlined),
                  items: const [
                    DropdownMenuItem(value: 'unverified', child: Text('Unverified')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'verified', child: Text('Verified')),
                  ],
                  onChanged: _saving ? null : (value) {
                    if (value != null) setState(() => _halalStatus = value);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Restaurant can appear as active on the platform.'),
                  value: _isActive,
                  onChanged: _saving ? null : (value) => setState(() => _isActive = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  subtitle: const Text('Highlight this restaurant in featured sections.'),
                  value: _isFeatured,
                  onChanged: _saving ? null : (value) => setState(() => _isFeatured = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_business_rounded),
                    label: Text(_saving ? 'Creating...' : 'Create Restaurant'),
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
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onSelected()),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
