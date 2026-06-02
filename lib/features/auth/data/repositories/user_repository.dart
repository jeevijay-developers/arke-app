import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../models/user_profile.dart';

class UserRepository {
  // Profiles CRUD mapped to the profiles table.
  final SupabaseClient _client;

  UserRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    try {
      final data = await _client
          .from('profiles')
          .update(profile.toJson())
          .eq('user_id', profile.userId)
          .select('*')
          .single();
      return UserProfile.fromJson(data);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  Future<void> insertUserData(UserProfile profile) async {
    try {
      await _client.from('profiles').insert(profile.toJson());
    } catch (e) {
      throw Exception('Failed to insert user profile: $e');
    }
  }
}
