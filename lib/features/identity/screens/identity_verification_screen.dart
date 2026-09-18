import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _latest;
  String _role = 'customer';
  final String _idType = 'National ID';

  Uint8List? _idBytes;
  Uint8List? _selfieBytes;
  String? _idFileName;
  String? _selfieFileName;

  static const _allowedRoles = {'customer', 'driver', 'restaurant_owner'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('role, full_name')
          .eq('id', user.id)
          .maybeSingle();

      final role = profile?['role']?.toString() ?? 'customer';
      _role = role;

      if (!_allowedRoles.contains(role)) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final rows = await _supabase
          .from('identity_verifications')
          .select(
            'id, role, id_type, status, rejection_reason, submitted_at, reviewed_at',
          )
          .eq('user_id', user.id)
          .order('submitted_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      setState(() {
        _latest = rows.isEmpty
            ? null
            : Map<String, dynamic>.from(rows.first as Map);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickId() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2200,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _idBytes = bytes;
      _idFileName = image.name;
    });
  }

  Future<void> _pickSelfie() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2200,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selfieBytes = bytes;
      _selfieFileName = image.name;
    });
  }

  Future<void> _submit() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _idBytes == null || _selfieBytes == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final attemptId = DateTime.now().microsecondsSinceEpoch.toString();
    final basePath = '${user.id}/$attemptId';
    final idPath = '$basePath/id_document';
    final selfiePath = '$basePath/selfie_with_id';

    try {
      await _supabase.storage.from('identity-verifications').uploadBinary(
            idPath,
            _idBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      await _supabase.storage.from('identity-verifications').uploadBinary(
            selfiePath,
            _selfieBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      await _supabase.from('identity_verifications').insert({
        'user_id': user.id,
        'role': _role,
        'id_type': _idType,
        'id_document_path': idPath,
        'selfie_with_id_path': selfiePath,
        'status': 'pending',
      });

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _idBytes = null;
        _selfieBytes = null;
        _idFileName = null;
        _selfieFileName = null;
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity verification submitted for admin review.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Verified';
      case 'rejected':
        return 'Rejected — Resubmission Required';
      default:
        return 'Pending Admin Review';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _latest?['status']?.toString();

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_allowedRoles.contains(_role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Identity Verification')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Identity verification is required for Customer, Rider/Driver and Restaurant Owner accounts.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final canSubmit = status == null || status == 'rejected';

    return PopScope(
      canPop: status == 'approved',
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: status == 'approved',
          title: const Text(
            'Identity Verification',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: _submitting ? null : _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
          children: [
            _headerCard(),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _errorCard(),
              const SizedBox(height: 14),
            ],
            if (status != null) ...[
              _statusCard(status),
              const SizedBox(height: 14),
            ],
            if (status == 'rejected' &&
                (_latest?['rejection_reason']?.toString().trim().isNotEmpty ??
                    false)) ...[
              _rejectionCard(),
              const SizedBox(height: 14),
            ],
            if (canSubmit) ...[
              _requirementsCard(),
              const SizedBox(height: 14),
              _idPickerCard(),
              const SizedBox(height: 12),
              _selfiePickerCard(),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submitting ||
                        _idBytes == null ||
                        _selfieBytes == null
                    ? null
                    : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _submitting
                      ? 'Submitting...'
                      : 'Submit for Verification',
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    status == 'approved'
                        ? 'Your identity is verified. You can continue using the app.'
                        : 'Your submission is currently under admin review. You can use this screen to check the status.',
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: HalalFoodTheme.primaryGreen.withValues(alpha: .14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: HalalFoodTheme.primaryGreen,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify your identity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_roleLabel(_role)} account protection',
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
    );
  }

  Widget _statusCard(String status) {
    final color = _statusColor(status);
    return Card(
      child: ListTile(
        leading: Icon(Icons.shield_rounded, color: color),
        title: Text(
          _statusLabel(status),
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Submitted ${_displayDate(_latest?['submitted_at'])}',
        ),
      ),
    );
  }

  Widget _requirementsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What you need',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text('• A valid government-issued ID.'),
            SizedBox(height: 6),
            Text('• A clear selfie while holding the same ID.'),
            SizedBox(height: 6),
            Text('• Make sure the ID text and photo are readable.'),
          ],
        ),
      ),
    );
  }

  Widget _idPickerCard() {
    return _uploadCard(
      title: 'Government ID',
      subtitle: _idFileName ?? 'Choose a clear photo of your valid ID.',
      icon: Icons.badge_rounded,
      preview: _idBytes,
      onTap: _pickId,
    );
  }

  Widget _selfiePickerCard() {
    return _uploadCard(
      title: 'Selfie with ID',
      subtitle: _selfieFileName ?? 'Take a selfie while holding the same ID.',
      icon: Icons.camera_front_rounded,
      preview: _selfieBytes,
      onTap: _pickSelfie,
    );
  }

  Widget _uploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Uint8List? preview,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _submitting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: preview == null
                    ? Icon(icon, size: 30, color: HalalFoodTheme.primaryGreen)
                    : Image.memory(preview, fit: BoxFit.cover),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HalalFoodTheme.textSecondary,
                      ),
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

  Widget _errorCard() {
    return Card(
      color: Colors.redAccent.withValues(alpha: .07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }

  Widget _rejectionCard() {
    return Card(
      color: Colors.redAccent.withValues(alpha: .07),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Admin remarks: ${_latest?['rejection_reason']}',
          style: const TextStyle(height: 1.4),
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
