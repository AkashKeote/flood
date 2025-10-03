import 'dart:io';
import 'dart:convert';

Future<void> testCsvUpdateSimple() async {
  print('Testing CSV update for Andheri East...');
  
  // Mock CSV update logic without Flutter dependencies
  final csvFilePath = r'evacuation\mumbai_ward_area_floodrisk_all_102.csv';
  final file = File(csvFilePath);
  
  if (!file.existsSync()) {
    print('CSV file not found at $csvFilePath');
    
    // Try alternate paths
    final alternatePaths = [
      r'.\evacuation\mumbai_ward_area_floodrisk_all_102.csv',
      r'flood\evacuation\mumbai_ward_area_floodrisk_all_102.csv',
      r'.\flood\evacuation\mumbai_ward_area_floodrisk_all_102.csv',
    ];
    
    for (String path in alternatePaths) {
      final altFile = File(path);
      if (altFile.existsSync()) {
        print('Found CSV file at alternate path: $path');
        final lines = await altFile.readAsLines();
        
        print('CSV file has ${lines.length} lines');
        
        // Check current value for Andheri East
        for (String line in lines) {
          if (line.contains('ANDHERI EAST')) {
            print('Current line for Andheri East: $line');
            
            // Update the line
            final parts = line.split(',');
            if (parts.length >= 3) {
              parts[2] = 'High'; // Update flood risk level
              final updatedLine = parts.join(',');
              print('Updated line would be: $updatedLine');
              
              // Update the file
              final updatedLines = lines.map((l) => 
                l.contains('ANDHERI EAST') ? updatedLine : l
              ).toList();
              
              await altFile.writeAsString(updatedLines.join('\n'));
              print('✅ CSV file updated successfully!');
              
              // Verify the update
              final verifyLines = await altFile.readAsLines();
              for (String vLine in verifyLines) {
                if (vLine.contains('ANDHERI EAST')) {
                  print('Verified updated line: $vLine');
                  break;
                }
              }
            }
            break;
          }
        }
        return;
      }
    }
    
    print('❌ CSV file not found in any expected location');
  }
}

void main() async {
  await testCsvUpdateSimple();
}