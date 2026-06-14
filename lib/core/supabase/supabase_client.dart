import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

Future<void> initSupabase() async {
  if (!SupabaseConfig.isConfigured) return;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

SupabaseClient? get supabaseOrNull =>
    SupabaseConfig.isConfigured ? Supabase.instance.client : null;
