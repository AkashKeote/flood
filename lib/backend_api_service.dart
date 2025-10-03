import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to interact with local backend APIs
class BackendApiService {
  // Local FastAPI URL (PredictionModel/src/api.py defaults to 7860)
  static const String baseUrl = 'http://127.0.0.1:7860';

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

  /// Get flood risk prediction for a ward/region (maps FastAPI -> app contract)
  static Future<Map<String, dynamic>> predictFlood(String wardName) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/predict',
      ).replace(queryParameters: {'area': wardName});
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // FastAPI fields
        final String area = (data['area'] ?? wardName).toString();
        final String matchedArea = (data['matched_area'] ?? area).toString();
        final String floodRisk = (data['flood_risk'] ?? 'unknown').toString();
        final double confidence0to1 = (data['confidence'] is num)
            ? (data['confidence'] as num).toDouble()
            : double.tryParse(data['confidence']?.toString() ?? '') ?? 0.0;

        // Convert to percentage for UI expectations
        final double confidencePct = (confidence0to1 * 100).clamp(0, 100);

        // Optional message/source
        final String modelVersion = (data['model_version'] ?? '').toString();
        final String message = 'Model: ' + modelVersion;

        return {
          'ward': matchedArea,
          'risk_level': floodRisk,
          'confidence': confidencePct,
          'message': message,
          'source': 'FastAPI ML',
        };
      } else {
        final error = _safeJson(response.body);
        throw Exception(error['error'] ?? 'Failed to predict flood risk');
      }
    } catch (e) {
      throw Exception('Network error during flood prediction: ' + e.toString());
    }
  }

  /// Get list of available regions (FastAPI `/areas`)
  static Future<List<String>> getRegions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/areas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['areas'] ?? []);
      } else {
        final error = _safeJson(response.body);
        throw Exception(error['error'] ?? 'Failed to get regions');
      }
    } catch (e) {
      throw Exception('Network error during region fetch: ' + e.toString());
    }
  }

  /// Get evacuation routes for a region
  static Future<Map<String, dynamic>> getEvacuationRoutes({
    required String region,
    int routeCount = 5,
  }) async {
    try {
      // Use the Flask evacuation server (port 5000)
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/routes'),
        headers: _headers,
        body: jsonEncode({'region': region, 'route_count': routeCount}),
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

  /// Get evacuation map HTML for a region with route count
  static Future<String> getEvacuationMap(
    String region, {
    int routeCount = 10,
  }) async {
    try {
      // Use the Flask evacuation server (port 5000)
      String mapUrl =
          'http://127.0.0.1:5000/live_map?region=$region&route_count=$routeCount';

      final response = await http.get(
        Uri.parse(mapUrl),
        headers: {'Accept': 'text/html,application/json'},
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

  // Helper to safely parse JSON error bodies
  static Map<String, dynamic> _safeJson(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
      return {'error': body};
    } catch (_) {
      return {'error': body};
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
      results['evacuation_routes'] = await getEvacuationRoutes(
        region: 'Andheri East',
      );
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
