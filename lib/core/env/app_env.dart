class AppEnv {
  final bool useMockData;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  const AppEnv({
    required this.useMockData,
    this.supabaseUrl,
    this.supabaseAnonKey,
  });

  bool get supabaseEnabled =>
      !useMockData && (supabaseUrl?.isNotEmpty == true) && (supabaseAnonKey?.isNotEmpty == true);
}
