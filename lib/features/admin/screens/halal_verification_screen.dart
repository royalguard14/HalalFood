import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';

class HalalVerificationScreen extends StatefulWidget {
  const HalalVerificationScreen({super.key});

  @override
  State<HalalVerificationScreen> createState() =>
      _HalalVerificationScreenState();
}

class _HalalVerificationScreenState
    extends State<HalalVerificationScreen> {
  final AdminRepository _repository = AdminRepository();

  bool _isLoading = true;
  String? _error;
  String _filter = 'pending';
  List<Map<String, dynamic>> _verifications = [];

  @override
  void initState() {
    super.initState();
    _loadVerifications();
  }

  Future<void> _loadVerifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getHalalVerifications();

      if (!mounted) return;

      setState(() {
        _verifications = data;
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

    return _verifications.where((item) {
      return item['status']?.toString() == _filter;
    }).toList();
  }

  Future<void> _approve(Map<String, dynamic> verification) async {
    final verificationId = verification['id']?.toString();
    final restaurantId = verification['restaurant_id']?.toString();
    final restaurant = _restaurant(verification);
    final name = restaurant['name']?.toString() ?? 'Restaurant';

    if (verificationId == null || restaurantId == null) return;

    final confirmed = await _confirmAction(
      title: 'Approve Halal Verification?',
      message:
          'Approve "$name" as Halal Verified? This will update the restaurant halal status to Halal Verified.',
      confirmLabel: 'Approve',
    );

    if (!confirmed || !mounted) return;

    try {
      await _repository.approveHalalVerification(
        verificationId: verificationId,
        restaurantId: restaurantId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name is now Halal Verified.')),
      );

      await _loadVerifications();
    } catch (e) {
      if (!mounted) return;
      _showError('Unable to approve verification: $e');
    }
  }

  Future<void> _reject(Map<String, dynamic> verification) async {
    final verificationId = verification['id']?.toString();
    final restaurantId = verification['restaurant_id']?.toString();
    final restaurant = _restaurant(verification);
    final name = restaurant['name']?.toString() ?? 'Restaurant';

    if (verificationId == null || restaurantId == null) return;

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

      await _loadVerifications();
    } catch (e) {
      if (!mounted) return;
      _showError('Unable to reject verification: $e');
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
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

  Map<String, dynamic> _restaurant(Map<String, dynamic> verification) {
    final value = verification['restaurants'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _restaurantName(Map<String, dynamic> verification) {
    return _restaurant(verification)['name']?.toString() ??
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showDetails(Map<String, dynamic> verification) {
    final restaurant = _restaurant(verification);
    final name = _restaurantName(verification);
    final status = verification['status']?.toString();
    final restaurantHalalStatus = restaurant['halal_status']?.toString();
    final certificateUrl = verification['certificate_url']?.toString();

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
                _StatusBadge(
                  label: _statusLabel(status),
                  color: _statusColor(status),
                ),
                const SizedBox(height: 20),
                _DetailRow(
                  label: 'Current Halal Status',
                  value: _halalStatusLabel(restaurantHalalStatus),
                ),
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
                  value: verification['issued_date']?.toString() ??
                      'Not provided',
                ),
                _DetailRow(
                  label: 'Expiry Date',
                  value: verification['expiry_date']?.toString() ??
                      'Not provided',
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
                if (certificateUrl != null && certificateUrl.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCertificateUrl(certificateUrl);
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('View Certificate'),
                    ),
                  ),
                ],
                if (status == 'pending') ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _reject(verification);
                          },
                          child: const Text('Reject'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCertificateUrl(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Certificate',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
            onPressed: _isLoading ? null : _loadVerifications,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
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
              const Icon(Icons.error_outline_rounded, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Unable to load halal verifications',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadVerifications,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredVerifications;

    return RefreshIndicator(
      onRefresh: _loadVerifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                  selected: _filter == 'pending',
                  onSelected: () => setState(() => _filter = 'pending'),
                ),
                _FilterChip(
                  label: 'Approved',
                  selected: _filter == 'verified',
                  onSelected: () => setState(() => _filter = 'verified'),
                ),
                _FilterChip(
                  label: 'Rejected',
                  selected: _filter == 'rejected',
                  onSelected: () => setState(() => _filter = 'rejected'),
                ),
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onSelected: () => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                    Text(
                      'No verification requests found.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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

  Widget _buildSummary() {
    final pending = _verifications
        .where((item) => item['status']?.toString() == 'pending')
        .length;
    final approved = _verifications
        .where((item) => item['status']?.toString() == 'verified')
        .length;
    final rejected = _verifications
        .where((item) => item['status']?.toString() == 'rejected')
        .length;

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
            label: 'Approved',
            value: approved.toString(),
            icon: Icons.verified_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Rejected',
            value: rejected.toString(),
            icon: Icons.cancel_outlined,
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final restaurant = _restaurant(verification);
    final name = _restaurantName(verification);
    final status = verification['status']?.toString();
    final halalStatus = restaurant['halal_status']?.toString();
    final certificateNumber =
        verification['certificate_number']?.toString();
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Current status: ${_halalStatusLabel(halalStatus)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
              if (certificateNumber?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(
                  'Certificate: $certificateNumber',
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
}

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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: HalalFoodTheme.textSecondary,
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

  const _StatusBadge({
    required this.label,
    required this.color,
  });

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

  const _DetailRow({
    required this.label,
    required this.value,
  });

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
