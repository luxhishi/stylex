class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = '';
  static const String anonKey =
      '';

  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
