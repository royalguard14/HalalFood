import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRestaurants() async {
    final response = await _supabase
        .from('restaurants')
        .select(
          'id, owner_id, name, description, phone, email, address, city, province, '
          'latitude, longitude, logo_url, cover_image_url, halal_status, is_active, '
          'is_featured, average_rating, review_count, created_at, updated_at',
        )
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<int> getRestaurantCount() async {
    final response = await _supabase.from('restaurants').select('id');
    return (response as List).length;
  }

  Future<int> getActiveRestaurantCount() async {
    final response = await _supabase.from('restaurants').select('id').eq('is_active', true);
    return (response as List).length;
  }

  Future<int> getPendingVerificationCount() async {
    final response = await _supabase.from('restaurants').select('id').eq('halal_status', 'unverified');
    return (response as List).length;
  }

  Future<void> setRestaurantActive({required String restaurantId, required bool isActive}) async {
    await _supabase.from('restaurants').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', restaurantId);
  }

  Future<void> setRestaurantFeatured({required String restaurantId, required bool isFeatured}) async {
    await _supabase.from('restaurants').update({
      'is_featured': isFeatured,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', restaurantId);
  }

  Future<void> setHalalStatus({required String restaurantId, required String halalStatus}) async {
    const allowed = {
      'unverified',
      'muslim_owned',
      'halal_verified',
      'certified_halal',
    };
    if (!allowed.contains(halalStatus)) {
      throw ArgumentError('Invalid halal status: $halalStatus');
    }

    await _supabase.from('restaurants').update({
      'halal_status': halalStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', restaurantId);
  }

  Future<Map<String, dynamic>?> getDeliveryPricing() async {
    final response = await _supabase
        .from('delivery_pricing_settings')
        .select()
        .limit(1)
        .maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<void> updateDeliveryPricing({
    required double baseFee,
    required double includedDistanceKm,
    required double perKmRate,
    required double fuelAdjustment,
    required double minimumFee,
    required double maximumDeliveryDistanceKm,
    required double rainSurcharge,
    required double peakHourSurcharge,
    required double nightSurcharge,
  }) async {
    final existing = await _supabase
        .from('delivery_pricing_settings')
        .select('id')
        .limit(1)
        .maybeSingle();

    final data = {
      'base_fee': baseFee,
      'included_distance_km': includedDistanceKm,
      'per_km_rate': perKmRate,
      'fuel_adjustment': fuelAdjustment,
      'minimum_fee': minimumFee,
      'maximum_delivery_distance_km': maximumDeliveryDistanceKm,
      'rain_surcharge': rainSurcharge,
      'peak_hour_surcharge': peakHourSurcharge,
      'night_surcharge': nightSurcharge,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing == null) {
      await _supabase.from('delivery_pricing_settings').insert(data);
    } else {
      await _supabase.from('delivery_pricing_settings').update(data).eq('id', existing['id']);
    }
  }

  Future<List<Map<String, dynamic>>> getHalalVerifications() async {
    final response = await _supabase
        .from('halal_verifications')
        .select(
          'id, restaurant_id, submitted_by, status, certificate_url, certificate_number, '
          'issuing_authority, issued_date, expiry_date, admin_remarks, verified_by, '
          'verified_at, created_at, updated_at, restaurants(id, owner_id, name, description, '
          'phone, email, website, address, city, province, latitude, longitude, logo_url, '
          'cover_image_url, halal_status, is_active, is_featured, average_rating, review_count)',
        )
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> approveHalalVerification({required String verificationId, required String restaurantId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _supabase.from('halal_verifications').update({
      'status': 'verified',
      'verified_by': user.id,
      'verified_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', verificationId);

    await setHalalStatus(
      restaurantId: restaurantId,
      halalStatus: 'halal_verified',
    );
  }

  Future<void> rejectHalalVerification({required String verificationId, required String restaurantId, String? remarks}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _supabase.from('halal_verifications').update({
      'status': 'rejected',
      'verified_by': user.id,
      'verified_at': DateTime.now().toIso8601String(),
      'admin_remarks': remarks,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', verificationId);

    await setHalalStatus(
      restaurantId: restaurantId,
      halalStatus: 'unverified',
    );
  }

  Future<int> getTodayOrderCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final response = await _supabase
        .from('orders')
        .select('id')
        .gte('created_at', startOfDay.toIso8601String());
    return (response as List).length;
  }

  Future<int> getPendingOrderCount() async {
    final response = await _supabase.from('orders').select('id').eq('status', 'pending');
    return (response as List).length;
  }
}
