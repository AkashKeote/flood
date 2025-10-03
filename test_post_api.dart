import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> testFlutterPostApi() async {
  print('=== Testing Flutter POST API ===');
  
  try {
    // Test the CSV update with POST method
    final uri = Uri.parse('http://localhost:7860/update-csv')
        .replace(queryParameters: {
      'area': 'Five Gardens Underpass',
      'risk_level': 'High',
    });
    
    print('🌐 Calling API with POST: $uri');
    
    final response = await http.post(uri);
    
    print('📡 Status Code: ${response.statusCode}');
    print('📄 Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        print('✅ POST API Success!');
        print('📁 Message: ${data['message']}');
      } else {
        print('❌ API Error: ${data['error']}');
      }
    } else {
      print('❌ HTTP Error: ${response.statusCode}');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

void main() async {
  await testFlutterPostApi();
}