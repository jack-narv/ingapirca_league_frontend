class Environment {
  // Base URL for your backend
  static const String baseUrl = "http://192.168.1.3:3000";
  //static const String baseUrl = "https://ingapirca-league-backend-production.up.railway.app";


  // API version
  static const String apiVersion = 'v1';

  static String get apiUrl => '$baseUrl/$apiVersion';
}