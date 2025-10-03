import 'dart:io';

class CSVFileHelper {
  /// Find the CSV file using multiple search strategies
  static Future<File?> findCSVFile() async {
    // List of possible paths to check
    final possiblePaths = [
      'evacuation/mumbai_ward_area_floodrisk_all_102.csv',
      '../evacuation/mumbai_ward_area_floodrisk_all_102.csv',
      '../../evacuation/mumbai_ward_area_floodrisk_all_102.csv',
      'mumbai_ward_area_floodrisk_all_102.csv',
      './evacuation/mumbai_ward_area_floodrisk_all_102.csv',
    ];

    // If we can get the current directory, try with absolute paths
    try {
      final currentDir = Directory.current.path;
      print('📁 Current directory: $currentDir');
      
      // Add absolute path variants
      possiblePaths.addAll([
        '$currentDir/evacuation/mumbai_ward_area_floodrisk_all_102.csv',
        '$currentDir/../evacuation/mumbai_ward_area_floodrisk_all_102.csv',
      ]);
    } catch (e) {
      print('⚠️ Could not get current directory: $e');
    }

    // Try each path
    for (final path in possiblePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          print('✅ Found CSV file at: $path');
          return file;
        } else {
          print('🔍 Checked: $path (not found)');
        }
      } catch (e) {
        print('❌ Error checking path $path: $e');
      }
    }

    print('❌ CSV file not found in any location');
    return null;
  }

  /// Check if we can read/write files in this environment
  static Future<bool> checkFileAccess() async {
    try {
      // Try to create a temporary file to test file access
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/flood_test.txt');
      
      await testFile.writeAsString('test');
      final content = await testFile.readAsString();
      await testFile.delete();
      
      return content == 'test';
    } catch (e) {
      print('❌ File access test failed: $e');
      return false;
    }
  }

  /// List files in the current directory for debugging
  static Future<void> listCurrentDirectory() async {
    try {
      final currentDir = Directory.current;
      print('📁 Listing current directory: ${currentDir.path}');
      
      await for (final entity in currentDir.list(recursive: false)) {
        if (entity is Directory) {
          print('📂 ${entity.path}');
        } else {
          print('📄 ${entity.path}');
        }
      }
    } catch (e) {
      print('❌ Error listing directory: $e');
    }
  }
}