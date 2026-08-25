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
  String _filter = 'pending';
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

  List<Map<String, dynamic>> get _filteredVerifications {
    if (_filter == 'all') return _verifications;
    return _verifications
        .where((item) => item['status']?.toString() == _filter)
        .toList();
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

  String _statusLabel(String? status) {
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

  Color _statusColor(String? status) {
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

  String _halalStatusLabel(String? status) {
    switch (status) {
      case 'muslim_owned':
        return 'Muslim Owned';
      case 'halal_verified':
        return 'Halal Verified';
      case 'certified_halal':
        return 'Certified Halal';
      case 'unverified':
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
            'Approve Verification',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select the correct halal classification for "$name".'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selected,
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
              Text(
                'This will also update the restaurant halal status.',
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
              label: const Text('Approve'),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _changeRestaurantStatus(
    Map<String, dynamic> restaurant,
  ) async {
    final restaurantId = restaurant['id']?.toString();
    if (restaurantId == null) return;

    var selected = restaurant['halal_status']?.toString() ?? 'unverified';
    final name = restaurant['name']?.toString() ?? 'Restaurant';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Change Halal Status',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Halal Status',
                  border: OutlineInputBorder(),
                ),
                items: AdminRepository.halalStatuses
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted || result == selected && result == restaurant['halal_status']) {
      return;
    }

    try {
      await _repository.setHalalStatus(
        restaurantId: restaurantId,
        halalStatus: result,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name is now ${_halalStatusLabel(result)}.'),
        ),
      );
      await _loadData();
    } catch (e) {
      if (mounted) _showError('Unable to update halal status: $e');
    }
  }

  void _showDetails(Map<String, dynamic> verification) {
    final restaurant = _restaurantFromVerification(verification);
    final name = _restaurantName(verification);
    final status = verification['status']?.toString();

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
                Row(
                  children: [
                    _StatusBadge(
                      label: _statusLabel(status),
                      color: _statusColor(status),
                    ),
                    const SizedBox(width: 8),
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
                _DetailRow(
                  label: 'Phone',
                  value: restaurant['phone']?.toString() ?? 'Not provided',
                ),
                _DetailRow(
                  label: 'Address',
                  value: restaurant['address']?.toString() ?? 'Not provided',
                ),
                if (verification['admin_remarks']?.toString().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Admin Remarks',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(verification['admin_remarks'].toString()),
                ],
                const SizedBox(height: 18),
                if (status == 'pending')
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
                          label: const Text('Approve'),
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
    final items = _filteredVerifications;
    final pending = _verifications.where((v) => v['status'] == 'pending').length;
    final approved = _verifications.where((v) => v['status'] == 'verified').length;
    final rejected = _verifications.where((v) => v['status'] == 'rejected').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: _SummaryCard('Pending', '$pending', Colors.orange, Icons.pending_actions_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _SummaryCard('Approved', '$approved', Colors.green, Icons.verified_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _SummaryCard('Rejected', '$rejected', Colors.redAccent, Icons.cancel_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip('Pending', _filter == 'pending', () => setState(() => _filter = 'pending')),
                _FilterChip('Approved', _filter == 'verified', () => setState(() => _filter = 'verified')),
                _FilterChip('Rejected', _filter == 'rejected', () => setState(() => _filter = 'rejected')),
                _FilterChip('All', _filter == 'all', () => setState(() => _filter = 'all')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${items.length} verification${items.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: HalalFoodTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.verified_outlined, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No verification requests found.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )
          else
            ...items.map(_buildVerificationCard),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final restaurant = _restaurantFromVerification(verification);
    final name = _restaurantName(verification);
    final status = verification['status']?.toString();
    final halalStatus = restaurant['halal_status']?.toString();
    final certificate = verification['certificate_number']?.toString();
    final authority = verification['issuing_authority']?.toString();

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
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: _statusLabel(status), color: _statusColor(status)),
                ],
              ),
              const SizedBox(height: 8),
              _StatusBadge(
                label: _halalStatusLabel(halalStatus),
                color: _halalStatusColor(halalStatus),
              ),
              if (certificate?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Certificate: $certificate', style: const TextStyle(fontSize: 13)),
              ],
              if (authority?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text('Authority: $authority', style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDetails(verification),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View Details'),
                    ),
                  ),
                  if (status == 'pending') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Reject',
                      onPressed: () => _reject(verification),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    IconButton(
                      tooltip: 'Approve',
                      onPressed: () => _approve(verification),
                      icon: const Icon(Icons.check_circle_rounded),
                      color: HalalFoodTheme.primaryGreen,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantStatus() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _restaurants[index];
          final status = restaurant['halal_status']?.toString() ?? 'unverified';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              title: Text(
                restaurant['name']?.toString() ?? 'Unnamed Restaurant',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _StatusBadge(
                  label: _halalStatusLabel(status),
                  color: _halalStatusColor(status),
                ),
              ),
              trailing: IconButton(
                tooltip: 'Edit halal status',
                onPressed: () => _changeRestaurantStatus(restaurant),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip(this.label, this.selected, this.onSelected);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
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
              'Unable to load halal management',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
