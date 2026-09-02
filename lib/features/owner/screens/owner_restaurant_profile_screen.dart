import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import 'owner_halal_verification_request_screen.dart';

class OwnerRestaurantProfileScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const OwnerRestaurantProfileScreen({super.key, required this.restaurantId, required this.restaurantName});

  @override
  State<OwnerRestaurantProfileScreen> createState() => _OwnerRestaurantProfileScreenState();
}

class _OwnerRestaurantProfileScreenState extends State<OwnerRestaurantProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  String? _error;
  String? _logoUrl;
  String? _logoPath;
  String _halalStatus = 'unverified';
  bool _hasPendingVerification = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.restaurantName;
    _loadRestaurant();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurant() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final restaurant = await _supabase.from('restaurants').select(
        'id, name, description, phone, email, address, city, province, halal_status, logo_url',
      ).eq('id', widget.restaurantId).maybeSingle();
      if (restaurant == null) throw Exception('Restaurant not found.');

      final pending = await _supabase.from('halal_verifications').select('id')
          .eq('restaurant_id', widget.restaurantId).eq('status', 'pending').limit(1).maybeSingle();

      if (!mounted) return;
      _nameController.text = restaurant['name']?.toString() ?? '';
      _descriptionController.text = restaurant['description']?.toString() ?? '';
      _phoneController.text = restaurant['phone']?.toString() ?? '';
      _emailController.text = restaurant['email']?.toString() ?? '';
      _addressController.text = restaurant['address']?.toString() ?? '';
      _cityController.text = restaurant['city']?.toString() ?? '';
      _provinceController.text = restaurant['province']?.toString() ?? '';
      setState(() {
        _logoUrl = restaurant['logo_url']?.toString();
        _halalStatus = restaurant['halal_status']?.toString() ?? 'unverified';
        _hasPendingVerification = pending != null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickLogo() async {
    if (_isUploadingLogo) return;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200, maxHeight: 1200);
      if (file == null) return;
      setState(() => _isUploadingLogo = true);
      final bytes = await file.readAsBytes();
      final path = '${widget.restaurantId}/logo-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('restaurant-images').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
      final url = _supabase.storage.from('restaurant-images').getPublicUrl(path);
      await _supabase.from('restaurants').update({'logo_url': url}).eq('id', widget.restaurantId);
      if (!mounted) return;
      setState(() { _logoUrl = url; _logoPath = path; _isUploadingLogo = false; });
      _showMessage('Restaurant logo updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingLogo = false);
      _showMessage('Unable to upload logo:\n$e', error: true);
    }
  }

  Future<void> _removeLogo() async {
    if (_isUploadingLogo || _logoUrl == null || _logoUrl!.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove Restaurant Logo?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('The restaurant will show the default No Photo image instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      setState(() => _isUploadingLogo = true);
      if (_logoPath != null) await _supabase.storage.from('restaurant-images').remove([_logoPath!]);
      await _supabase.from('restaurants').update({'logo_url': null}).eq('id', widget.restaurantId);
      if (!mounted) return;
      setState(() { _logoUrl = null; _logoPath = null; _isUploadingLogo = false; });
      _showMessage('Restaurant logo removed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingLogo = false);
      _showMessage('Unable to remove logo:\n$e', error: true);
    }
  }

  Future<void> _saveRestaurant() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    try {
      setState(() => _isSaving = true);
      await _supabase.from('restaurants').update({
        'name': _nameController.text.trim(),
        'description': _clean(_descriptionController.text),
        'phone': _clean(_phoneController.text),
        'email': _clean(_emailController.text),
        'address': _clean(_addressController.text),
        'city': _clean(_cityController.text),
        'province': _clean(_provinceController.text),
      }).eq('id', widget.restaurantId);
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Restaurant profile updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Unable to update restaurant profile:\n$e', error: true);
    }
  }

  String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _openVerificationRequest() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OwnerHalalVerificationRequestScreen(
        restaurantId: widget.restaurantId,
        restaurantName: _nameController.text.trim().isEmpty ? widget.restaurantName : _nameController.text.trim(),
      ),
    ));
    if (mounted) await _loadRestaurant();
  }

  String _halalLabel(String value) => switch (value) {
        'muslim_owned' => 'Muslim Owned',
        'halal_verified' => 'Halal Verified',
        'certified_halal' => 'Certified Halal',
        _ => 'Unverified',
      };

  Color _halalColor(String value) => switch (value) {
        'muslim_owned' => Colors.blue,
        'halal_verified' => Colors.green,
        'certified_halal' => Colors.deepPurple,
        _ => Colors.orange,
      };

  InputDecoration _decoration(String label, IconData icon, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Restaurant Profile & Settings', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading || _isSaving ? null : _loadRestaurant,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _buildBody(),
      );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Unable to load restaurant profile', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _loadRestaurant, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    final canRequest = _halalStatus == 'unverified' && !_hasPendingVerification;
    return RefreshIndicator(
      onRefresh: _loadRestaurant,
      child: Form(
        key: _formKey,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            if (canRequest) ...[_buildVerificationRequestCard(), const SizedBox(height: 24)],
            if (_hasPendingVerification) ...[_buildPendingCard(), const SizedBox(height: 24)],
            const Text('Restaurant Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Restaurant Name', Icons.storefront_outlined, hint: 'Enter restaurant name'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Restaurant name cannot be empty.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _descriptionController, maxLines: 4, decoration: _decoration('Description', Icons.description_outlined, hint: 'Tell customers about your restaurant')),
            const SizedBox(height: 14),
            TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _decoration('Phone', Icons.phone_outlined)),
            const SizedBox(height: 14),
            TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _decoration('Email', Icons.email_outlined)),
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(controller: _addressController, maxLines: 2, decoration: _decoration('Address', Icons.location_on_outlined)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: TextFormField(controller: _cityController, textCapitalization: TextCapitalization.words, decoration: _decoration('City', Icons.location_city_outlined))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _provinceController, textCapitalization: TextCapitalization.words, decoration: _decoration('Province', Icons.map_outlined))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRestaurant,
                icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('These details are used for your restaurant listing and customer information.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _hasPendingVerification ? Colors.orange : _halalColor(_halalStatus);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickLogo,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: _logoUrl != null && _logoUrl!.isNotEmpty
                        ? Image.network(_logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _noPhoto())
                        : _noPhoto(),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(color: HalalFoodTheme.primaryGreen, shape: BoxShape.circle),
                    child: _isUploadingLogo
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Restaurant Profile', style: TextStyle(fontSize: 13, color: HalalFoodTheme.textSecondary)),
                const SizedBox(height: 3),
                Text(_nameController.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _hasPendingVerification ? 'Verification Pending' : _halalLabel(_halalStatus),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                    if (_logoUrl != null && _logoUrl!.isNotEmpty)
                      TextButton(onPressed: _removeLogo, child: const Text('Remove Logo')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noPhoto() => Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 28, color: Colors.grey.shade500),
            const SizedBox(height: 3),
            Text('NO PHOTO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _buildVerificationRequestCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withValues(alpha: .22))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Get Your Restaurant Halal Status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Submit your supporting documents and request a halal classification. The admin will review everything and make the final decision.', style: TextStyle(color: HalalFoodTheme.textSecondary)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _openVerificationRequest, icon: const Icon(Icons.verified_user_outlined), label: const Text('Request Halal Verification'))),
          ],
        ),
      );

  Widget _buildPendingCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(child: Text('Your halal verification request is pending admin review.', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
