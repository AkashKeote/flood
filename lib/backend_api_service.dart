import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to interact with Vercel-deployed backend APIs
class BackendApiService {
  // Local development URL - change this when you deploy to Vercel
  static const String baseUrl = 'http://127.0.0.1:5000';
  // Vercel URL (uncomment when deployed): 'https://flood-knzosjz5w-akash-keotes-projects.vercel.app';
  
  // Common headers for API requests
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Health check endpoint
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during health check: $e');
    }
  }

  /// Get flood risk prediction for a ward/region
  static Future<Map<String, dynamic>> predictFlood(String wardName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_flood'),
        headers: _headers,
        body: jsonEncode({
          'ward_name': wardName,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to predict flood risk');
      }
    } catch (e) {
      throw Exception('Network error during flood prediction: $e');
    }
  }

  /// Get list of available regions
  static Future<List<String>> getRegions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/regions'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['regions'] ?? []);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get regions');
      }
    } catch (e) {
      throw Exception('Network error during region fetch: $e');
    }
  }

  /// Get evacuation routes for a region
  static Future<Map<String, dynamic>> getEvacuationRoutes({
    required String region,
    int routeCount = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/routes'),
        headers: _headers,
        body: jsonEncode({
          'region': region,
          'route_count': routeCount,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get evacuation routes');
      }
    } catch (e) {
      throw Exception('Network error during route fetch: $e');
    }
  }

  /// Get evacuation map HTML for a region
  static Future<String> getEvacuationMap(String region) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/map?region=$region'),
        headers: {
          'Accept': 'text/html,application/json',
        },
      );

      if (response.statusCode == 200) {
        // Check if response is HTML
        if (response.headers['content-type']?.contains('text/html') == true) {
          return response.body;
        } else {
          // Try to parse as JSON and extract HTML
          try {
            final data = jsonDecode(response.body);
            return data['html_content'] ?? response.body;
          } catch (e) {
            return response.body;
          }
        }
      } else {
        throw Exception('Failed to get evacuation map: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during map fetch: $e');
    }
  }

  /// Get basic API info
  static Future<Map<String, dynamic>> getApiInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get API info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during API info fetch: $e');
    }
  }

  /// Test all API endpoints
  static Future<Map<String, dynamic>> testAllAPIs() async {
    Map<String, dynamic> results = {};
    
    try {
      // Health check
      results['health'] = await healthCheck();
    } catch (e) {
      results['health'] = {'error': e.toString()};
    }

    try {
      // API info
      results['api_info'] = await getApiInfo();
    } catch (e) {
      results['api_info'] = {'error': e.toString()};
    }

    try {
      // Regions
      results['regions'] = await getRegions();
    } catch (e) {
      results['regions'] = {'error': e.toString()};
    }

    try {
      // Test flood prediction
      results['flood_prediction'] = await predictFlood('Andheri East');
    } catch (e) {
      results['flood_prediction'] = {'error': e.toString()};
    }

    try {
      // Test evacuation routes
      results['evacuation_routes'] = await getEvacuationRoutes(region: 'Andheri East');
    } catch (e) {
      results['evacuation_routes'] = {'error': e.toString()};
    }

    return results;
  }
}

/// Data models for API responses
class EvacuationRoute {
  final String destination;
  final double distance;
  final String eta;
  final String riskLevel;
  final List<double> coordinates;

  EvacuationRoute({
    required this.destination,
    required this.distance,
    required this.eta,
    required this.riskLevel,
    required this.coordinates,
  });

  factory EvacuationRoute.fromJson(Map<String, dynamic> json) {
    return EvacuationRoute(
      destination: json['destination'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      eta: json['eta'] ?? '',
      riskLevel: json['risk_level'] ?? 'unknown',
      coordinates: List<double>.from(json['coordinates'] ?? []),
    );
  }
}

class FloodPrediction {
  final String ward;
  final String riskLevel;
  final double confidence;
  final String message;

  FloodPrediction({
    required this.ward,
    required this.riskLevel,
    required this.confidence,
    required this.message,
  });

  factory FloodPrediction.fromJson(Map<String, dynamic> json) {
    return FloodPrediction(
      ward: json['ward'] ?? '',
      riskLevel: json['risk_level'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      message: json['message'] ?? '',
    );
  }
}
