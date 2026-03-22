class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://mrrnqvqqmygdisvrwjtt.supabase.co';
  static const String anonKey =
      'sb_publishable_HGrI6OyX_ZhAMX9DX46WJA_Z0_vtY5s';

  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
