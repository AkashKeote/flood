import 'dart:io';
import 'dart:convert';

Future<void> testApiPredictionAndCsvUpdate() async {
  print('=== Testing API Prediction + CSV Update ===');
  
  // Check initial CSV state
  print('\n1. Checking initial CSV state...');
  await checkCsvValue();
  
  // Make API call like Flutter app would
  print('\n2. Making API prediction call...');
  try {
    final result = await Process.run('curl', [
      '--no-progress-meter',
      '-X', 'POST',
      'http://localhost:8000/predict',
      '-H', 'Content-Type: application/json',
      '-d', '{"area": "Andheri East"}'
    ]);
    
    if (result.exitCode == 0) {
      print('✅ API call successful');
      final response = result.stdout;
      print('📊 API Response: $response');
      
      // Parse JSON response
      try {
        final jsonResponse = json.decode(response);
        final riskLevel = jsonResponse['risk_level']?.toString() ?? 'Unknown';
        print('🎯 Predicted risk level: $riskLevel');
      } catch (e) {
        print('⚠️ Could not parse JSON response: $e');
      }
    } else {
      print('❌ API call failed: ${result.stderr}');
    }
  } catch (e) {
    print('❌ Error making API call: $e');
  }
  
  // Now simulate what Flutter app would do - update CSV
  print('\n3. Simulating Flutter CSV update...');
  await simulateFlutterCsvUpdate('Andheri East', 'High');
  
  // Check final CSV state
  print('\n4. Checking final CSV state...');
  await checkCsvValue();
}

Future<void> checkCsvValue() async {
  final csvFile = File(r'evacuation\mumbai_ward_area_floodrisk_all_102.csv');
  
  if (!csvFile.existsSync()) {
    print('❌ CSV file not found');
    return;
  }
  
  final lines = await csvFile.readAsLines();
  for (String line in lines) {
    if (line.contains('Andheri East')) {
      print('📄 Current CSV line: $line');
      final parts = line.split(',');
      if (parts.length >= 5) {
        print('🏷️ Current risk level: ${parts[4]}');
      }
      break;
    }
  }
}

Future<void> simulateFlutterCsvUpdate(String areaName, String newRiskLevel) async {
  final csvFile = File(r'evacuation\mumbai_ward_area_floodrisk_all_102.csv');
  
  if (!csvFile.existsSync()) {
    print('❌ CSV file not found');
    return;
  }
  
  try {
    final lines = await csvFile.readAsLines();
    bool updated = false;
    
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains(areaName)) {
        final parts = lines[i].split(',');
        if (parts.length >= 5) {
          final oldRisk = parts[4];
          parts[4] = newRiskLevel;
          lines[i] = parts.join(',');
          updated = true;
          print('🔄 Updated CSV: $oldRisk -> $newRiskLevel');
          break;
        }
      }
    }
    
    if (updated) {
      await csvFile.writeAsString(lines.join('\n'));
      print('✅ CSV file updated successfully');
    } else {
      print('❌ Area not found in CSV for update');
    }
    
  } catch (e) {
    print('❌ Error updating CSV: $e');
  }
}

void main() async {
  await testApiPredictionAndCsvUpdate();
}