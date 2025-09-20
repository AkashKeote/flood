// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'mumbai_prediction_data.dart';
// import 'weather_service.dart';
// import 'user_service.dart';
// import 'ml_flood_predictor.dart';
// import 'fastapi_flood_service.dart';

// class FloodPredictionPage extends StatefulWidget {
//   const FloodPredictionPage({super.key});

//   @override
//   State<FloodPredictionPage> createState() => _FloodPredictionPageState();
// }

// class _FloodPredictionPageState extends State<FloodPredictionPage> {
//   String _userSelectedRegion = 'Andheri East'; // User's home region
//   bool _isLoading = false;
//   Map<String, dynamic>? _predictionData;
//   String _errorMessage = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadUserRegion();
//   }

//   // Load user's selected region from UserService
//   Future<void> _loadUserRegion() async {
//     try {
//       final userData = await UserService.getUserData();
//       if (userData != null && userData['area'] != null) {
//         final userArea = userData['area'].toString();
//         // Always use the city selected on UserSetupPage
//         final matchingRegion = userArea;
//         setState(() {
//           _userSelectedRegion = matchingRegion;
//         });
//         print('👤 User region loaded: $matchingRegion');
//         // Immediately predict for the user's selected city only
//         await _predictFloodForRegion(matchingRegion);
//       }
//     } catch (e) {
//       print('❌ Error loading user region: $e');
//     }
//   }

//   // Predict flood for selected region (user's city)
//   Future<void> _predictFloodForRegion(String regionName) async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });

//     try {
//       // First try backend FastAPI prediction (uses trained model + forecast CSV)
//       try {
//         final backendResult = await FastApiFloodService.predict(regionName);

//         final backendPredictions = {
//           'region_name': backendResult['matched_area'] ?? regionName,
//           'overall_risk': (backendResult['flood_risk'] ?? 'Low').toString(),
//           'overall_risk_score': 0.0,
//           'confidence': ((backendResult['match_score'] ?? 80) as num) / 100.0,
//           'daily_predictions': <Map<String, dynamic>>[],
//           'model_info': {
//             'algorithm': 'Backend FastAPI (Ensemble Model)',
//             'features_used': ['trained_model'],
//             'accuracy_estimate': 0.0,
//           },
//           'feature_contributions': {},
//           'weather_summary': {
//             'total_rainfall_7days': backendResult['rainfall'] ?? 0.0,
//             'max_intensity': 0.0,
//             'rainy_days_count': null,
//             'average_daily_rainfall': null,
//           },
//           'last_updated': DateTime.now().toIso8601String(),
//         };

//         setState(() {
//           _isLoading = false;
//           _predictionData = backendPredictions;
//         });

//         return; // Show backend result, skip local ML fallback
//       } catch (_) {
//         // Ignore and fallback to local ML below
//       }

//       // Get region static data
//       final regionData = MumbaiPredictionData.getRegionData(regionName);
//       if (regionData == null || regionData.isEmpty) {
//         throw Exception('Region not found in training data');
//       }

//       print('🏢 Predicting for region: $regionName');

//       // Get weather forecast
//       final weatherResult = await WeatherService.getWeatherForecast(
//         latitude: regionData['latitude'],
//         longitude: regionData['longitude'],
//       );

//       if (!weatherResult['success']) {
//         throw Exception(weatherResult['error']);
//       }

//       final weatherData = weatherResult['data'];

//       print('🌤️ Weather data received: ${weatherData.keys}');
//       print('🏢 Region data keys: ${regionData.keys}');

//       // Calculate flood risk predictions using ML-inspired model
//       final predictions = MLFloodPredictor.predictFloodRisk(
//         staticData: regionData,
//         weatherData: weatherData,
//       );

//       setState(() {
//         _isLoading = false;
//         _predictionData = predictions;
//       });

//       print('✅ Prediction completed for $regionName');
//     } catch (e) {
//       print('❌ Prediction error: $e');
//       setState(() {
//         _isLoading = false;
//         _errorMessage = 'Error predicting flood: $e';
//       });
//     }
//   }

//   Color _getRiskColor(String risk) {
//     switch (risk.toLowerCase()) {
//       case 'critical':
//         return Color(0xFFFF1744);
//       case 'high':
//         return Color(0xFFFF5722);
//       case 'moderate':
//         return Color(0xFFFF9800);
//       case 'low':
//         return Color(0xFF4CAF50);
//       default:
//         return Colors.grey;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFFF5F5F5),
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Color(0xFF22223B),
//         title: Text(
//           '🌊 Flood Prediction',
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: _isLoading
//           ? _buildLoadingWidget()
//           : SingleChildScrollView(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // User's Area Prediction Section
//                   _buildUserAreaSection(),

//                   SizedBox(height: 24),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildLoadingWidget() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22223B)),
//           ),
//           SizedBox(height: 16),
//           Text(
//             'Fetching real-time weather data...',
//             style: GoogleFonts.poppins(fontSize: 16, color: Color(0xFF666666)),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'This may take a few seconds',
//             style: GoogleFonts.poppins(fontSize: 14, color: Color(0xFF999999)),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserAreaSection() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             children: [
//               Icon(Icons.home, color: Color(0xFF22223B), size: 24),
//               SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   'Your Area: $_userSelectedRegion',
//                   style: GoogleFonts.poppins(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF22223B),
//                   ),
//                 ),
//               ),
//               if (_predictionData != null)
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: _getRiskColor(_predictionData!['overall_risk']),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     _predictionData!['overall_risk'].toUpperCase(),
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//             ],
//           ),

//           if (_errorMessage.isNotEmpty) ...[
//             SizedBox(height: 16),
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.error, color: Colors.red, size: 20),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       _errorMessage,
//                       style: GoogleFonts.poppins(
//                         color: Colors.red,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],

//           if (_predictionData != null) ...[
//             SizedBox(height: 20),
//             _buildMLModelInfo(_predictionData!),
//             SizedBox(height: 16),
//             _build7DayForecast(_predictionData!),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _build7DayForecast(Map<String, dynamic> predictionData) {
//     final dailyPredictions =
//         predictionData['daily_predictions'] as List<Map<String, dynamic>>;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           '📅 7-Day Forecast',
//           style: GoogleFonts.poppins(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF22223B),
//           ),
//         ),
//         SizedBox(height: 12),

//         // Daily cards
//         ...dailyPredictions.map((day) {
//           final date = DateTime.parse(day['date']);
//           final dayName = [
//             'Mon',
//             'Tue',
//             'Wed',
//             'Thu',
//             'Fri',
//             'Sat',
//             'Sun',
//           ][date.weekday - 1];

//           return Container(
//             margin: EdgeInsets.only(bottom: 8),
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(
//                 color: _getRiskColor(day['risk_level']).withOpacity(0.3),
//                 width: 1,
//               ),
//             ),
//             child: Row(
//               children: [
//                 // Day
//                 SizedBox(
//                   width: 50,
//                   child: Text(
//                     '$dayName\n${date.day}',
//                     style: GoogleFonts.poppins(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                       color: Color(0xFF666666),
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),

//                 SizedBox(width: 12),

//                 // Risk Level
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: _getRiskColor(day['risk_level']),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     day['risk_level'],
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),

//                 SizedBox(width: 12),

//                 // Weather info
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '${day['precipitation'].toStringAsFixed(1)}mm rain',
//                         style: GoogleFonts.poppins(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                           color: Color(0xFF22223B),
//                         ),
//                       ),
//                       if (day['intensity'] > 0)
//                         Text(
//                           'Intensity: ${day['intensity'].toStringAsFixed(1)}mm/hr',
//                           style: GoogleFonts.poppins(
//                             fontSize: 10,
//                             color: Color(0xFF666666),
//                           ),
//                         ),
//                       if (day['confidence'] != null)
//                         Text(
//                           'Confidence: ${(day['confidence'] * 100).toStringAsFixed(0)}%',
//                           style: GoogleFonts.poppins(
//                             fontSize: 9,
//                             color: Colors.blue,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }),

//         SizedBox(height: 12),

//         // Summary
//         Container(
//           padding: EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.blue.withOpacity(0.05),
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: Colors.blue.withOpacity(0.2)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Weekly Summary',
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF22223B),
//                 ),
//               ),
//               SizedBox(height: 8),
//               Text(
//                 'Total Rainfall: ${(predictionData['weather_summary']?['total_rainfall_7days'] ?? 0.0).toStringAsFixed(1)}mm',
//                 style: GoogleFonts.poppins(
//                   fontSize: 12,
//                   color: Color(0xFF666666),
//                 ),
//               ),
//               Text(
//                 'Rainy Days: ${predictionData['weather_summary']?['rainy_days_count'] ?? 0}',
//                 style: GoogleFonts.poppins(
//                   fontSize: 12,
//                   color: Color(0xFF666666),
//                 ),
//               ),
//               Text(
//                 'Max Intensity: ${(predictionData['weather_summary']?['max_intensity'] ?? 0.0).toStringAsFixed(1)}mm/hr',
//                 style: GoogleFonts.poppins(
//                   fontSize: 12,
//                   color: Color(0xFF666666),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildMLModelInfo(Map<String, dynamic> predictionData) {
//     final modelInfo = predictionData['model_info'];
//     final confidence = (predictionData['confidence'] * 100).toStringAsFixed(1);

//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blue.withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.psychology, color: Colors.blue, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 'ML Model Prediction',
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF22223B),
//                 ),
//               ),
//               Spacer(),
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.green,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   '$confidence% Confidence',
//                   style: GoogleFonts.poppins(
//                     color: Colors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           Text(
//             'Algorithm: ${modelInfo['algorithm']}',
//             style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
//           ),
//           Text(
//             'Training Accuracy: ${(modelInfo['accuracy_estimate'] * 100).toStringAsFixed(1)}%',
//             style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
//           ),
//           Text(
//             'Features: ${modelInfo['features_used'].length} variables analyzed',
//             style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Prevents overfitting through ensemble voting and calibration',
//             style: GoogleFonts.poppins(
//               fontSize: 11,
//               color: Color(0xFF999999),
//               fontStyle: FontStyle.italic,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Extension to convert hex color strings to Color objects
// extension ColorExtension on Color {
//   static Color fromHex(String hexString) {
//     final buffer = StringBuffer();
//     if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
//     buffer.write(hexString.replaceFirst('#', ''));
//     return Color(int.parse(buffer.toString(), radix: 16));
//   }
// }
