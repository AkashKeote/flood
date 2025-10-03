import 'lib/csv_update_service.dart';

void main() async {
  print('🧪 Testing CSV update for Andheri East...');
  
  // Test getting current value
  final current = await CSVUpdateService.getCurrentRiskLevel('Andheri East');
  print('📊 Current risk: $current');
  
  // Test update
  final updated = await CSVUpdateService.updateFloodRiskLevel(
    areaName: 'Andheri East',
    newRiskLevel: 'High',
  );
  print('🔄 Update result: $updated');
  
  // Verify update
  final newValue = await CSVUpdateService.getCurrentRiskLevel('Andheri East');
  print('✅ New risk: $newValue');
}