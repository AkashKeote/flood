import 'dart:io';

Future<void> debugAreaMatching() async {
  print('=== Debugging Area Name Matching ===');
  
  // Test what the Flutter app might be sending
  final testAreas = [
    'Colaba Causeway',
    'COLABA CAUSEWAY', 
    'colaba causeway',
    'Colaba',
    'Causeway',
  ];
  
  // Read CSV to see actual area names
  final csvFile = File('evacuation/mumbai_ward_area_floodrisk_all_102.csv');
  if (!csvFile.existsSync()) {
    print('❌ CSV file not found');
    return;
  }
  
  final lines = await csvFile.readAsLines();
  print('📄 Found ${lines.length} lines in CSV');
  
  // Show first few area names from CSV
  print('\n🏢 Sample areas in CSV:');
  for (int i = 1; i < 6 && i < lines.length; i++) {
    final parts = lines[i].split(',');
    if (parts.length >= 2) {
      print('  Line $i: "${parts[1].trim()}"');
    }
  }
  
  // Test area matching logic
  print('\n🔍 Testing area matching:');
  for (final testArea in testAreas) {
    print('\n🎯 Testing: "$testArea"');
    bool found = false;
    
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length >= 2) {
        final csvArea = parts[1].trim();
        
        // Test the matching logic from CSV update service
        if (csvArea.toLowerCase().contains(testArea.toLowerCase()) || 
            testArea.toLowerCase().contains(csvArea.toLowerCase())) {
          print('  ✅ MATCH: "$csvArea" (line $i)');
          found = true;
          break;
        }
      }
    }
    
    if (!found) {
      print('  ❌ NO MATCH found');
    }
  }
}

void main() async {
  await debugAreaMatching();
}