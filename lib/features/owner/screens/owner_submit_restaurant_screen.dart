import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/owner_restaurant_repository.dart';

class OwnerSubmitRestaurantScreen extends StatefulWidget {
  const OwnerSubmitRestaurantScreen({super.key});

  @override
  State<OwnerSubmitRestaurantScreen> createState() => _OwnerSubmitRestaurantScreenState();
}

class _OwnerSubmitRestaurantScreenState extends State<OwnerSubmitRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = OwnerRestaurantRepository();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);
    try {
      await _repository.submitRestaurant(
        name: _name.text,
        description: _description.text,
        phone: _phone.text,
        email: _email.text,
        address: _address.text,
        city: _city.text,
        province: _province.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit restaurant: $e')),
      );
    }
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add My Restaurant',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your restaurant will be submitted for admin approval. It will remain hidden from customers until approved.',
                      style: TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _name,
              decoration: _decoration('Restaurant Name', icon: Icons.store_rounded),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Restaurant name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: _decoration('Description', icon: Icons.description_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _decoration('Phone', icon: Icons.phone_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoration('Email', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              decoration: _decoration('Address', icon: Icons.location_on_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _city,
              decoration: _decoration('City'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _province,
              decoration: _decoration('Province'),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _saving ? 'Submitting...' : 'Submit for Approval',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Halal status starts as Unverified. Admin handles halal verification separately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
