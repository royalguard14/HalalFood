import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/admin_repository.dart';

class DeliveryPricingScreen extends StatefulWidget {
  const DeliveryPricingScreen({super.key});

  @override
  State<DeliveryPricingScreen> createState() => _DeliveryPricingScreenState();
}

class _DeliveryPricingScreenState extends State<DeliveryPricingScreen> {
  final _repository = AdminRepository();
  final _formKey = GlobalKey<FormState>();

  final _baseFee = TextEditingController();
  final _includedDistance = TextEditingController();
  final _perKmRate = TextEditingController();
  final _fuelAdjustment = TextEditingController();
  final _minimumFee = TextEditingController();
  final _maximumDistance = TextEditingController();
  final _rainSurcharge = TextEditingController();
  final _peakHourSurcharge = TextEditingController();
  final _nightSurcharge = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _baseFee,
      _includedDistance,
      _perKmRate,
      _fuelAdjustment,
      _minimumFee,
      _maximumDistance,
      _rainSurcharge,
      _peakHourSurcharge,
      _nightSurcharge,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final pricing = await _repository.getDeliveryPricing();
      if (!mounted) return;

      _baseFee.text = _numberText(pricing?['base_fee']);
      _includedDistance.text = _numberText(pricing?['included_distance_km']);
      _perKmRate.text = _numberText(pricing?['per_km_rate']);
      _fuelAdjustment.text = _numberText(pricing?['fuel_adjustment']);
      _minimumFee.text = _numberText(pricing?['minimum_fee']);
      _maximumDistance.text = _numberText(pricing?['maximum_delivery_distance_km']);
      _rainSurcharge.text = _numberText(pricing?['rain_surcharge']);
      _peakHourSurcharge.text = _numberText(pricing?['peak_hour_surcharge']);
      _nightSurcharge.text = _numberText(pricing?['night_surcharge']);

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _numberText(dynamic value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _repository.updateDeliveryPricing(
        baseFee: _value(_baseFee),
        includedDistanceKm: _value(_includedDistance),
        perKmRate: _value(_perKmRate),
        fuelAdjustment: _value(_fuelAdjustment),
        minimumFee: _value(_minimumFee),
        maximumDeliveryDistanceKm: _value(_maximumDistance),
        rainSurcharge: _value(_rainSurcharge),
        peakHourSurcharge: _value(_peakHourSurcharge),
        nightSurcharge: _value(_nightSurcharge),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery pricing saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save delivery pricing: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Pricing',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      _IntroCard(),
                      const SizedBox(height: 16),
                      _SectionCard(
                        icon: Icons.local_shipping_rounded,
                        title: 'Standard Delivery Fee',
                        subtitle: 'The normal pricing used for each delivery.',
                        children: [
                          _moneyField(_baseFee, 'Base Fee'),
                          _distanceField(_includedDistance, 'Included Distance'),
                          _moneyField(_perKmRate, 'Additional Fee Per KM'),
                          _moneyField(_fuelAdjustment, 'Fuel Adjustment'),
                          _moneyField(_minimumFee, 'Minimum Delivery Fee'),
                          _distanceField(
                            _maximumDistance,
                            'Maximum Delivery Distance',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        icon: Icons.thunderstorm_rounded,
                        title: 'Additional Surcharges',
                        subtitle: 'Optional charges that can be applied based on conditions.',
                        children: [
                          _moneyField(_rainSurcharge, 'Rain Surcharge'),
                          _moneyField(_peakHourSurcharge, 'Peak Hour Surcharge'),
                          _moneyField(_nightSurcharge, 'Night Surcharge'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PreviewCard(
                        baseFee: _value(_baseFee),
                        includedDistance: _value(_includedDistance),
                        perKmRate: _value(_perKmRate),
                        minimumFee: _value(_minimumFee),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading || _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(_saving ? 'Saving...' : 'Save Pricing'),
      ),
    );
  }

  Widget _moneyField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '₱ ',
          prefixIcon: const Icon(Icons.payments_outlined),
        ),
        validator: _numberValidator,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _distanceField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'km',
          prefixIcon: const Icon(Icons.route_outlined),
        ),
        validator: _numberValidator,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  String? _numberValidator(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Enter a valid number.';
    if (number < 0) return 'Value cannot be negative.';
    return null;
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.16),
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            child: Icon(Icons.delivery_dining_rounded),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform-Wide Pricing',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'These settings control the default delivery charges across the HALAL Food platform.',
                  style: TextStyle(
                    fontSize: 12,
                    color: HalalFoodTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HalalFoodTheme.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: HalalFoodTheme.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final double baseFee;
  final double includedDistance;
  final double perKmRate;
  final double minimumFee;

  const _PreviewCard({
    required this.baseFee,
    required this.includedDistance,
    required this.perKmRate,
    required this.minimumFee,
  });

  @override
  Widget build(BuildContext context) {
    final exampleDistance = includedDistance + 3;
    final calculated = (baseFee + (3 * perKmRate)).clamp(minimumFee, double.infinity);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calculate_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Preview',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${exampleDistance.toStringAsFixed(1)} km delivery ≈ ₱${calculated.toStringAsFixed(2)} before condition-based surcharges.',
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
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Unable to load delivery pricing',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
