import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mumbai_prediction_data.dart';
import 'weather_service.dart';
import 'user_service.dart';
import 'ml_flood_predictor.dart';
import 'fastapi_flood_service.dart';

class FloodPredictionPage extends StatefulWidget {
  const FloodPredictionPage({super.key});

  @override
  State<FloodPredictionPage> createState() => _FloodPredictionPageState();
}

class _FloodPredictionPageState extends State<FloodPredictionPage> {
  String _selectedRegion = 'Andheri East'; // Default region
  String _userSelectedRegion = 'Andheri East'; // User's home region
  bool _isLoading = false;
  bool _isLoadingAlternate = false;
  bool _showAlternateRegion = false;
  Map<String, dynamic>? _predictionData;
  Map<String, dynamic>? _alternateRegionData;
  String _errorMessage = '';
  String _searchQuery = '';
  
  // All regions from backend
  List<String> _allRegions = [];
  List<String> _filteredRegions = [];
  bool _loadingRegions = false;

  @override
  void initState() {
    super.initState();
    _loadBackendRegions();
    _loadUserRegion();
    _loadUserRegionPrediction();
  }

  // Load regions from backend
  Future<void> _loadBackendRegions() async {
    setState(() {
      _loadingRegions = true;
    });
    
    try {
      final regions = await FastApiFloodService.getAreas();
      setState(() {
        _allRegions = regions;
        _updateFilteredRegions();
        _loadingRegions = false;
      });
      print('✅ Loaded ${regions.length} regions from backend: $regions');
    } catch (e) {
      print('❌ Failed to load backend regions: $e');
      // Fallback to local regions
      setState(() {
        _allRegions = MumbaiPredictionData.getAllRegionNames();
        _updateFilteredRegions();
        _loadingRegions = false;
      });
    }
  }

  // Load user's selected region from UserService
  Future<void> _loadUserRegion() async {
    try {
      final userData = await UserService.getUserData();
      if (userData != null && userData['area'] != null) {
        final userArea = userData['area'].toString();
        // Check if user's area exists in our regions (case-insensitive)
        final matchingRegion = _allRegions.isNotEmpty 
          ? _allRegions.firstWhere(
              (region) => region.toLowerCase() == userArea.toLowerCase(),
              orElse: () => _allRegions.isNotEmpty ? _allRegions.first : 'Andheri East',
            )
          : 'Andheri East';
        
    setState(() {
          _userSelectedRegion = matchingRegion;
          _selectedRegion = matchingRegion;
        });
        
        print('👤 User region loaded: $matchingRegion');
      }
    } catch (e) {
      print('❌ Error loading user region: $e');
    }
  }

  // Load prediction for user's region automatically
  Future<void> _loadUserRegionPrediction() async {
    await _predictFloodForRegion(_userSelectedRegion, isUserRegion: true);
  }

  // Predict flood for any region
  Future<void> _predictFloodForRegion(String regionName, {bool isUserRegion = false}) async {
    setState(() {
      if (isUserRegion) {
      _isLoading = true;
      } else {
        _isLoadingAlternate = true;
      }
      _errorMessage = '';
    });

    try {
      // First try backend FastAPI prediction (uses trained model + forecast CSV)
      try {
        final backendResult = await FastApiFloodService.predict(regionName);

        final backendPredictions = {
          'region_name': backendResult['matched_area'] ?? regionName,
          'overall_risk': (backendResult['flood_risk'] ?? 'Low').toString(),
          'overall_risk_score': 0.0,
          'confidence': ((backendResult['match_score'] ?? 80) as num) / 100.0,
          'daily_predictions': <Map<String, dynamic>>[],
          'model_info': {
            'algorithm': 'Backend FastAPI (Ensemble Model)',
            'features_used': ['trained_model'],
            'accuracy_estimate': 0.0,
          },
          'feature_contributions': {},
          'weather_summary': {
            'total_rainfall_7days': backendResult['rainfall'] ?? 0.0,
            'max_intensity': 0.0,
            'rainy_days_count': null,
            'average_daily_rainfall': null,
          },
          'last_updated': DateTime.now().toIso8601String(),
        };

        setState(() {
          if (isUserRegion) {
          _isLoading = false;
            _predictionData = backendPredictions;
          } else {
            _isLoadingAlternate = false;
            _alternateRegionData = backendPredictions;
          }
        });

        return; // Show backend result, skip local ML fallback
      } catch (_) {
        // Ignore and fallback to local ML below
      }

      // Get region static data
      final regionData = MumbaiPredictionData.getRegionData(regionName);
      if (regionData == null || regionData.isEmpty) {
        throw Exception('Region not found in training data');
      }

      print('🏢 Predicting for region: $regionName');
      
      // Get weather forecast
      final weatherResult = await WeatherService.getWeatherForecast(
        latitude: regionData['latitude'],
        longitude: regionData['longitude'],
      );

      if (!weatherResult['success']) {
        throw Exception(weatherResult['error']);
      }

      final weatherData = weatherResult['data'];
      
      print('🌤️ Weather data received: ${weatherData.keys}');
      print('🏢 Region data keys: ${regionData.keys}');
      
      // Calculate flood risk predictions using ML-inspired model
      final predictions = MLFloodPredictor.predictFloodRisk(
        staticData: regionData,
        weatherData: weatherData,
      );
      
      setState(() {
        if (isUserRegion) {
        _isLoading = false;
          _predictionData = predictions;
        } else {
          _isLoadingAlternate = false;
          _alternateRegionData = predictions;
        }
      });
      
      print('✅ Prediction completed for $regionName');
      
    } catch (e) {
      print('❌ Prediction error: $e');
      setState(() {
        if (isUserRegion) {
        _isLoading = false;
        } else {
          _isLoadingAlternate = false;
        }
        _errorMessage = 'Error predicting flood: $e';
      });
    }
  }



  void _updateFilteredRegions() {
    _filteredRegions = _allRegions.where((region) {
      return region.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
    // If current selected region is not in filtered list, reset to first item
    if (_filteredRegions.isNotEmpty && !_filteredRegions.contains(_selectedRegion)) {
      _selectedRegion = _filteredRegions.first;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical': return Color(0xFFFF1744);
      case 'high': return Color(0xFFFF5722);
      case 'moderate': return Color(0xFFFF9800);
      case 'low': return Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF22223B),
        title: Text(
          '🌊 Flood Prediction',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? _buildLoadingWidget()
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Main City Selection
                _buildMainCitySelector(),
                
                SizedBox(height: 20),
                
                // User's Area Prediction Section
                _buildUserAreaSection(),
                
                SizedBox(height: 24),
                
                // Alternative Region Section
                _buildAlternativeRegionSection(),
                
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22223B)),
          ),
          SizedBox(height: 16),
                Text(
            'Fetching real-time weather data...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
          SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
                ),
              ],
            ),
    );
  }

  Widget _buildMainCitySelector() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_city, color: Color(0xFF22223B), size: 24),
              SizedBox(width: 12),
              Text(
                '🏙️ Select City/Region',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF22223B),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          if (_loadingRegions) ...[
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22223B)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading cities...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Search Bar
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _updateFilteredRegions();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search city (e.g., Bandra, Colaba, Dadar)...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF22223B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF22223B), width: 2),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // City Dropdown
            DropdownButtonFormField<String>(
              value: _filteredRegions.contains(_selectedRegion) ? _selectedRegion : null,
              decoration: InputDecoration(
                labelText: 'Choose City/Region',
                prefixIcon: Icon(Icons.map, color: Color(0xFF22223B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF22223B), width: 2),
                ),
              ),
              items: _filteredRegions.map((region) {
                return DropdownMenuItem<String>(
                  value: region,
                  child: Text(
                    region,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRegion = newValue;
                  });
                  _predictFloodForRegion(newValue, isUserRegion: false);
                }
              },
            ),
            
            SizedBox(height: 16),
            
            // Quick City Buttons
            if (_allRegions.isNotEmpty) ...[
              Text(
                'Quick Select:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allRegions.take(4).map((region) {
                  final isSelected = _selectedRegion == region;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRegion = region;
                      });
                      _predictFloodForRegion(region, isUserRegion: false);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF22223B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Color(0xFF22223B) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        region,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Color(0xFF666666),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildUserAreaSection() {
    return Container(
              width: double.infinity,
      padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
        borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Header
                  Row(
                    children: [
              Icon(Icons.home, color: Color(0xFF22223B), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                  'Your Area: $_userSelectedRegion',
                  style: GoogleFonts.poppins(
                            fontSize: 18,
                    fontWeight: FontWeight.w600,
                            color: Color(0xFF22223B),
                          ),
                        ),
                      ),
              if (_predictionData != null)
                        Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                    color: _getRiskColor(_predictionData!['overall_risk']),
                    borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                    _predictionData!['overall_risk'].toUpperCase(),
                    style: GoogleFonts.poppins(
                              color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
          
          if (_errorMessage.isNotEmpty) ...[
            SizedBox(height: 16),
                  Container(
              padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                        Expanded(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                                  fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
          
                     if (_predictionData != null) ...[
             SizedBox(height: 20),
             _buildMLModelInfo(_predictionData!),
             SizedBox(height: 16),
             _build7DayForecast(_predictionData!),
           ],
        ],
      ),
    );
  }

  Widget _buildAlternativeRegionSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          InkWell(
            onTap: () {
              setState(() {
                _showAlternateRegion = !_showAlternateRegion;
              });
            },
                          child: Row(
                            children: [
                Icon(Icons.explore, color: Color(0xFF22223B), size: 24),
                SizedBox(width: 12),
                              Expanded(
                  child: Text(
                    '🔍 Explore Other Regions',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF22223B),
                                        ),
                                      ),
                                        ),
                Icon(
                  _showAlternateRegion ? Icons.expand_less : Icons.expand_more,
                  color: Color(0xFF22223B),
                                      ),
                                    ],
                                  ),
                                ),
          
          if (_showAlternateRegion) ...[
            SizedBox(height: 20),
            
            // Search Bar
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _updateFilteredRegions();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search region (e.g., Bandra, Colaba)...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF22223B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF22223B), width: 2),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Region Dropdown
            DropdownButtonFormField<String>(
              initialValue: _filteredRegions.contains(_selectedRegion) ? _selectedRegion : null,
              decoration: InputDecoration(
                labelText: 'Select Region',
                prefixIcon: Icon(Icons.location_city, color: Color(0xFF22223B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF22223B), width: 2),
                ),
              ),
              items: _filteredRegions.map((region) {
                return DropdownMenuItem<String>(
                  value: region,
                  child: Text(
                    region,
                    style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      );
                    }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                        setState(() {
                    _selectedRegion = newValue;
                        });
                      }
                    },
                  ),
                  
            SizedBox(height: 16),
                  
                  // Predict Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                onPressed: _isLoadingAlternate ? null : () {
                  _predictFloodForRegion(_selectedRegion, isUserRegion: false);
                },
                      style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF22223B),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                child: _isLoadingAlternate
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                          'Predicting...',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                                    fontSize: 16,
                            fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                  : Text(
                                  'Predict Flood Risk',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                                    fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ),

            if (_alternateRegionData != null) ...[
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Expanded(
                      child: Text(
                            'Results for: ${_alternateRegionData!['region_name']}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22223B),
                ),
              ),
            ),
                  Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                            color: _getRiskColor(_alternateRegionData!['overall_risk']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _alternateRegionData!['overall_risk'].toUpperCase(),
                            style: GoogleFonts.poppins(
                      color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _build7DayForecast(_alternateRegionData!),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _build7DayForecast(Map<String, dynamic> predictionData) {
    final dailyPredictions = predictionData['daily_predictions'] as List<Map<String, dynamic>>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📅 7-Day Forecast',
          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22223B),
                            ),
                          ),
        SizedBox(height: 12),
        
        // Daily cards
        ...dailyPredictions.map((day) {
          final date = DateTime.parse(day['date']);
          final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
          
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
                             border: Border.all(
                 color: _getRiskColor(day['risk_level']).withOpacity(0.3),
                 width: 1,
               ),
            ),
            child: Row(
                            children: [
                // Day
                SizedBox(
                  width: 50,
                  child: Text(
                    '$dayName\n${date.day}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                              color: Color(0xFF666666),
                            ),
                    textAlign: TextAlign.center,
                    ),
                  ),
                  
                SizedBox(width: 12),
                  
                // Risk Level
                  Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                     color: _getRiskColor(day['risk_level']),
                     borderRadius: BorderRadius.circular(12),
                   ),
                  child: Text(
                    day['risk_level'],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                SizedBox(width: 12),
                
                                 // Weather info
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         '${day['precipitation'].toStringAsFixed(1)}mm rain',
                         style: GoogleFonts.poppins(
                           fontSize: 12,
                           fontWeight: FontWeight.w500,
                           color: Color(0xFF22223B),
                         ),
                       ),
                       if (day['intensity'] > 0)
                         Text(
                           'Intensity: ${day['intensity'].toStringAsFixed(1)}mm/hr',
                           style: GoogleFonts.poppins(
                             fontSize: 10,
                             color: Color(0xFF666666),
                           ),
                         ),
                       if (day['confidence'] != null)
                         Text(
                           'Confidence: ${(day['confidence'] * 100).toStringAsFixed(0)}%',
                           style: GoogleFonts.poppins(
                             fontSize: 9,
                             color: Colors.blue,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                     ],
                   ),
                 ),
                ],
            ),
          );
        }),
        
        SizedBox(height: 12),
        
        // Summary
        Container(
          padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Weekly Summary',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                color: Color(0xFF22223B),
              ),
            ),
              SizedBox(height: 8),
              Text(
                'Total Rainfall: ${(predictionData['weather_summary']?['total_rainfall_7days'] ?? 0.0).toStringAsFixed(1)}mm',
                style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
              ),
            Text(
                'Rainy Days: ${predictionData['weather_summary']?['rainy_days_count'] ?? 0}',
                style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
              ),
              Text(
                'Max Intensity: ${(predictionData['weather_summary']?['max_intensity'] ?? 0.0).toStringAsFixed(1)}mm/hr',
                style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
      ],
         );
   }

   Widget _buildMLModelInfo(Map<String, dynamic> predictionData) {
     final modelInfo = predictionData['model_info'];
     final confidence = (predictionData['confidence'] * 100).toStringAsFixed(1);
     
     return Container(
       padding: EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Colors.blue.withOpacity(0.05),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.blue.withOpacity(0.2)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Icon(Icons.psychology, color: Colors.blue, size: 20),
               SizedBox(width: 8),
               Text(
                 'ML Model Prediction',
                 style: GoogleFonts.poppins(
                   fontSize: 14,
                   fontWeight: FontWeight.w600,
                   color: Color(0xFF22223B),
                 ),
               ),
               Spacer(),
               Container(
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.green,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   '$confidence% Confidence',
                   style: GoogleFonts.poppins(
                     color: Colors.white,
                     fontSize: 10,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ),
             ],
           ),
           SizedBox(height: 12),
           Text(
             'Algorithm: ${modelInfo['algorithm']}',
             style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
           ),
           Text(
             'Training Accuracy: ${(modelInfo['accuracy_estimate'] * 100).toStringAsFixed(1)}%',
             style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
           ),
           Text(
             'Features: ${modelInfo['features_used'].length} variables analyzed',
             style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF666666)),
           ),
           SizedBox(height: 8),
           Text(
             'Prevents overfitting through ensemble voting and calibration',
             style: GoogleFonts.poppins(
               fontSize: 11,
               color: Color(0xFF999999),
               fontStyle: FontStyle.italic,
             ),
           ),
         ],
       ),
     );
   }
 }
 
 // Extension to convert hex color strings to Color objects
 extension ColorExtension on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
