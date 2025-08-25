import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';
  static const String _wardKey = 'user_ward';
  static const String _isLoggedInKey = 'is_logged_in';

  // Save user data
  static Future<void> saveUserData(String name, String ward, [String? email]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_wardKey, ward);
    if (email != null && email.isNotEmpty) {
      await prefs.setString(_emailKey, email);
    }
    await prefs.setBool(_isLoggedInKey, true);
  }

  // Get user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // Get user ward
  static Future<String?> getUserWard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wardKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Logout user (but keep name and ward for future use)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
  }

  // Clear all user data
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_wardKey);
    await prefs.remove(_isLoggedInKey);
  }
}
