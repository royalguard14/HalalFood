import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';

class HalalVerificationScreen extends StatefulWidget {
  const HalalVerificationScreen({super.key});

  @override
  State<HalalVerificationScreen> createState() =>
      _HalalVerificationScreenState();
}

class _HalalVerificationScreenState extends State<HalalVerificationScreen>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _verifications = [];
  List<Map<String, dynamic>> _restaurants = [];

  static const _positiveStatuses = <String>[
    'muslim_owned',
    'halal_verified',
    'certified_halal',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        _repository.getHalalVerifications(),
        _repository.getRestaurants(),
      ]);

      if (!mounted) return;
      setState(() {
        _verifications = results[0] as List<Map<String, dynamic>>;
        _restaurants = results[1] as List<Map<String, dynamic>>;
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

  Map<String, dynamic> _restaurantFromVerification(
    Map<String, dynamic> verification,
  ) {
    final value = verification['restaurants'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    final restaurantId = verification['restaurant_id']?.toString();
    for (final restaurant in _restaurants) {
      if (restaurant['id']?.toString() == restaurantId) return restaurant;
    }
    return <String, dynamic>{};
  }

  String _restaurantName(Map<String, dynamic> verification) {
    return _restaurantFromVerification(verification)['name']?.toString() ??
        'Unnamed Restaurant';
  }

  String _halalStatusLabel(String? status) {
    switch (status) {
      case 'muslim_owned':
        return 'Muslim Owned';
      case 'halal_verified':
        return 'Halal Verified';
      case 'certified_halal':
        return 'Certified Halal';
      default:
        return 'Unverified';
    }
  }

  Color _halalStatusColor(String? status) {
    switch (status) {
      case 'muslim_owned':
        return Colors.blue;
      case 'halal_verified':
        return Colors.green;
      case 'certified_halal':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  String _requestStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'verified':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status?.isNotEmpty == true ? status! : 'Unknown';
    }
  }

  Color _requestStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  // Verification Requests means ONLY an actual pending request from an
  // unverified restaurant. A plain unverified restaurant is not a request.
  List<Map<String, dynamic>> get _pendingRequests {
    return _verifications.where((verification) {
      if (verification['status']?.toString() != 'pending') return false;
      final restaurant = _restaurantFromVerification(verification);
      return restaurant['halal_status']?.toString() == 'unverified';
    }).toList();
  }

  // Restaurant Status is ONLY for active restaurants that already received
  // a positive halal classification. Unverified and inactive restaurants are
  // intentionally excluded from this list.
  List<Map<String, dynamic>> get _approvedRestaurants {
    return _restaurants.where((restaurant) {
      final active = restaurant['is_active'] == true;
      final halalStatus = restaurant['halal_status']?.toString();
      return active && _positiveStatuses.contains(halalStatus);
    }).toList();
  }

  Future<void> _approve(Map<String, dynamic> verification) async {
    final verificationId = verification['id']?.toString();
    final restaurantId = verification['restaurant_id']?.toString();
    if (verificationId == null || restaurantId == null) return;

    final selectedStatus = await _showApprovalDialog(verification);
    if (selectedStatus == null || !mounted) return;

    final name = _restaurantName(verification);
    try {
      await _repository.approveHalalVerification(
        verificationId: verificationId,
        restaurantId: restaurantId,
        halalStatus: selectedStatus,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name is now ${_halalStatusLabel(selectedStatus)}.',
          ),
        ),
      );
      await _loadData();
    } catch (e) {
      if (mounted) _showError('Unable to approve verification: $e');
    }
  }

  Future<void> _reject(Map<String, dynamic> verification) async {
    final verificationId = verification['id']?.toString();
    final restaurantId = verification['restaurant_id']?.toString();
    if (verificationId == null || restaurantId == null) return;

    final name = _restaurantName(verification);
    final remarks = await _showRejectDialog(name);
    if (remarks == null || !mounted) return;

    try {
      await _repository.rejectHalalVerification(
        verificationId: verificationId,
        restaurantId: restaurantId,
        remarks: remarks.trim().isEmpty ? null : remarks.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name verification was rejected.')),
      );
      await _loadData();
    } catch (e) {
      if (mounted) _showError('Unable to reject verification: $e');
    }
  }

  Future<String?> _showApprovalDialog(
    Map<String, dynamic> verification,
  ) async {
    var selected = 'halal_verified';
    final name = _restaurantName(verification);

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Give Halal Classification',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the final classification for "$name" after reviewing the submitted documents.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selected,
                decoration: const InputDecoration(
                  labelText: 'Halal Status',
                  border: OutlineInputBorder(),
                ),
                items: _positiveStatuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_halalStatusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'The restaurant will remain inactive if it is currently inactive. Restaurant Status only shows active halal-approved restaurants.',
                style: TextStyle(
                  fontSize: 12,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, selected),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Save Decision'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showRejectDialog(String restaurantName) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reject Verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why is "$restaurantName" being rejected?'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                hintText: 'Enter the reason for rejection',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, controller.text),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showDetails(Map<String, dynamic> verification) {
    final restaurant = _restaurantFromVerification(verification);
    final name = _restaurantName(verification);
    final requestStatus = verification['status']?.toString();
    final documentUrl = verification['certificate_url']?.toString().trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusBadge(
                      label: _requestStatusLabel(requestStatus),
                      color: _requestStatusColor(requestStatus),
                    ),
                    _StatusBadge(
                      label: _halalStatusLabel(
                        restaurant['halal_status']?.toString(),
                      ),
                      color: _halalStatusColor(
                        restaurant['halal_status']?.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Restaurant Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Phone',
                  value: restaurant['phone']?.toString() ?? 'Not provided',
                ),
                _DetailRow(
                  label: 'Address',
                  value: restaurant['address']?.toString() ?? 'Not provided',
                ),
                _DetailRow(
                  label: 'City',
                  value: restaurant['city']?.toString() ?? 'Not provided',
                ),
                _DetailRow(
                  label: 'Province',
                  value: restaurant['province']?.toString() ?? 'Not provided',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submitted Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Certificate Number',
                  value: verification['certificate_number']?.toString() ??
                      'Not provided',
                ),
                _DetailRow(
                  label: 'Issuing Authority',
                  value: verification['issuing_authority']?.toString() ??
                      'Not provided',
                ),
                _DetailRow(
                  label: 'Issued Date',
                  value: _displayDate(verification['issued_date']),
                ),
                _DetailRow(
                  label: 'Expiry Date',
                  value: _displayDate(verification['expiry_date']),
                ),
                if (documentUrl != null && documentUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HalalFoodTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: SelectableText(
                      documentUrl,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Document URL is shown above. Open it from the Supabase storage link to inspect the submitted file.',
                    style: TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                    ),
                  ),
                ] else
                  const Text(
                    'No document URL was submitted.',
                    style: TextStyle(color: HalalFoodTheme.textSecondary),
                  ),
                if (verification['admin_remarks']?.toString().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Admin Remarks',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(verification['admin_remarks'].toString()),
                ],
                const SizedBox(height: 20),
                if (requestStatus == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _reject(verification);
                          },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _approve(verification);
                          },
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Give Decision'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return 'Not provided';
    return text.split('T').first;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Halal Verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Verification Requests'),
            Tab(text: 'Restaurant Status'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequests(),
                    _buildRestaurantStatus(),
                  ],
                ),
    );
  }

  Widget _buildRequests() {
    final requests = _pendingRequests;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SummaryCard(
            'Pending Verification Requests',
            '${requests.length}',
            Colors.orange,
            Icons.pending_actions_rounded,
          ),
          const SizedBox(height: 16),
          const Text(
            'Only restaurants that are Unverified and have actually submitted a verification request appear here.',
            style: TextStyle(
              color: HalalFoodTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No verification requests found.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            )
          else
            ...requests.map(_buildVerificationCard),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final restaurant = _restaurantFromVerification(verification);
    final name = _restaurantName(verification);
    final certificate = verification['certificate_number']?.toString();
    final authority = verification['issuing_authority']?.toString();
    final documentUrl = verification['certificate_url']?.toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(verification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _StatusBadge(
                    label: 'Pending Review',
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _StatusBadge(
                label: 'Unverified',
                color: Colors.grey,
              ),
              if ((restaurant['address']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  restaurant['address'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (certificate?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Certificate: $certificate',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (authority?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Authority: $authority',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    documentUrl?.isNotEmpty == true
                        ? Icons.description_rounded
                        : Icons.description_outlined,
                    size: 18,
                    color: documentUrl?.isNotEmpty == true
                        ? HalalFoodTheme.primaryGreen
                        : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    documentUrl?.isNotEmpty == true
                        ? 'Document submitted'
                        : 'No document URL',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDetails(verification),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Review Documents & Decide'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantStatus() {
    final restaurants = _approvedRestaurants;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '${restaurants.length} active halal-approved restaurant${restaurants.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: HalalFoodTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Only Active restaurants with Muslim Owned, Halal Verified, or Certified Halal status are shown here.',
            style: TextStyle(
              color: HalalFoodTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          if (restaurants.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant_outlined, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No active halal-approved restaurants found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            )
          else
            ...restaurants.map((restaurant) {
              final status = restaurant['halal_status']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  title: Text(
                    restaurant['name']?.toString() ?? 'Unnamed Restaurant',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _StatusBadge(
                          label: _halalStatusLabel(status),
                          color: _halalStatusColor(status),
                        ),
                        const _StatusBadge(
                          label: 'Active',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HalalFoodTheme.textSecondary,
                    ),
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HalalFoodTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Unable to load halal verification',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
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
