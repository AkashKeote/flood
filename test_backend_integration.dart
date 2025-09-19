import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify the PredictionModel backend integration
void main() async {
  print('🧪 Testing PredictionModel Backend Integration...\n');

  const baseUrl = 'http://127.0.0.1:7860';

  try {
    // Test 1: Health check
    print('1. Testing health check...');
    final healthResponse = await http
        .get(
          Uri.parse('$baseUrl/health'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 5));

    if (healthResponse.statusCode == 200) {
      print('✅ Health check passed');
      final healthData = jsonDecode(healthResponse.body);
      print('   Status: ${healthData['status']}');
      print('   API Version: ${healthData['api_version']}');
    } else {
      print('❌ Health check failed: ${healthResponse.statusCode}');
      return;
    }

    // Test 2: Get available areas
    print('\n2. Testing areas endpoint...');
    final areasResponse = await http.get(
      Uri.parse('$baseUrl/areas'),
      headers: {'Accept': 'application/json'},
    );

    if (areasResponse.statusCode == 200) {
      final areasData = jsonDecode(areasResponse.body);
      final areas = List<String>.from(areasData['areas'] ?? []);
      print('✅ Areas loaded successfully');
      print('   Total areas: ${areas.length}');
      print('   Sample areas: ${areas.take(5).join(', ')}...');
    } else {
      print('❌ Areas endpoint failed: ${areasResponse.statusCode}');
      return;
    }

    // Test 3: Test prediction for a sample area
    print('\n3. Testing prediction endpoint...');
    final testArea = 'Andheri East';
    final predictionResponse = await http.get(
      Uri.parse('$baseUrl/predict?area=$testArea'),
      headers: {'Accept': 'application/json'},
    );

    if (predictionResponse.statusCode == 200) {
      final predictionData = jsonDecode(predictionResponse.body);
      print('✅ Prediction successful');
      print('   Area: ${predictionData['area']}');
      print('   Matched Area: ${predictionData['matched_area']}');
      print('   Flood Risk: ${predictionData['flood_risk']}');
      print('   Rainfall: ${predictionData['rainfall']} mm');
      print('   Date: ${predictionData['date']}');
      print('   Match Score: ${predictionData['match_score']}%');
    } else {
      print('❌ Prediction failed: ${predictionResponse.statusCode}');
      print('   Response: ${predictionResponse.body}');
    }

    print('\n🎉 Backend integration test completed!');
    print('\n📝 To start the backend:');
    print('   cd PredictionModel');
    print('   python app.py');
    print(
      '\n📱 The Flutter app should now work with the PredictionModel backend!',
    );
  } catch (e) {
    print('❌ Test failed with error: $e');
    print('\n🔧 Make sure the PredictionModel backend is running:');
    print('   cd PredictionModel');
    print('   python app.py');
  }
}

