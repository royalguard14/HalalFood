import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/address_model.dart';
import '../data/address_repository.dart';
import 'add_address_screen.dart';
import 'edit_address_screen.dart';



class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() =>
      _AddressesScreenState();
}

class _AddressesScreenState
    extends State<AddressesScreen> {
  final AddressRepository _repository =
      AddressRepository();

  late Future<List<Address>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  void _loadAddresses() {
    _addressesFuture =
        _repository.getAddresses();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadAddresses();
    });

    await _addressesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Addresses',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Address>>(
          future: _addressesFuture,
          builder: (
            context,
            snapshot,
          ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _AddressErrorView(
                message:
                    snapshot.error.toString(),
                onRetry: () {
                  setState(() {
                    _loadAddresses();
                  });
                },
              );
            }

            final addresses =
                snapshot.data ?? [];

            if (addresses.isEmpty) {
              return const _EmptyAddressesView();
            }

            return ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                32,
              ),
              itemCount: addresses.length,
              itemBuilder: (
                context,
                index,
              ) {
                final address =
                    addresses[index];
return _AddressCard(
  address: address,
  onChanged: () {
    setState(() {
      _loadAddresses();
    });
  },
);
              },
            );
          },
        ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () async {
  final result =
      await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          const AddAddressScreen(),
    ),
  );

  if (result == true && mounted) {
    setState(() {
      _loadAddresses();
    });
  }
},
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Address',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final VoidCallback onChanged;

  const _AddressCard({
    required this.address,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locationParts = <String>[
      if (address.barangay != null &&
          address.barangay!.trim().isNotEmpty)
        address.barangay!.trim(),
      if (address.city != null &&
          address.city!.trim().isNotEmpty)
        address.city!.trim(),
      if (address.province != null &&
          address.province!.trim().isNotEmpty)
        address.province!.trim(),
    ];

    final location = locationParts.join(', ');

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: HalalFoodTheme.primaryGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address.label
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? address.label!
                              : 'Delivery Address',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: HalalFoodTheme.primaryGreen
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: HalalFoodTheme.primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              address.recipientName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            if (address.phone != null &&
                address.phone!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                address.phone!,
                style: const TextStyle(
                  fontSize: 13,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 10),

            Text(
              address.addressLine,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: HalalFoodTheme.textSecondary,
              ),
            ),

            if (location.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: HalalFoodTheme.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (!address.isDefault) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await AddressRepository()
                          .setDefaultAddress(
                        address.id,
                      );

                      if (!context.mounted) return;

                      onChanged();

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Default address updated.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Unable to set default address: $e',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Set as Default',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result =
                          await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => EditAddressScreen(
                            address: address,
                          ),
                        ),
                      );

                      if (result == true &&
                          context.mounted) {
                        onChanged();

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Address updated successfully.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'Edit',
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed =
                          await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text(
                              'Delete Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            content: const Text(
                              'Are you sure you want to delete this address?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(
                                    dialogContext,
                                  ).pop(false);
                                },
                                child: const Text(
                                  'Cancel',
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(
                                    dialogContext,
                                  ).pop(true);
                                },
                                child: const Text(
                                  'Delete',
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed != true ||
                          !context.mounted) {
                        return;
                      }

                      try {
                        await AddressRepository()
                            .deleteAddress(
                          address.id,
                        );

                        if (!context.mounted) return;

                        onChanged();

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Address deleted successfully.',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'Unable to delete address: $e',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Delete',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _EmptyAddressesView
    extends StatelessWidget {
  const _EmptyAddressesView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 80),
        Icon(
          Icons.location_off_outlined,
          size: 64,
          color:
              HalalFoodTheme.primaryGreen,
        ),
        SizedBox(height: 20),
        Text(
          'No addresses yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Add a delivery address so you can use it when placing an order.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color:
                HalalFoodTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AddressErrorView
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AddressErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load addresses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:
                    HalalFoodTheme
                        .textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}