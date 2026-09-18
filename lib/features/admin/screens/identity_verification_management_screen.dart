import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class IdentityVerificationManagementScreen extends StatefulWidget {
  const IdentityVerificationManagementScreen({
    super.key,
    this.readOnly = false,
  });

  final bool readOnly;

  @override
  State<IdentityVerificationManagementScreen> createState() =>
      _IdentityVerificationManagementScreenState();
}

class _IdentityVerificationManagementScreenState
    extends State<IdentityVerificationManagementScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  String _filter = 'pending';
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      final data = await _supabase
          .from('identity_verifications')
          .select(
            'id,user_id,role,id_type,id_document_path,selfie_with_id_path,status,rejection_reason,submitted_at,reviewed_at,reviewed_by',
          )
          .eq('status', _filter)
          .order('submitted_at', ascending: false);

      final verificationRows =
          List<Map<String, dynamic>>.from(data as List);
      final ids = verificationRows
          .map((e) => e['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profiles = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await _supabase
                  .from('profiles')
                  .select('id,full_name,phone,role')
                  .inFilter('id', ids) as List,
            );

      final profileMap = {
        for (final p in profiles) p['id'].toString(): p,
      };

      for (final row in verificationRows) {
        row['profile'] = profileMap[row['user_id']?.toString()];
      }

      if (!mounted) return;
      setState(() {
        _rows = verificationRows;
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

  String _roleLabel(String role) {
    switch (role) {
      case 'driver':
        return 'Rider / Driver';
      case 'restaurant_owner':
        return 'Restaurant Owner';
      default:
        return 'Customer';
    }
  }

  Future<void> _review(Map<String, dynamic> row) async {
    final idPath = row['id_document_path']?.toString();
    final selfiePath = row['selfie_with_id_path']?.toString();

    try {
      final idUrl = idPath == null
          ? null
          : await _supabase.storage
              .from('identity-verifications')
              .createSignedUrl(idPath, 300);
      final selfieUrl = selfiePath == null
          ? null
          : await _supabase.storage
              .from('identity-verifications')
              .createSignedUrl(selfiePath, 300);

      if (!mounted) return;

      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _ReviewSheet(
          row: row,
          idUrl: idUrl,
          selfieUrl: selfieUrl,
          roleLabel: _roleLabel(row['role']?.toString() ?? 'customer'),
          readOnly: widget.readOnly,
        ),
      );

      if (!mounted || result == null) return;

      if (result == 'approve') {
        await _setDecision(row, 'approved', null);
      } else if (result == 'reject') {
        await _rejectWithReason(row);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open verification: $e')),
        );
      }
    }
  }

  Future<void> _setDecision(
    Map<String, dynamic> row,
    String status,
    String? reason,
  ) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) return;

    try {
      await _supabase.from('identity_verifications').update({
        'status': status,
        'rejection_reason': reason,
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', row['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Identity verification approved.'
                : 'Identity verification rejected.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save decision: $e')),
        );
      }
    }
  }

  Future<void> _rejectWithReason(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reject Verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Rejection reason',
            hintText: 'Explain what the user needs to correct.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (reason == null || reason.trim().isEmpty) return;
    await _setDecision(row, 'rejected', reason.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Identity Verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ],
              selected: {_filter},
              onSelectionChanged: (value) {
                setState(() => _filter = value.first);
                _load();
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'No identity verification records found.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        itemCount: _rows.length,
        itemBuilder: (_, i) => _card(_rows[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final profile = row['profile'] is Map
        ? Map<String, dynamic>.from(row['profile'] as Map)
        : <String, dynamic>{};
    final role = row['role']?.toString() ?? 'customer';
    final status = row['status']?.toString() ?? 'pending';

    final color = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.redAccent
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _review(row),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .10),
                child: Icon(Icons.verified_user_rounded, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile['full_name']?.toString() ?? 'Unnamed User',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_roleLabel(role)} • ${row['id_type'] ?? 'ID'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HalalFoodTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _displayDate(row['submitted_at']),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  String _displayDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return 'Not available';
    return text.replaceFirst('T', ' ').split('.').first;
  }
}

class _ReviewSheet extends StatelessWidget {
  final Map<String, dynamic> row;
  final String? idUrl;
  final String? selfieUrl;
  final String roleLabel;
  final bool readOnly;

  const _ReviewSheet({
    required this.row,
    required this.idUrl,
    required this.selfieUrl,
    required this.roleLabel,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final profile = row['profile'] is Map
        ? Map<String, dynamic>.from(row['profile'] as Map)
        : <String, dynamic>{};

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile['full_name']?.toString() ?? 'Unnamed User',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '$roleLabel • ${profile['phone'] ?? 'No phone'}',
                style: const TextStyle(color: HalalFoodTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              const Text(
                'Government ID',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _image(idUrl),
              const SizedBox(height: 16),
              const Text(
                'Selfie with ID',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _image(selfieUrl),
              const SizedBox(height: 18),
              _detail('ID Type', row['id_type']?.toString() ?? 'Not provided'),
              _detail('Submitted', row['submitted_at']?.toString() ?? 'Not available'),
              if (row['rejection_reason']?.toString().isNotEmpty == true)
                _detail('Previous Reason', row['rejection_reason'].toString()),
              if (!readOnly) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'reject'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, 'approve'),
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 20),
                const Text(
                  'View-only access • Developer cannot approve or reject identity verification.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HalalFoodTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('Document unavailable'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: double.infinity,
        height: 280,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 220,
          child: Center(child: Text('Unable to display document')),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(color: HalalFoodTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
