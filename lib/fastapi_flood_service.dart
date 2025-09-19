import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to interact with the local FastAPI backend in `FloosdPredictionBackend`
class FastApiFloodService {
  /// Change this if your FastAPI runs on a different host/port
  static String baseUrl = 'http://127.0.0.1:7860';

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Health check
  static Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// List areas from backend
  static Future<List<String>> getAreas() async {
    final res = await http.get(
      Uri.parse('$baseUrl/areas'),
      headers: _jsonHeaders,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<String>.from(data['areas'] ?? const []);
    }
    throw Exception('Failed to load areas');
  }

  /// Predict flood risk using backend
  /// Returns a map like: { area, date, flood_risk, rainfall, matched_area, match_score }
  static Future<Map<String, dynamic>> predict(
    String area, {
    String? date,
  }) async {
    final uri = Uri.parse('$baseUrl/predict').replace(
      queryParameters: {
        'area': area,
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Backend prediction failed: ${res.statusCode}');
  }
}
