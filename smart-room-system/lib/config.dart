// lib/config.dart
class AppConfig {
  // Supabase
  static const String supabaseUrl = 'https://oziywdhvvjqrdxhglxeb.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96aXl3ZGh2dmpxcmR4aGdseGViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcyODk1MDYsImV4cCI6MjA4Mjg2NTUwNn0.wrzc2-Zb8xBREPK_Yt9jhUCDzGJAIfFALY-qqp_v5Dc';

  // API Keys
  static const String apiKey = '67ed653b0a1c65458b95769444e4d179';
  static const String apiSecret = 'f4002a95cc397907f7739f59675ef59b';
  
  // Chat Configuration - ADD THESE
  static const String chatImagesBucket = 'chat-images';
  
  // App Constants
  static const String appName = 'Smart Room';
  
  // Firebase Project ID
  static const String firebaseProjectId = 'mdmapp-4793e';

  // Room Price Prediction API
  // Change this to your deployed Flask API URL
  static const String priceEstimationApiUrl = 'http://10.0.2.2:5000/predict';
}