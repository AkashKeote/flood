import 'dart:io';

Future<void> testDirectCsvUpdate() async {
  print('=== Testing Direct CSV Update ===');
  
  // Path to CSV file
  final csvPath = r'evacuation\mumbai_ward_area_floodrisk_all_102.csv';
  final csvFile = File(csvPath);
  
  if (!csvFile.existsSync()) {
    print('❌ CSV file not found: $csvPath');
    return;
  }
  
  print('✅ CSV file found: $csvPath');
  
  try {
    // Read the file
    final lines = await csvFile.readAsLines();
    print('📄 CSV has ${lines.length} lines');
    
    // Find Andheri East
    int lineIndex = -1;
    String currentLine = '';
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('Andheri East')) {
        lineIndex = i;
        currentLine = lines[i];
        break;
      }
    }
    
    if (lineIndex == -1) {
      print('❌ Andheri East not found in CSV');
      return;
    }
    
    print('📍 Found Andheri East at line ${lineIndex + 1}: $currentLine');
    
    // Update the line
    final parts = currentLine.split(',');
    if (parts.length >= 5) {
      final originalRisk = parts[4];
      parts[4] = 'High'; // Update flood risk level
      final updatedLine = parts.join(',');
      
      print('🔄 Updating: $originalRisk -> High');
      
      // Update the lines
      lines[lineIndex] = updatedLine;
      
      // Write back to file
      await csvFile.writeAsString(lines.join('\n'));
      print('✅ CSV file updated successfully!');
      
      // Verify update
      final verifyLines = await csvFile.readAsLines();
      final verifyLine = verifyLines[lineIndex];
      print('✔️ Verification: $verifyLine');
      
      if (verifyLine.contains('High')) {
        print('🎉 SUCCESS: CSV update confirmed!');
      } else {
        print('❌ FAILED: CSV update not confirmed');
      }
    } else {
      print('❌ Invalid CSV format - expected at least 5 columns');
    }
    
  } catch (e) {
    print('❌ Error updating CSV: $e');
  }
}

void main() async {
  await testDirectCsvUpdate();
}