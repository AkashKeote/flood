import 'dart:io';
import 'lib/csv_update_service.dart';

/// Simple test to verify CSV functionality
void main() async {
  print('🧪 Testing CSV Update Service');
  print('=' * 50);

  // Test 1: Check CSV file existence
  print('\n1️⃣ Testing CSV file access...');
  final currentRisk = await CSVUpdateService.getCurrentRiskLevel('Colaba');
  if (currentRisk != null) {
    print('✅ CSV file accessible, current risk for Colaba: $currentRisk');
  } else {
    print('❌ Could not access CSV file');
    
    // Debug: List current directory
    print('\n🔍 Current directory contents:');
    try {
      final dir = Directory.current;
      await for (final entity in dir.list()) {
        print('   ${entity.path}');
      }
    } catch (e) {
      print('❌ Error listing directory: $e');
    }
    return;
  }

  // Test 2: Test normalization
  print('\n2️⃣ Testing risk level normalization...');
  final testRisks = ['high', 'very high', 'medium', 'low', 'unknown'];
  for (final risk in testRisks) {
    final normalized = CSVUpdateService.normalizeRiskLevel(risk);
    print('   $risk → $normalized');
  }

  // Test 3: Test update (if CSV is accessible)
  print('\n3️⃣ Testing CSV update...');
  final testArea = 'Colaba Causeway';
  final newRisk = 'High';
  
  print('🔄 Attempting to update $testArea to $newRisk...');
  final updateSuccess = await CSVUpdateService.updateFloodRiskLevel(
    areaName: testArea,
    newRiskLevel: newRisk,
  );
  
  if (updateSuccess) {
    print('✅ Update successful!');
    
    // Verify the update
    final updatedRisk = await CSVUpdateService.getCurrentRiskLevel(testArea);
    print('🔍 Verification: $testArea now has risk level: $updatedRisk');
  } else {
    print('❌ Update failed');
  }

  print('\n' + '=' * 50);
  print('🏁 Test completed');
}