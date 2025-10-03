import 'dart:convert';
import 'package:http/http.dart' as http;

class CSVUpdateService {
  /// Normalize risk level to match CSV format
  static String normalizeRiskLevel(String riskLevel) {
    final normalized = riskLevel.toLowerCase().trim();
    switch (normalized) {
      case 'very high':
      case 'veryhigh':
      case 'critical':
        return 'Very High';
      case 'high':
        return 'High';
      case 'medium':
      case 'moderate':
        return 'Moderate';
      case 'low':
        return 'Low';
      case 'very low':
      case 'verylow':
      case 'minimal':
        return 'Very Low';
      default:
        return 'Medium';
    }
  }

  /// Get current risk level for an area from API
  static Future<String?> getCurrentRiskLevel(String areaName) async {
    try {
      print('📖 Getting current risk level for: $areaName');
      
      // Use Flask server API instead of direct file access
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/get-current-risk'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'area': areaName}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final riskLevel = data['risk_level'] as String;
          print('✅ Got risk level for $areaName: $riskLevel (${data['source']})');
          return riskLevel;
        }
      }

      print('⚠️ No matching area found for: $areaName');
      return null;
    } catch (e) {
      print('❌ Error reading CSV: $e');
      return null;
    }
  }

  /// Update flood risk level for a specific area via backend API
  static Future<bool> updateFloodRiskLevel({
    required String areaName,
    required String newRiskLevel,
  }) async {
    try {
      print('🔄🔄🔄 CSV UPDATE SERVICE CALLED (VIA API) 🔄🔄🔄');
      print('🎯 Area: "$areaName"');
      print('📊 New Risk Level: "$newRiskLevel"');
      
      // Use Flask server API to update CSV instead of direct file access
      final uri = Uri.parse('http://127.0.0.1:5000/update-csv')
          .replace(queryParameters: {
        'area': areaName,
        'risk_level': newRiskLevel,
      });
      
      print('🌐 Calling API: $uri');
      
      final response = await http.post(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅✅✅ CSV UPDATED VIA API! ✅✅✅');
          print('📁 Message: ${data['message']}');
          return true;
        } else {
          print('❌ API Error: ${data['error']}');
          return false;
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }

    } catch (e) {
      print('❌ Error calling CSV update API: $e');
      return false;
    }
  }

  /// Get all areas from API
  static Future<List<Map<String, dynamic>>> getAllAreas() async {
    try {
      // Use Flask server API instead of direct file access
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/get-all-areas'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final areas = (data['areas'] as List).cast<Map<String, dynamic>>();
          print('✅ Loaded ${areas.length} areas from Flask API');
          return areas;
        }
      }
      
      print('❌ Failed to get areas from API');
      return [];
    } catch (e) {
      print('❌ Error getting areas from API: $e');
      return [];
    }
  }

  /// Create backup of CSV file (disabled for web - data is managed by server)
  static Future<bool> createBackup() async {
    try {
      print('📝 Backup functionality disabled for web - data managed by server');
      return true; // Return success since server manages data
    } catch (e) {
      print('❌ Error in backup: $e');
      return false;
    }
  }
}