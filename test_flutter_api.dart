import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> testFlutterCsvUpdateApi() async {
  print('=== Testing Flutter CSV Update API ===');
  
  try {
    // Test the new CSV update API endpoint
    final uri = Uri.parse('http://localhost:7860/update-csv')
        .replace(queryParameters: {
      'area': 'Chembur',
      'risk_level': 'High',
    });
    
    print('🌐 Calling API: $uri');
    
    final response = await http.post(uri);
    
    print('📡 Status Code: ${response.statusCode}');
    print('📄 Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        print('✅ CSV Update API Success!');
        print('📁 Message: ${data['message']}');
        print('🎯 CSV Path: ${data['csv_path']}');
      } else {
        print('❌ API Error: ${data['error']}');
      }
    } else {
      print('❌ HTTP Error: ${response.statusCode}');
    }
    
  } catch (e) {
    print('❌ Error calling API: $e');
  }
}

void main() async {
  await testFlutterCsvUpdateApi();
}