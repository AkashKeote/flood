import 'package:flutter/material.dart';
import 'backend_api_service.dart';
import 'csv_update_service.dart';
import 'mumbai_areas.dart';

class FloodPredictionService {
  /// Get prediction for a single area and update CSV
  static Future<Map<String, dynamic>> getPredictionAndUpdate(String areaName) async {
    try {
      print('🔍 Getting prediction for: $areaName');
      
      // Get current CSV risk level for comparison
      final currentCSVRisk = await CSVUpdateService.getCurrentRiskLevel(areaName);
      print('📊 Current CSV risk level: $currentCSVRisk');
      
      // Get AI prediction from backend
      final prediction = await BackendApiService.predictFlood(areaName);
      final riskLevel = prediction['risk_level']?.toString() ?? 'Medium';
      final ward = prediction['ward']?.toString() ?? prediction['area']?.toString() ?? areaName;
      final confidence = prediction['confidence']?.toString() ?? '0';
      final message = prediction['message']?.toString() ?? '';
      final source = prediction['source']?.toString() ?? 'Backend';

      print('📊 Backend returned ward: $ward');
      print('🎯 Risk level: $riskLevel');
      print('📈 Confidence: $confidence');

      // Update CSV file with new prediction
      print('🚀🚀🚀 CALLING CSV UPDATE SERVICE 🚀🚀🚀');
      print('📍 Ward: "$ward"');
      print('📈 Risk Level: "$riskLevel"');
      final csvUpdated = await CSVUpdateService.updateFloodRiskLevel(
        areaName: ward,
        newRiskLevel: riskLevel,
      );
      print('💾 CSV Update Result: $csvUpdated');

      return {
        'success': true,
        'risk_level': riskLevel,
        'ward': ward,
        'confidence': confidence,
        'message': message,
        'source': source,
        'previous_csv_risk': currentCSVRisk,
        'csv_updated': csvUpdated,
        'display_message': _formatDisplayMessage(ward, riskLevel, confidence, source, currentCSVRisk, csvUpdated),
      };
    } catch (e) {
      print('❌ Error in getPredictionAndUpdate: $e');
      return {
        'success': false,
        'error': e.toString(),
        'display_message': 'Error: $e',
      };
    }
  }

  /// Bulk update all areas with AI predictions
  static Future<Map<String, dynamic>> bulkUpdateAllAreas({
    required List<String> areas,
    required Function(String status, int current, int total) onProgress,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    int successCount = 0;
    int failCount = 0;

    try {
      print('🚀 Starting bulk update for ${areas.length} areas...');
      
      // Create backup before bulk update
      await CSVUpdateService.createBackup();
      
      for (int i = 0; i < areas.length; i++) {
        final area = areas[i];
        
        onProgress('Updating $area...', i + 1, areas.length);

        try {
          // Get AI prediction
          final prediction = await BackendApiService.predictFlood(area);
          final riskLevel = prediction['risk_level']?.toString() ?? 'Medium';
          final ward = prediction['ward']?.toString() ?? prediction['area']?.toString() ?? area;
          
          // Update CSV
          final success = await CSVUpdateService.updateFloodRiskLevel(
            areaName: ward,
            newRiskLevel: riskLevel,
          );
          
          results[area] = {
            'success': success,
            'risk_level': riskLevel,
            'ward': ward,
            'confidence': prediction['confidence']?.toString() ?? '0',
          };

          if (success) {
            successCount++;
            print('✅ Updated $area: $riskLevel');
          } else {
            failCount++;
            print('⚠️ Failed to update $area in CSV');
          }
          
          // Small delay to avoid overwhelming API
          await Future.delayed(const Duration(milliseconds: 300));
          
        } catch (e) {
          print('❌ Error updating $area: $e');
          results[area] = {
            'success': false,
            'error': e.toString(),
          };
          failCount++;
        }
      }
      
      final summary = 'Bulk update completed!\n'
          'Success: $successCount areas\n'
          'Failed: $failCount areas\n'
          'Total: ${areas.length} areas\n'
          'CSV file updated and ready for GraphML processing';
      
      onProgress(summary, areas.length, areas.length);
      
      return {
        'success': true,
        'total': areas.length,
        'success_count': successCount,
        'fail_count': failCount,
        'results': results,
        'summary': summary,
      };
      
    } catch (e) {
      print('❌ Bulk update failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'summary': 'Bulk update failed: $e',
      };
    }
  }

  /// Get available areas for prediction
  static Future<List<String>> getAvailableAreas() async {
    try {
      // Try backend regions first
      final regions = await BackendApiService.getRegions();
      if (regions.isNotEmpty) {
        print('✅ Loaded ${regions.length} areas from backend');
        return regions;
      }
    } catch (e) {
      print('⚠️ Backend regions failed, falling back to static list: $e');
    }

    // Fallback to static Mumbai areas list
    print('Using Mumbai areas list with ${MumbaiAreas.list.length} areas');
    return MumbaiAreas.list;
  }

  /// Validate prediction data
  static bool isValidPrediction(Map<String, dynamic> prediction) {
    return prediction.containsKey('risk_level') && 
           prediction['risk_level'] != null &&
           prediction['risk_level'].toString().isNotEmpty;
  }

  /// Get areas from CSV file for bulk update
  static Future<List<String>> getAreasFromCSV() async {
    try {
      final csvAreas = await CSVUpdateService.getAllAreas();
      return csvAreas.map((area) => area['area'].toString()).toList();
    } catch (e) {
      print('❌ Error getting areas from CSV: $e');
      return [];
    }
  }

  /// Format display message for single prediction
  static String _formatDisplayMessage(
    String ward,
    String riskLevel,
    String confidence,
    String source,
    String? previousCSVRisk,
    bool csvUpdated,
  ) {
    final confidencePercent = (double.tryParse(confidence)?.toStringAsFixed(0) ?? '0');
    
    String message = 'Ward: $ward\n'
        'Flood Risk: ${riskLevel.toUpperCase()}\n'
        'Confidence: $confidencePercent%\n'
        'Source: $source';
    
    if (previousCSVRisk != null) {
      message += '\nPrevious CSV Risk: $previousCSVRisk';
    }
    
    if (csvUpdated) {
      message += '\n✅ CSV Updated Successfully';
    } else {
      message += '\n⚠️ CSV Update Failed';
    }

    return message;
  }

  /// Show prediction result dialog
  static void showPredictionDialog({
    required BuildContext context,
    required Map<String, dynamic> result,
  }) {
    final isSuccess = result['success'] == true;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isSuccess ? 'Prediction Complete' : 'Prediction Failed'),
          ],
        ),
        content: Text(result['display_message'] ?? result['summary'] ?? 'Unknown result'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show bulk update progress dialog
  static void showBulkUpdateDialog({
    required BuildContext context,
    required List<String> areas,
  }) {
    int currentProgress = 0;
    String currentStatus = 'Preparing bulk update...';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.update_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Bulk Update Progress'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: areas.isEmpty ? 0 : currentProgress / areas.length,
              ),
              const SizedBox(height: 16),
              Text('$currentProgress / ${areas.length}'),
              const SizedBox(height: 8),
              Text(
                currentStatus,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: currentProgress >= areas.length
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ]
              : [],
        ),
      ),
    );

    // Start bulk update
    bulkUpdateAllAreas(
      areas: areas,
      onProgress: (status, current, total) {
        currentProgress = current;
        currentStatus = status;
        // The StatefulBuilder will handle the UI update
      },
    );
  }
}