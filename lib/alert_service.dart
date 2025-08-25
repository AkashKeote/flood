import 'dart:convert';
import 'package:http/http.dart' as http;

class AlertService {
  static const String baseUrl = 'https://smsfloddbackend.vercel.app';

  static Future<Map<String, dynamic>> sendAlertByCity(String city) async {
    try {
      print('🚨 Sending alert for city: $city');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/alert/send-by-city'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'city': city,
        }),
      ).timeout(Duration(seconds: 20));

      print('📡 Alert API Response Status: ${response.statusCode}');
      print('📡 Alert API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to send alert: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Alert API Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> updateCity({
    required String email,
    required String newCity,
  }) async {
    try {
      print('🔄 Updating city for $email to $newCity');
      final response = await http.post(
        Uri.parse('$baseUrl/api/alert/update-city'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'newCity': newCity,
        }),
      ).timeout(Duration(seconds: 20));

      print('📡 Update-city Status: ${response.statusCode}');
      print('📡 Update-city Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update city: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> sendDirect({
    required String email,
    required String city,
  }) async {
    try {
      print('✉️ Sending direct test email to $email for $city');
      final response = await http.post(
        Uri.parse('$baseUrl/api/alert/send-direct'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'city': city,
        }),
      ).timeout(Duration(seconds: 20));

      print('📡 Send-direct Status: ${response.statusCode}');
      print('📡 Send-direct Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to send direct email: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getUsersByCity(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/alert/users/${Uri.encodeComponent(city)}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 20));

      print('📡 Get-users Status: ${response.statusCode}');
      print('📡 Get-users Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch users: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
