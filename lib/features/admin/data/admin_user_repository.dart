import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserRepository {
  final SupabaseClient _supabase;

  AdminUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _supabase
        .from('profiles')
        .select('id, full_name, phone, role, created_at')
        .order('created_at', ascending: false);

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
}
