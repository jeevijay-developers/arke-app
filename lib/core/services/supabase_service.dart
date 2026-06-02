import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SupabaseService {
  SupabaseService._();

  // Single access point for the Supabase client.
  static SupabaseClient get client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured. Check your .env values.');
    }
    return Supabase.instance.client;
  }
}

class SupabaseConfig {
  SupabaseConfig._();

  // Validate required environment variables are present.
  static bool get isConfigured =>
      Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty;
}
