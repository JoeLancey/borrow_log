class AppConfig {
  static const _defaultSupabaseUrl =
    'https://pponevrnsnuzjbcnwvlg.supabase.co';
  static const _defaultPublishableKey =
    'sb_publishable_WmHaWEZS0WjXQYsqYJH5-g_4aAMzNKW';

  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    const publishableKey =
        String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      supabaseUrl: String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: _defaultSupabaseUrl,
      ),
      supabasePublishableKey:
          publishableKey.isNotEmpty
              ? publishableKey
              : anonKey.isNotEmpty
                  ? anonKey
                  : _defaultPublishableKey,
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isValid =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Run with '
        '--dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=....',
      );
    }
  }
}
