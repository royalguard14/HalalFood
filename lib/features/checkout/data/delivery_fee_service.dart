
import 'package:geolocator/geolocator.dart';

class DeliveryFeeService {
  static const double baseFee = 49.00;
  static const double includedDistanceKm = 3.0;
  static const double additionalFeePerKm = 10.00;

  static double calculate({
    required double restaurantLatitude,
    required double restaurantLongitude,
    required double customerLatitude,
    required double customerLongitude,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      restaurantLatitude,
      restaurantLongitude,
      customerLatitude,
      customerLongitude,
    );

    final distanceInKm = distanceInMeters / 1000;

    if (distanceInKm <= includedDistanceKm) {
      return baseFee;
    }

    final additionalDistanceKm =
        (distanceInKm - includedDistanceKm).ceil();

    return baseFee +
        (additionalDistanceKm * additionalFeePerKm);
  }
}
