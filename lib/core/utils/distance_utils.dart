import 'dart:math' as math;

class DistanceUtils {
  static double distanceInKm({
    required double latitude1,
    required double longitude1,
    required double latitude2,
    required double longitude2,
  }) {
    const earthRadiusKm = 6371.0;

    final lat1 = latitude1 * math.pi / 180;
    final lat2 = latitude2 * math.pi / 180;

    final deltaLat =
        (latitude2 - latitude1) * math.pi / 180;

    final deltaLon =
        (longitude2 - longitude1) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) *
                math.sin(deltaLat / 2) +
            math.cos(lat1) *
                math.cos(lat2) *
                math.sin(deltaLon / 2) *
                math.sin(deltaLon / 2);

    final c =
        2 * math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusKm * c;
  }

  static double deliveryFee({
    required double distanceKm,
  }) {
    if (distanceKm <= 2) {
      return 49.00;
    }

    if (distanceKm <= 5) {
      return 69.00;
    }

    if (distanceKm <= 8) {
      return 89.00;
    }

    if (distanceKm <= 12) {
      return 119.00;
    }

    final extraKm = distanceKm - 12;

    return 119.00 + (extraKm * 10.00);
  }
}