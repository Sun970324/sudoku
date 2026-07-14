/// Read via `--dart-define-from-file=config/secrets.json` (see
/// config/secrets.example.json for the expected keys). Values are baked in
/// at compile time, so a missing config fails fast in debug rather than
/// silently connecting to nothing.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    assert(
      url.isNotEmpty && anonKey.isNotEmpty,
      'SUPABASE_URL/SUPABASE_ANON_KEY are not set. Run with '
      '--dart-define-from-file=config/secrets.json',
    );
  }
}
