import 'package:supabase_flutter/supabase_flutter.dart';

import 'address_model.dart';

class AddressRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<List<Address>> getAddresses() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final response = await _supabase
        .from('user_addresses')
        .select()
        .eq('user_id', user.id)
        .order(
          'is_default',
          ascending: false,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => Address.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<Address> createAddress({
    String? label,
    required String recipientName,
    String? phone,
    required String addressLine,
    String? barangay,
    String? city,
    String? province,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    if (isDefault) {
      await _clearDefaultAddress(
        user.id,
      );
    }

    final response = await _supabase
        .from('user_addresses')
        .insert({
          'user_id': user.id,
          'label': label,
          'recipient_name': recipientName,
          'phone': phone,
          'address_line': addressLine,
          'barangay': barangay,
          'city': city,
          'province': province,
          'latitude': latitude,
          'longitude': longitude,
          'is_default': isDefault,
        })
        .select()
        .single();

    return Address.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<Address> updateAddress({
    required String id,
    String? label,
    required String recipientName,
    String? phone,
    required String addressLine,
    String? barangay,
    String? city,
    String? province,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    if (isDefault) {
      await _clearDefaultAddress(
        user.id,
        exceptId: id,
      );
    }

    final response = await _supabase
        .from('user_addresses')
        .update({
          'label': label,
          'recipient_name': recipientName,
          'phone': phone,
          'address_line': addressLine,
          'barangay': barangay,
          'city': city,
          'province': province,
          'latitude': latitude,
          'longitude': longitude,
          'is_default': isDefault,
          'updated_at': DateTime.now()
              .toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', user.id)
        .select()
        .single();

    return Address.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> deleteAddress(
    String id,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    await _supabase
        .from('user_addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<Address> setDefaultAddress(
    String id,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    await _clearDefaultAddress(
      user.id,
      exceptId: id,
    );

    final response = await _supabase
        .from('user_addresses')
        .update({
          'is_default': true,
          'updated_at': DateTime.now()
              .toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', user.id)
        .select()
        .single();

    return Address.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> _clearDefaultAddress(
    String userId, {
    String? exceptId,
  }) async {
    var query = _supabase
        .from('user_addresses')
        .update({
          'is_default': false,
          'updated_at': DateTime.now()
              .toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('is_default', true);

    if (exceptId != null) {
      query = query.neq(
        'id',
        exceptId,
      );
    }

    await query;
  }
}
