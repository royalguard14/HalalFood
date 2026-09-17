import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserRepository {
  final SupabaseClient _supabase;

  AdminUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUsers() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    var query = _supabase
        .from('profiles')
        .select('id, full_name, phone, role, created_at')
        .order('created_at', ascending: false);

    // PostgREST filters must be applied before the transform/order stage.
    // The current SDK type does not expose neq() after order().
    if (currentUserId != null) {
      query = query.neq('id', currentUserId);
    }

    final response = await query;
    return (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> updateRole({
    required String userId,
    required String role,
  }) async {
    await _supabase
        .from('profiles')
        .update({'role': role})
        .eq('id', userId);
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    await _supabase
        .from('profiles')
        .update({
          'full_name': fullName,
          'phone': phone,
        })
        .eq('id', userId);
  }
}
