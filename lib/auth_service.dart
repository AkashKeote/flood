import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Use the deployed Vercel backend
  static const String baseUrl = 'https://smsfloddbackend.vercel.app'; // Deployed Vercel backend
  
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String city,
  }) async {
    print('🔄 Attempting to register user: $name, $email, $city');
    print('🌐 Backend URL: $baseUrl/api/auth/signup');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/signup'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'city': city,
        }),
      ).timeout(Duration(seconds: 15)); // Increased timeout

      print('📤 Request sent. Status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ Registration successful!');
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        print('❌ Registration failed with status: ${response.statusCode}');
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'error': error['error'] ?? 'Registration failed',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('💥 Network error: $e');
      return {
        'success': false,
        'error': 'Network error: Unable to connect to server. Details: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }
}
