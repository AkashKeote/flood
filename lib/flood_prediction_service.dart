import 'dart:convert';
import 'package:http/http.dart' as http;

class FloodPredictionService {
  static const String _baseUrl = 'https://flood-knzosjz5w-akash-keotes-projects.vercel.app';
  
  static Future<Map<String, dynamic>> predictFlood(String wardName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/server/predict_flood'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'ward_name': wardName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get prediction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // Get list of available Mumbai wards
  static Future<List<Map<String, dynamic>>> getMumbaiWards() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/server/regions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final regions = List<String>.from(data['regions'] ?? []);
        return regions.map((region) => {
          'name': region,
          'display_name': region,
        }).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to load wards');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // Get detailed ward information
  static Future<Map<String, dynamic>?> getWardInfo(String wardName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/server/predict_flood'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ward_name': wardName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Check server health
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/server/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy' || data['message'] != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  static String getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return '0xFF4CAF50'; // Green
      case 'moderate':
        return '0xFFFF9800'; // Orange  
      case 'high':
        return '0xFFF44336'; // Red
      default:
        return '0xFF9E9E9E'; // Grey
    }
  }
  
  static String getRiskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return 'check_circle';
      case 'moderate':
        return 'warning';
      case 'high':
        return 'error';
      default:
        return 'help';
    }
  }
}
