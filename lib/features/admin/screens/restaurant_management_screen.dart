import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';

class RestaurantManagementScreen extends StatefulWidget {
  const RestaurantManagementScreen({
    super.key,
  });

  @override
  State<RestaurantManagementScreen> createState() =>
      _RestaurantManagementScreenState();
}

class _RestaurantManagementScreenState
    extends State<RestaurantManagementScreen> {
  final _repository = AdminRepository();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _restaurants = [];

  String _searchQuery = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadRestaurants() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final restaurants =
          await _repository.getRestaurants();

      if (!mounted) return;

      setState(() {
        _restaurants = restaurants;
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
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredRestaurants {
    return _restaurants.where((restaurant) {
      final name =
          restaurant['name']?.toString().toLowerCase() ?? '';

      final city =
          restaurant['city']?.toString().toLowerCase() ?? '';

      final halalStatus =
          restaurant['halal_status']?.toString() ?? '';

      final isActive =
          restaurant['is_active'] == true;

      final matchesSearch =
          _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          city.contains(_searchQuery);

      bool matchesFilter = true;

      switch (_filter) {
        case 'active':
          matchesFilter = isActive;
          break;

        case 'inactive':
          matchesFilter = !isActive;
          break;

        case 'verified':
          matchesFilter = halalStatus == 'verified';
          break;

        case 'unverified':
          matchesFilter = halalStatus == 'unverified';
          break;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // ============================================================
  // RESTAURANT ACTIONS
  // ============================================================

  Future<void> _toggleActive(
    Map<String, dynamic> restaurant,
  ) async {
    final id = restaurant['id']?.toString();

    if (id == null) return;

    final current =
        restaurant['is_active'] == true;

    try {
      await _repository.setRestaurantActive(
        restaurantId: id,
        isActive: !current,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !current
                ? 'Restaurant activated.'
                : 'Restaurant deactivated.',
          ),
        ),
      );

      await _loadRestaurants();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update restaurant: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleFeatured(
    Map<String, dynamic> restaurant,
  ) async {
    final id = restaurant['id']?.toString();

    if (id == null) return;

    final current =
        restaurant['is_featured'] == true;

    try {
      await _repository.setRestaurantFeatured(
        restaurantId: id,
        isFeatured: !current,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !current
                ? 'Restaurant featured.'
                : 'Restaurant removed from featured.',
          ),
        ),
      );

      await _loadRestaurants();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update featured status: $e',
          ),
        ),
      );
    }
  }

  Future<void> _changeHalalStatus(
    Map<String, dynamic> restaurant,
  ) async {
    final id = restaurant['id']?.toString();

    if (id == null) return;

    final currentStatus =
        restaurant['halal_status']?.toString() ??
            'unverified';

    final selected =
        await showDialog<String>(
      context: context,
      builder: (context) {
        String selectedStatus = currentStatus;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Halal Status',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
       content: RadioGroup<String>(
  groupValue: selectedStatus,
  onChanged: (value) {
    if (value == null) return;

    setDialogState(() {
      selectedStatus = value;
    });
  },
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RadioListTile<String>(
        value: 'verified',
        title: const Text('Verified'),
      ),
      RadioListTile<String>(
        value: 'unverified',
        title: const Text('Unverified'),
      ),
      RadioListTile<String>(
        value: 'pending',
        title: const Text('Pending'),
      ),
    ],
  ),
),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      selectedStatus,
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null ||
        selected == currentStatus) {
      return;
    }

    try {
      await _repository.setHalalStatus(
        restaurantId: id,
        halalStatus: selected,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Halal status changed to $selected.',
          ),
        ),
      );

      await _loadRestaurants();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update halal status: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _showDetails(
    Map<String, dynamic> restaurant,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              30,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant['name']?.toString() ??
                        'Restaurant',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _DetailRow(
                    label: 'Halal Status',
                    value:
                        restaurant['halal_status']
                                ?.toString() ??
                            'Unknown',
                  ),

                  _DetailRow(
                    label: 'Status',
                    value:
                        restaurant['is_active'] == true
                            ? 'Active'
                            : 'Inactive',
                  ),

                  _DetailRow(
                    label: 'Featured',
                    value:
                        restaurant['is_featured'] == true
                            ? 'Yes'
                            : 'No',
                  ),

                  _DetailRow(
                    label: 'Phone',
                    value:
                        restaurant['phone']
                                ?.toString() ??
                            'Not provided',
                  ),

                  _DetailRow(
                    label: 'Email',
                    value:
                        restaurant['email']
                                ?.toString() ??
                            'Not provided',
                  ),

                  _DetailRow(
                    label: 'Address',
                    value:
                        restaurant['address']
                                ?.toString() ??
                            'Not provided',
                  ),

                  _DetailRow(
                    label: 'City',
                    value:
                        restaurant['city']
                                ?.toString() ??
                            'Not provided',
                  ),

                  _DetailRow(
                    label: 'Province',
                    value:
                        restaurant['province']
                                ?.toString() ??
                            'Not provided',
                  ),

                  _DetailRow(
                    label: 'Rating',
                    value:
                        restaurant['average_rating']
                                ?.toString() ??
                            '0',
                  ),

                  _DetailRow(
                    label: 'Reviews',
                    value:
                        restaurant['review_count']
                                ?.toString() ??
                            '0',
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _changeHalalStatus(
                          restaurant,
                        );
                      },
                      child: const Text(
                        'Manage Halal Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final restaurants =
        _filteredRestaurants;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Restaurant Management',
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
                    : _loadRestaurants,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _buildBody(restaurants),
    );
  }

  Widget _buildBody(
    List<Map<String, dynamic>> restaurants,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
                'Unable to load restaurants',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRestaurants,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery =
                    value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search restaurants...',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(
                            Icons.clear_rounded,
                          ),
                        )
                      : null,
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection:
                  Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected:
                      _filter == 'all',
                  onSelected: () {
                    setState(() {
                      _filter = 'all';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Active',
                  selected:
                      _filter == 'active',
                  onSelected: () {
                    setState(() {
                      _filter = 'active';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Inactive',
                  selected:
                      _filter == 'inactive',
                  onSelected: () {
                    setState(() {
                      _filter = 'inactive';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Verified',
                  selected:
                      _filter == 'verified',
                  onSelected: () {
                    setState(() {
                      _filter = 'verified';
                    });
                  },
                ),
                _FilterChip(
                  label: 'Unverified',
                  selected:
                      _filter == 'unverified',
                  onSelected: () {
                    setState(() {
                      _filter = 'unverified';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            '${restaurants.length} restaurant${restaurants.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  HalalFoodTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 10),

          if (restaurants.isEmpty)
            const Padding(
              padding: EdgeInsets.only(
                top: 70,
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No restaurants found.',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...restaurants.map(
              _buildRestaurantCard,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // RESTAURANT CARD
  // ============================================================

  Widget _buildRestaurantCard(
    Map<String, dynamic> restaurant,
  ) {
    final name =
        restaurant['name']?.toString() ??
            'Unnamed Restaurant';

    final city =
        restaurant['city']?.toString() ??
            '';

    final halalStatus =
        restaurant['halal_status']?.toString() ??
            'unverified';

    final isActive =
        restaurant['is_active'] == true;

    final isFeatured =
        restaurant['is_featured'] == true;

    final rating =
        restaurant['average_rating']?.toString() ??
            '0';

    final imageUrl =
        restaurant['logo_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () => _showDetails(
          restaurant,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _RestaurantImage(
                imageUrl: imageUrl,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isFeatured)
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                      ],
                    ),

                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        city,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              HalalFoodTheme
                                  .textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(
                          label:
                              _halalLabel(
                            halalStatus,
                          ),
                          color:
                              _halalColor(
                            halalStatus,
                          ),
                        ),
                        _StatusBadge(
                          label:
                              isActive
                                  ? 'Active'
                                  : 'Inactive',
                          color:
                              isActive
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        _StatusBadge(
                          label:
                              '★ $rating',
                          color:
                              Colors.amber.shade700,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _toggleActive(
                              restaurant,
                            ),
                            icon: Icon(
                              isActive
                                  ? Icons
                                      .block_rounded
                                  : Icons
                                      .check_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              isActive
                                  ? 'Deactivate'
                                  : 'Activate',
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        IconButton(
                          tooltip:
                              isFeatured
                                  ? 'Remove featured'
                                  : 'Feature',
                          onPressed: () =>
                              _toggleFeatured(
                            restaurant,
                          ),
                          icon: Icon(
                            isFeatured
                                ? Icons
                                    .star_rounded
                                : Icons
                                    .star_border_rounded,
                            color:
                                Colors.amber.shade700,
                          ),
                        ),

                        IconButton(
                          tooltip:
                              'Halal status',
                          onPressed: () =>
                              _changeHalalStatus(
                            restaurant,
                          ),
                          icon: const Icon(
                            Icons.verified_outlined,
                          ),
                        ),
                      ],
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

  String _halalLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Halal Verified';

      case 'pending':
        return 'Pending';

      case 'unverified':
        return 'Unverified';

      default:
        return status;
    }
  }

  Color _halalColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'unverified':
        return Colors.grey;

      default:
        return Colors.blueGrey;
    }
  }
}

// ============================================================
// IMAGE
// ============================================================

class _RestaurantImage extends StatelessWidget {
  final String? imageUrl;

  const _RestaurantImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        width: 82,
        height: 82,
        color:
            HalalFoodTheme.primaryGreen
                .withValues(alpha: 0.08),
        child:
            imageUrl != null &&
                    imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) =>
                            const Icon(
                      Icons.restaurant_rounded,
                      size: 34,
                      color:
                          HalalFoodTheme
                              .primaryGreen,
                    ),
                  )
                : const Icon(
                    Icons.restaurant_rounded,
                    size: 34,
                    color:
                        HalalFoodTheme
                            .primaryGreen,
                  ),
      ),
    );
  }
}

// ============================================================
// FILTER CHIP
// ============================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          onSelected();
        },
      ),
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(8),
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

// ============================================================
// DETAIL ROW
// ============================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}