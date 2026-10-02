class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey:
          String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;

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
