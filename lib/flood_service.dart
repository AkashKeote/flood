import 'dart:convert';
import 'package:http/http.dart' as http;

class FloodService {
  static const String baseUrl = 'https://smsfloddbackend.vercel.app';
  
  // Get flood risk for a specific area
  static Future<Map<String, dynamic>> getFloodRisk(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/flood/risk/$city'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'riskLevel': data['riskLevel'] ?? 'low',
          'city': data['city'] ?? city,
          'message': data['message'] ?? 'Flood risk data retrieved successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get flood risk data: ${response.statusCode}',
          'riskLevel': 'low', // Default fallback
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
        'riskLevel': 'low', // Default fallback
      };
    }
  }

  // Get risk level color
  static Map<String, dynamic> getRiskLevelInfo(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return {
          'color': 0xFFE53E3E, // Red
          'icon': '🔴',
          'message': 'High Risk - Take immediate precautions',
          'bgColor': 0xFFFFE5E5,
        };
      case 'moderate':
        return {
          'color': 0xFFFF9800, // Orange
          'icon': '🟡',
          'message': 'Moderate Risk - Stay alert',
          'bgColor': 0xFFFFF3E0,
        };
      case 'low':
      default:
        return {
          'color': 0xFF4CAF50, // Green
          'icon': '🟢',
          'message': 'Low Risk - Normal conditions',
          'bgColor': 0xFFE8F5E8,
        };
    }
  }

  // Get flood alerts for a city
  static Future<Map<String, dynamic>> getFloodAlerts(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/alerts/send-by-city/$city'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get alerts: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
