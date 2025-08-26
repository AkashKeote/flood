import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _nameKey = 'user_name';
  static const String _wardKey = 'user_ward';
  static const String _emailKey = 'user_email';
  static const String _phoneKey = 'user_phone';
  static const String _isLoggedInKey = 'is_logged_in';

  // Save user data
  static Future<void> saveUserData(String name, String ward) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_wardKey, ward);
    await prefs.setBool(_isLoggedInKey, true);
  }

  // Save user data with email
  static Future<void> saveUserDataWithEmail(String name, String ward, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_wardKey, ward);
    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
    await prefs.setBool(_isLoggedInKey, true);
  }

  // Save user phone
  static Future<void> saveUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  // Get user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  // Get user ward
  static Future<String?> getUserWard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wardKey);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // Get user phone
  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  // Get all user data as a map
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey);
    final ward = prefs.getString(_wardKey);
    final email = prefs.getString(_emailKey);
    final phone = prefs.getString(_phoneKey);
    
    if (name == null && ward == null && email == null && phone == null) {
      return null;
    }
    
    return {
      'name': name,
      'area': ward, // Using 'area' for consistency with the calling code
      'email': email,
      'phone': phone,
    };
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
    await prefs.remove(_wardKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_isLoggedInKey);
  }
}
