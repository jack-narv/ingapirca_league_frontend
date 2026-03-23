class Environment {
  // Configure at build time:
  // flutter build web --dart-define=API_BASE_URL=https://your-backend.railway.app


  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ingapirca-league-backend-production.up.railway.app',
  );

  //static const String baseUrl = String.fromEnvironment(
  //  'API_BASE_URL',
  //  defaultValue: 'http://localhost:3000',
  //);
}
