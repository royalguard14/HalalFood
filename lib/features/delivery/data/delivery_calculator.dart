import 'package:geolocator/geolocator.dart';

import 'delivery_pricing_repository.dart';

class DeliveryCalculation {
  final double distanceKm;
  final double deliveryFee;

  const DeliveryCalculation({
    required this.distanceKm,
    required this.deliveryFee,
  });
}

class DeliveryCalculator {
  double calculateDistanceKm({
    required double restaurantLatitude,
    required double restaurantLongitude,
    required double customerLatitude,
    required double customerLongitude,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      restaurantLatitude,
      restaurantLongitude,
      customerLatitude,
      customerLongitude,
    );

    return distanceMeters / 1000;
  }

  DeliveryCalculation calculateFee({
    required double distanceKm,
    required DeliveryPricing pricing,
  }) {
    if (distanceKm > pricing.maximumDeliveryDistanceKm) {
      throw Exception(
        'Delivery is not available beyond '
        '${pricing.maximumDeliveryDistanceKm.toStringAsFixed(0)} km.',
      );
    }

    double fee = pricing.baseFee;

    if (distanceKm > pricing.includedDistanceKm) {
      final extraDistance =
          distanceKm - pricing.includedDistanceKm;

      fee += extraDistance * pricing.perKmRate;
    }

    fee += pricing.fuelAdjustment;
    fee += pricing.rainSurcharge;
    fee += pricing.peakHourSurcharge;
    fee += pricing.nightSurcharge;

    if (fee < pricing.minimumFee) {
      fee = pricing.minimumFee;
    }

    return DeliveryCalculation(
      distanceKm: distanceKm,
      deliveryFee: fee,
    );
  }
}