
import 'package:halalfood/core/utils/distance_utils.dart';

void main() {
  const customerLatitude = 8.9749037;
  const customerLongitude = 125.4095302;

  const restaurantLatitude = 8.93577679474168;
  const restaurantLongitude = 125.526776141867;

  final distance = DistanceUtils.distanceInKm(
    latitude1: customerLatitude,
    longitude1: customerLongitude,
    latitude2: restaurantLatitude,
    longitude2: restaurantLongitude,
  );

  final fee = DistanceUtils.deliveryFee(
    distanceKm: distance,
  );

  print('Distance: ${distance.toStringAsFixed(2)} km');
  print('Delivery Fee: ₱${fee.toStringAsFixed(2)}');
}
