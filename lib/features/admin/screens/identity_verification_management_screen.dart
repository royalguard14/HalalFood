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
      } else if (result.startsWith('reject:')) {
        final reason = result.substring('reject:'.length).trim();
        if (reason.isNotEmpty) {
          await _setDecision(row, 'rejected', reason);
        }
      } else if (result == 'delete') {
        await _deleteVerification(row);
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

      if (status == 'approved') {
        await _cleanupRejectedHistory(
          userId: row['user_id'].toString(),
          role: row['role'].toString(),
          excludeId: row['id'].toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        if (_filter == status) {
          final index = _rows.indexWhere((item) => item['id'] == row['id']);
          if (index >= 0) {
            _rows[index] = {...row, 'status': status, 'rejection_reason': reason};
          }
        } else {
          _rows.removeWhere((item) => item['id'] == row['id']);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Identity verification approved. Rejected history was cleaned up.'
                : 'Identity verification rejected and removed from Pending.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save decision: $e')),
        );
      }
    }
  }

  Future<void> _cleanupRejectedHistory({
    required String userId,
    required String role,
    required String excludeId,
  }) async {
    final rows = await _supabase
        .from('identity_verifications')
        .select('id,id_document_path,selfie_with_id_path')
        .eq('user_id', userId)
        .eq('role', role)
        .eq('status', 'rejected')
        .neq('id', excludeId);

    final rejected = List<Map<String, dynamic>>.from(rows as List);
    if (rejected.isEmpty) return;

    final paths = <String>[];
    for (final item in rejected) {
      final idPath = item['id_document_path']?.toString();
      final selfiePath = item['selfie_with_id_path']?.toString();
      if (idPath != null && idPath.isNotEmpty) paths.add(idPath);
      if (selfiePath != null && selfiePath.isNotEmpty) paths.add(selfiePath);
    }

    if (paths.isNotEmpty) {
      await _supabase.storage.from('identity-verifications').remove(paths);
    }

    await _supabase
        .from('identity_verifications')
        .delete()
        .inFilter('id', rejected.map((e) => e['id']).toList());
  }

  Future<void> _deleteVerification(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Verification?'),
        content: const Text(
          'This permanently deletes the verification record and its ID/selfie files. '
          'The user will become unverified if this is their approved record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final paths = <String>[];
      final idPath = row['id_document_path']?.toString();
      final selfiePath = row['selfie_with_id_path']?.toString();
      if (idPath != null && idPath.isNotEmpty) paths.add(idPath);
      if (selfiePath != null && selfiePath.isNotEmpty) paths.add(selfiePath);

      if (paths.isNotEmpty) {
        await _supabase.storage.from('identity-verifications').remove(paths);
      }

      await _supabase
          .from('identity_verifications')
          .delete()
          .eq('id', row['id']);

      if (!mounted) return;
      setState(() => _rows.removeWhere((item) => item['id'] == row['id']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification and its files were deleted.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete verification: $e')),
        );
      }
    }
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

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Reject Verification',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Rejection reason',
          hintText: 'Explain what the user needs to correct.',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isEmpty) return;
            Navigator.of(context).pop(reason);
          },
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject'),
        ),
      ],
    );
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

  Future<void> _reject(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectReasonDialog(),
    );

    if (!context.mounted || reason == null || reason.trim().isEmpty) {
      return;
    }

    final result = 'reject:' + reason.trim();

    // Let the AlertDialog route finish its own frame before closing the
    // review BottomSheet. This avoids navigating two routes during the
    // same widget build scope.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }
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
              _image(idUrl, context),
              const SizedBox(height: 16),
              const Text(
                'Selfie with ID',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _image(selfieUrl, context),
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
                        onPressed: () => _reject(context),
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
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete Verification Permanently'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(String? url, BuildContext context) {
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

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openImageViewer(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          width: double.infinity,
          height: 280,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 220,
            child: Center(child: Text('Unable to display document')),
          ),
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(80),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  'Unable to display document',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
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
