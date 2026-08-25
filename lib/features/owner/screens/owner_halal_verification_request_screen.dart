import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class OwnerHalalVerificationRequestScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerHalalVerificationRequestScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<OwnerHalalVerificationRequestScreen> createState() =>
      _OwnerHalalVerificationRequestScreenState();
}

class _OwnerHalalVerificationRequestScreenState
    extends State<OwnerHalalVerificationRequestScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _certificateUrl = TextEditingController();
  final _certificateNumber = TextEditingController();
  final _issuingAuthority = TextEditingController();
  final _issuedDate = TextEditingController();
  final _expiryDate = TextEditingController();
  final _remarks = TextEditingController();

  String _requestedStatus = 'muslim_owned';
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _pending;
  String? _error;

  static const _statuses = <String>[
    'muslim_owned',
    'halal_verified',
    'certified_halal',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _certificateUrl.dispose();
    _certificateNumber.dispose();
    _issuingAuthority.dispose();
    _issuedDate.dispose();
    _expiryDate.dispose();
    _remarks.dispose();
    super.dispose();
  }

  String _statusLabel(String status) => switch (status) {
        'muslim_owned' => 'Muslim Owned',
        'halal_verified' => 'Halal Verified',
        'certified_halal' => 'Certified Halal',
        _ => 'Unverified',
      };

  Future<void> _loadRequest() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final restaurant = await _supabase
          .from('restaurants')
          .select('id, name, halal_status')
          .eq('id', widget.restaurantId)
          .maybeSingle();

      if (restaurant == null) throw Exception('Restaurant not found.');

      final response = await _supabase
          .from('halal_verifications')
          .select(
            'id, status, requested_status, certificate_url, certificate_number, issuing_authority, '
            'issued_date, expiry_date, admin_remarks, created_at',
          )
          .eq('restaurant_id', widget.restaurantId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _pending = response == null ? null : Map<String, dynamic>.from(response);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showMessage('You are not authenticated.', error: true);
      return;
    }

    try {
      setState(() => _saving = true);

      final restaurant = await _supabase
          .from('restaurants')
          .select('id, owner_id, halal_status')
          .eq('id', widget.restaurantId)
          .eq('owner_id', user.id)
          .maybeSingle();

      if (restaurant == null) {
        throw Exception('This restaurant does not belong to your account.');
      }

      if (restaurant['halal_status']?.toString() != 'unverified') {
        throw Exception('This restaurant already has a halal classification.');
      }

      final existing = await _supabase
          .from('halal_verifications')
          .select('id')
          .eq('restaurant_id', widget.restaurantId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        throw Exception('A verification request is already pending.');
      }

      await _supabase.from('halal_verifications').insert({
        'restaurant_id': widget.restaurantId,
        'submitted_by': user.id,
        'status': 'pending',
        'requested_status': _requestedStatus,
        'certificate_url': _clean(_certificateUrl.text),
        'certificate_number': _clean(_certificateNumber.text),
        'issuing_authority': _clean(_issuingAuthority.text),
        'issued_date': _clean(_issuedDate.text),
        'expiry_date': _clean(_expiryDate.text),
        'admin_remarks': _clean(_remarks.text),
      });

      if (!mounted) return;
      _showMessage('Verification request submitted. The admin will review it.');
      await _loadRequest();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to submit verification request: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _clean(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Halal Verification Request', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _loadRequest,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_pending != null) {
      return RefreshIndicator(
        onRefresh: _loadRequest,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _restaurantHeader(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Request Pending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text('Requested: ${_statusLabel(_pending!['requested_status']?.toString() ?? 'muslim_owned')}'),
                        const SizedBox(height: 5),
                        const Text('Your request has been submitted. Please wait for the admin to review your documents and make a final classification.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequest,
      child: Form(
        key: _formKey,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _restaurantHeader(),
            const SizedBox(height: 22),
            const Text('Request Classification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Tell the admin what classification you are requesting. The admin makes the final decision.', style: TextStyle(color: HalalFoodTheme.textSecondary)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _requestedStatus,
              decoration: _decoration('Requested Classification', Icons.verified_outlined),
              items: _statuses.map((status) => DropdownMenuItem(value: status, child: Text(_statusLabel(status)))).toList(),
              onChanged: _saving ? null : (value) {
                if (value != null) setState(() => _requestedStatus = value);
              },
            ),
            const SizedBox(height: 22),
            const Text('Supporting Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Provide the document link if you already uploaded the file to your storage or document service. File upload can be connected to Supabase Storage next.', style: TextStyle(color: HalalFoodTheme.textSecondary)),
            const SizedBox(height: 14),
            TextFormField(controller: _certificateUrl, keyboardType: TextInputType.url, decoration: _decoration('Document / Certificate URL', Icons.link_rounded)),
            const SizedBox(height: 12),
            TextFormField(controller: _certificateNumber, decoration: _decoration('Certificate Number', Icons.numbers_rounded)),
            const SizedBox(height: 12),
            TextFormField(controller: _issuingAuthority, decoration: _decoration('Issuing Authority', Icons.account_balance_outlined)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _issuedDate, decoration: _decoration('Issued Date', Icons.calendar_today_outlined))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _expiryDate, decoration: _decoration('Expiry Date', Icons.event_available_outlined))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _remarks, maxLines: 4, decoration: _decoration('Message to Admin', Icons.notes_rounded)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Submitting...' : 'Submit Verification Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restaurantHeader() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: HalalFoodTheme.primaryGreen,
              child: Icon(Icons.restaurant_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Restaurant', style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
                  const SizedBox(height: 3),
                  Text(widget.restaurantName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  const Text('Current status: Unverified', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
}
