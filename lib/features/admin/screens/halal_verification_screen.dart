import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';

class HalalVerificationScreen extends StatefulWidget {
  const HalalVerificationScreen({super.key});

  @override
  State<HalalVerificationScreen> createState() => _HalalVerificationScreenState();
}

class _HalalVerificationScreenState extends State<HalalVerificationScreen>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();
  late final TabController _tabController;

  bool _loading = true;
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _repository.getHalalVerifications(),
        _repository.getRestaurants(),
      ]);

      if (!mounted) return;
      setState(() {
        _verifications = results[0];
        _restaurants = results[1];
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

  Map<String, dynamic> _restaurantForVerification(Map<String, dynamic> verification) {
    final nested = verification['restaurants'];
    if (nested is Map) return Map<String, dynamic>.from(nested);

    final id = verification['restaurant_id']?.toString();
    for (final restaurant in _restaurants) {
      if (restaurant['id']?.toString() == id) return restaurant;
    }
    return <String, dynamic>{};
  }

  String _restaurantName(Map<String, dynamic> verification) {
    return _restaurantForVerification(verification)['name']?.toString() ??
        'Unnamed Restaurant';
  }

  String _statusLabel(String? status) {
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

  Color _statusColor(String? status) {
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

  List<Map<String, dynamic>> get _pendingRequests {
    return _verifications.where((verification) {
      if (verification['status']?.toString() != 'pending') return false;
      final restaurant = _restaurantForVerification(verification);
      return restaurant['halal_status']?.toString() == 'unverified';
    }).toList();
  }

  List<Map<String, dynamic>> get _restaurantStatuses {
    return _restaurants.where((restaurant) {
      final active = restaurant['is_active'] == true;
      final status = restaurant['halal_status']?.toString();
      return active && _positiveStatuses.contains(status);
    }).toList();
  }

  Future<void> _editStatus(Map<String, dynamic> restaurant) async {
    final restaurantId = restaurant['id']?.toString();
    if (restaurantId == null || restaurantId.isEmpty) return;

    String? selected = restaurant['halal_status']?.toString();
    if (!_positiveStatuses.contains(selected)) selected = 'halal_verified';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Halal Status', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurant['name']?.toString() ?? 'Restaurant', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Halal Status', border: OutlineInputBorder()),
                items: _positiveStatuses.map((status) => DropdownMenuItem<String>(value: status, child: Text(_statusLabel(status)))).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Only positive halal classifications can be selected here. Unverified restaurants belong in Verification Requests.',
                style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: selected == null ? null : () => Navigator.pop(context, selected),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == restaurant['halal_status']?.toString()) return;

    try {
      await _repository.setHalalStatus(restaurantId: restaurantId, halalStatus: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${restaurant['name'] ?? 'Restaurant'} is now ${_statusLabel(result)}.')),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update halal status: $e')));
      }
    }
  }

  Future<String?> _chooseApprovalStatus(String restaurantName) {
    String selected = 'halal_verified';

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Give Halal Classification', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose the final classification for "$restaurantName" after reviewing the submitted documents.'),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Halal Status', border: OutlineInputBorder()),
                items: _positiveStatuses.map((status) => DropdownMenuItem<String>(value: status, child: Text(_statusLabel(status)))).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  Future<void> _approve(Map<String, dynamic> verification) async {
    final verificationId = verification['id']?.toString();
    final restaurantId = verification['restaurant_id']?.toString();
    if (verificationId == null || restaurantId == null) return;

    final name = _restaurantName(verification);
    final status = await _chooseApprovalStatus(name);
    if (status == null) return;

    try {
      await _repository.approveHalalVerification(
        verificationId: verificationId,
        restaurantId: restaurantId,
        halalStatus: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name is now ${_statusLabel(status)}.')));
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to approve verification: $e')));
    }
  }

  Future<void> _reject(Map<String, dynamic> verification) async {
    final verificationId = verification['id']?.toString();
    final restaurantId = verification['restaurant_id']?.toString();
    if (verificationId == null || restaurantId == null) return;

    final controller = TextEditingController();
    final remarks = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Verification'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Remarks', hintText: 'Reason for rejection', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(onPressed: () => Navigator.pop(context, controller.text), icon: const Icon(Icons.close_rounded), label: const Text('Reject')),
        ],
      ),
    );
    controller.dispose();
    if (remarks == null) return;

    try {
      await _repository.rejectHalalVerification(
        verificationId: verificationId,
        restaurantId: restaurantId,
        remarks: remarks.trim().isEmpty ? null : remarks.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_restaurantName(verification)} was rejected.')));
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to reject verification: $e')));
    }
  }

  Future<void> _showVerificationDetails(Map<String, dynamic> verification) async {
    final restaurant = _restaurantForVerification(verification);
    final name = _restaurantName(verification);
    final documentUrl = verification['certificate_url']?.toString().trim();

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const _StatusBadge(label: 'Unverified / Pending Review', color: Colors.orange),
                const SizedBox(height: 18),
                const Text('Restaurant Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                _DetailRow('Phone', restaurant['phone']?.toString() ?? 'Not provided'),
                _DetailRow('Address', restaurant['address']?.toString() ?? 'Not provided'),
                _DetailRow('City', restaurant['city']?.toString() ?? 'Not provided'),
                _DetailRow('Province', restaurant['province']?.toString() ?? 'Not provided'),
                const SizedBox(height: 12),
                const Text('Submitted Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                _DetailRow('Certificate No.', verification['certificate_number']?.toString() ?? 'Not provided'),
                _DetailRow('Authority', verification['issuing_authority']?.toString() ?? 'Not provided'),
                _DetailRow('Issued', _displayDate(verification['issued_date'])),
                _DetailRow('Expiry', _displayDate(verification['expiry_date'])),
                const SizedBox(height: 8),
                if (documentUrl != null && documentUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                    child: SelectableText(documentUrl, style: const TextStyle(fontSize: 12)),
                  )
                else
                  const Text('No document URL was submitted.', style: TextStyle(color: HalalFoodTheme.textSecondary)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(sheetContext, 'reject'), icon: const Icon(Icons.close_rounded), label: const Text('Reject'))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.pop(sheetContext, 'decide'), icon: const Icon(Icons.verified_rounded), label: const Text('Decide'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'reject') await _reject(verification);
    if (action == 'decide') await _approve(verification);
  }

  String _displayDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return 'Not provided';
    return text.split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Halal Verification', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Verification Requests'), Tab(text: 'Restaurant Status')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadData)
              : TabBarView(controller: _tabController, children: [_buildVerificationRequests(), _buildRestaurantStatus()]),
    );
  }

  Widget _buildVerificationRequests() {
    final requests = _pendingRequests;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SummaryCard(label: 'Pending Verification Requests', value: '${requests.length}', color: Colors.orange, icon: Icons.pending_actions_rounded),
          const SizedBox(height: 12),
          const Text('Only Unverified restaurants with an actual pending verification request appear here.', style: TextStyle(color: HalalFoodTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          if (requests.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: Text('No verification requests found.', style: TextStyle(fontWeight: FontWeight.w700))))
          else
            ...requests.map(_verificationCard),
        ],
      ),
    );
  }

  Widget _verificationCard(Map<String, dynamic> verification) {
    final restaurant = _restaurantForVerification(verification);
    final document = verification['certificate_url']?.toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showVerificationDetails(verification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(_restaurantName(verification), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  const _StatusBadge(label: 'Pending', color: Colors.orange),
                ],
              ),
              const SizedBox(height: 7),
              Text(restaurant['address']?.toString() ?? 'Address not provided', maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(document?.isNotEmpty == true ? Icons.description_rounded : Icons.description_outlined, size: 18, color: document?.isNotEmpty == true ? HalalFoodTheme.primaryGreen : Colors.grey),
                  const SizedBox(width: 6),
                  Text(document?.isNotEmpty == true ? 'Document submitted' : 'No document URL', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _showVerificationDetails(verification), icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('Review Documents & Decide'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantStatus() {
    final restaurants = _restaurantStatuses;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halal-Approved Restaurants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Active restaurants with an approved halal classification.', style: TextStyle(color: HalalFoodTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                child: Text('${restaurants.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: HalalFoodTheme.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (restaurants.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Center(child: Text('No active halal-approved restaurants found.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
            )
          else
            ...restaurants.map(_restaurantStatusCard),
        ],
      ),
    );
  }

  Widget _restaurantStatusCard(Map<String, dynamic> restaurant) {
    final status = restaurant['halal_status']?.toString();
    final statusColor = _statusColor(status);
    final name = restaurant['name']?.toString() ?? 'Unnamed Restaurant';
    final city = restaurant['city']?.toString().trim() ?? '';
    final address = restaurant['address']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: InkWell(
        onTap: () => _editStatus(restaurant),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.verified_rounded, color: statusColor, size: 29),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (city.isNotEmpty || address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: HalalFoodTheme.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(child: Text(city.isNotEmpty ? city : address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(label: _statusLabel(status), color: statusColor),
                        const _StatusBadge(label: 'Active', color: Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.10), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
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
          SizedBox(width: 105, child: Text(label, style: const TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
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
            const Icon(Icons.error_outline_rounded, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Unable to load halal verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
