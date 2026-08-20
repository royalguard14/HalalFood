
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/address_model.dart';
import '../data/address_repository.dart';

class EditAddressScreen extends StatefulWidget {
  final Address address;

  const EditAddressScreen({
    super.key,
    required this.address,
  });

  @override
  State<EditAddressScreen> createState() =>
      _EditAddressScreenState();
}

class _EditAddressScreenState
    extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final _repository = AddressRepository();

  late final TextEditingController _labelController;
  late final TextEditingController _recipientNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressLineController;
  late final TextEditingController _barangayController;
  late final TextEditingController _cityController;
  late final TextEditingController _provinceController;

  late bool _isDefault;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final address = widget.address;

    _labelController = TextEditingController(
      text: address.label ?? '',
    );

    _recipientNameController =
        TextEditingController(
      text: address.recipientName,
    );

    _phoneController = TextEditingController(
      text: address.phone ?? '',
    );

    _addressLineController =
        TextEditingController(
      text: address.addressLine,
    );

    _barangayController =
        TextEditingController(
      text: address.barangay ?? '',
    );

    _cityController = TextEditingController(
      text: address.city ?? '',
    );

    _provinceController =
        TextEditingController(
      text: address.province ?? '',
    );

    _isDefault = address.isDefault;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientNameController.dispose();
    _phoneController.dispose();
    _addressLineController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.updateAddress(
        id: widget.address.id,
        label:
            _labelController.text.trim().isEmpty
                ? null
                : _labelController.text.trim(),
        recipientName:
            _recipientNameController.text.trim(),
        phone:
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        addressLine:
            _addressLineController.text.trim(),
        barangay:
            _barangayController.text.trim().isEmpty
                ? null
                : _barangayController.text.trim(),
        city:
            _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
        province:
            _provinceController.text.trim().isEmpty
                ? null
                : _provinceController.text.trim(),
        latitude: widget.address.latitude,
        longitude: widget.address.longitude,
        isDefault: _isDefault,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Address updated successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update address: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration _decoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Address',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              32,
            ),
            children: [
              const Text(
                'Delivery Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color:
                      HalalFoodTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Update your delivery address information.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color:
                      HalalFoodTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Address Label',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _labelController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  hintText:
                      'e.g. Home, Work',
                  icon:
                      Icons.bookmark_outline_rounded,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Recipient Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                    _recipientNameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  hintText:
                      'Name of recipient',
                  icon:
                      Icons.person_outline_rounded,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter recipient name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              const Text(
                'Phone Number',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _phoneController,
                keyboardType:
                    TextInputType.phone,
                decoration: _decoration(
                  hintText:
                      'e.g. 09171234567',
                  icon:
                      Icons.phone_outlined,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Address Line',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                    _addressLineController,
                textCapitalization:
                    TextCapitalization.sentences,
                maxLines: 2,
                decoration: _decoration(
                  hintText:
                      'House no., street, building, etc.',
                  icon:
                      Icons.home_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter your address';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              const Text(
                'Barangay',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                    _barangayController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  hintText: 'Barangay',
                  icon:
                      Icons.location_on_outlined,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'City',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _cityController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  hintText: 'City',
                  icon:
                      Icons.location_city_outlined,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Province',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                    _provinceController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  hintText: 'Province',
                  icon:
                      Icons.map_outlined,
                ),
              ),

              const SizedBox(height: 22),

              Card(
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  value: _isDefault,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _isDefault = value;
                          });
                        },
                  title: const Text(
                    'Set as default address',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Use this address by default when ordering.',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor:
                      HalalFoodTheme.primaryGreen,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isSaving
                          ? null
                          : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
