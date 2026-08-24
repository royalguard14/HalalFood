import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';

class HalalVerificationScreen extends StatefulWidget {
  const HalalVerificationScreen({
    super.key,
  });

  @override
  State<HalalVerificationScreen> createState() =>
      _HalalVerificationScreenState();
}

class _HalalVerificationScreenState
    extends State<HalalVerificationScreen> {
  final _repository = AdminRepository();

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _restaurants = [];

  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
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
      final status =
          restaurant['halal_status']?.toString() ??
              'unverified';

      if (_filter == 'all') {
        return true;
      }

      return status == _filter;
    }).toList();
  }

  // ============================================================
  // CHANGE STATUS
  // ============================================================

  Future<void> _changeStatus(
    Map<String, dynamic> restaurant,
    String newStatus,
  ) async {
    final id = restaurant['id']?.toString();

    if (id == null) return;

    final name =
        restaurant['name']?.toString() ??
            'Restaurant';

    try {
      await _repository.setHalalStatus(
        restaurantId: id,
        halalStatus: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name is now ${_statusLabel(newStatus)}.',
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
  // CONFIRM ACTION
  // ============================================================

  Future<void> _confirmStatusChange(
    Map<String, dynamic> restaurant,
    String newStatus,
  ) async {
    final name =
        restaurant['name']?.toString() ??
            'Restaurant';

    final isVerifying = newStatus == 'verified';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isVerifying
                ? 'Verify Restaurant?'
                : 'Mark as Unverified?',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            isVerifying
                ? 'Are you sure you want to mark "$name" as Halal Verified?'
                : 'Are you sure you want to mark "$name" as Unverified?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text(
                isVerifying
                    ? 'Verify'
                    : 'Confirm',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _changeStatus(
      restaurant,
      newStatus,
    );
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _showDetails(
    Map<String, dynamic> restaurant,
  ) {
    final name =
        restaurant['name']?.toString() ??
            'Restaurant';

    final status =
        restaurant['halal_status']?.toString() ??
            'unverified';

    final imageUrl =
        restaurant['logo_url']?.toString();

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
                  Row(
                    children: [
                      _RestaurantImage(
                        imageUrl: imageUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _DetailRow(
                    label: 'Halal Status',
                    value:
                        _statusLabel(status),
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

                  const SizedBox(height: 22),

                  if (status != 'verified')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);

                          _confirmStatusChange(
                            restaurant,
                            'verified',
                          );
                        },
                        icon: const Icon(
                          Icons.verified_rounded,
                        ),
                        label: const Text(
                          'Verify Restaurant',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                  if (status == 'verified')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);

                          _confirmStatusChange(
                            restaurant,
                            'unverified',
                          );
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                        label: const Text(
                          'Mark as Unverified',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
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
          'Halal Verification',
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
                textAlign: TextAlign.center,
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
          _buildSummary(),

          const SizedBox(height: 18),

          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Pending',
                  selected:
                      _filter == 'pending',
                  onSelected: () {
                    setState(() {
                      _filter = 'pending';
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
                  label: 'All',
                  selected:
                      _filter == 'all',
                  onSelected: () {
                    setState(() {
                      _filter = 'all';
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
              padding: EdgeInsets.only(top: 70),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_outlined,
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
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final pending =
        _restaurants.where(
      (restaurant) =>
          restaurant['halal_status'] ==
          'pending',
    ).length;

    final verified =
        _restaurants.where(
      (restaurant) =>
          restaurant['halal_status'] ==
          'verified',
    ).length;

    final unverified =
        _restaurants.where(
      (restaurant) =>
          restaurant['halal_status'] ==
          'unverified',
    ).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Pending',
            value: pending.toString(),
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Verified',
            value: verified.toString(),
            icon: Icons.verified_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Unverified',
            value: unverified.toString(),
            icon: Icons.cancel_outlined,
            color: Colors.grey,
          ),
        ),
      ],
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
        restaurant['city']?.toString() ?? '';

    final status =
        restaurant['halal_status']?.toString() ??
            'unverified';

    final imageUrl =
        restaurant['logo_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _showDetails(restaurant);
        },
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
                    Text(
                      name,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),

                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        city,
                        style: const TextStyle(
                          fontSize: 12,
                          color:
                              HalalFoodTheme
                                  .textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    _StatusBadge(
                      label:
                          _statusLabel(status),
                      color:
                          _statusColor(status),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child:
                              OutlinedButton.icon(
                            onPressed: () {
                              _showDetails(
                                restaurant,
                              );
                            },
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Review',
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        if (status != 'verified')
                          IconButton(
                            tooltip: 'Verify',
                            onPressed: () {
                              _confirmStatusChange(
                                restaurant,
                                'verified',
                              );
                            },
                            icon: const Icon(
                              Icons.verified_rounded,
                              color: Colors.green,
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

  // ============================================================
  // HELPERS
  // ============================================================

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Halal Verified';

      case 'pending':
        return 'Pending Verification';

      case 'unverified':
        return 'Unverified';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
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
// SUMMARY CARD
// ============================================================

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
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
        width: 78,
        height: 78,
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
                      size: 32,
                      color:
                          HalalFoodTheme
                              .primaryGreen,
                    ),
                  )
                : const Icon(
                    Icons.restaurant_rounded,
                    size: 32,
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

