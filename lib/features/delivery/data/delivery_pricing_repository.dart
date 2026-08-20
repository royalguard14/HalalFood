import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryPricing {
  final double baseFee;
  final double includedDistanceKm;
  final double perKmRate;
  final double fuelAdjustment;
  final double minimumFee;
  final double maximumDeliveryDistanceKm;
  final double rainSurcharge;
  final double peakHourSurcharge;
  final double nightSurcharge;

  const DeliveryPricing({
    required this.baseFee,
    required this.includedDistanceKm,
    required this.perKmRate,
    required this.fuelAdjustment,
    required this.minimumFee,
    required this.maximumDeliveryDistanceKm,
    required this.rainSurcharge,
    required this.peakHourSurcharge,
    required this.nightSurcharge,
  });

  factory DeliveryPricing.fromMap(
    Map<String, dynamic> map,
  ) {
    return DeliveryPricing(
      baseFee: (map['base_fee'] as num).toDouble(),
      includedDistanceKm:
          (map['included_distance_km'] as num).toDouble(),
      perKmRate:
          (map['per_km_rate'] as num).toDouble(),
      fuelAdjustment:
          (map['fuel_adjustment'] as num).toDouble(),
      minimumFee:
          (map['minimum_fee'] as num).toDouble(),
      maximumDeliveryDistanceKm:
          (map['maximum_delivery_distance_km'] as num)
              .toDouble(),
      rainSurcharge:
          (map['rain_surcharge'] as num).toDouble(),
      peakHourSurcharge:
          (map['peak_hour_surcharge'] as num).toDouble(),
      nightSurcharge:
          (map['night_surcharge'] as num).toDouble(),
    );
  }
}

class DeliveryPricingRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<DeliveryPricing> getPricing() async {
    final response = await _supabase
        .from('delivery_pricing_settings')
        .select()
        .limit(1)
        .single();

    return DeliveryPricing.fromMap(
      Map<String, dynamic>.from(response),
    );
  }
}