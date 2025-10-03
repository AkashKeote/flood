import 'lib/flood_prediction_service.dart';

void main() async {
  print('🧪 Testing Flutter App Integration...');
  print('=' * 50);
  
  // Test the exact same flow as Flutter app
  print('\n1️⃣ Testing getPredictionAndUpdate (same as "Get AI Prediction" button)...');
  
  final result = await FloodPredictionService.getPredictionAndUpdate('Andheri East');
  
  print('\n📊 Result:');
  result.forEach((key, value) {
    print('   $key: $value');
  });
  
  if (result['success'] == true) {
    print('\n✅ SUCCESS: This should update the CSV file');
    print('🎯 Risk Level: ${result['risk_level']}');
    print('📍 Ward: ${result['ward']}');
    print('📈 Confidence: ${result['confidence']}');
    print('💾 CSV Updated: ${result['csv_updated']}');
  } else {
    print('\n❌ FAILED: ${result['error']}');
  }
  
  print('\n' + '=' * 50);
  print('🏁 Integration test completed');
}