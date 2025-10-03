import 'package:flutter_test/flutter_test.dart';
import 'package:flood/csv_update_service.dart';

void main() {
  group('CSV Update Service Tests', () {
    test('should get current risk level for Dadar TT', () async {
      final riskLevel = await CSVUpdateService.getCurrentRiskLevel('Dadar TT');
      print('Risk level for Dadar TT: $riskLevel');
      expect(riskLevel, isNotNull);
      expect(riskLevel, isNot('unknown'));
    });

    test('should get all areas', () async {
      final areas = await CSVUpdateService.getAllAreas();
      print('Total areas loaded: ${areas.length}');
      expect(areas, isNotEmpty);
      expect(areas.length, greaterThan(50)); // Should have many areas
    });

    test('should update flood risk level', () async {
      final result = await CSVUpdateService.updateFloodRiskLevel(
        areaName: 'Test Area',
        newRiskLevel: 'High',
      );
      print('Update result: $result');
      expect(result, isTrue);
    });
  });
}