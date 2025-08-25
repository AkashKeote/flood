import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flood_prediction_service.dart';
import 'mumbai_wards_data.dart';

class FloodPredictionPage extends StatefulWidget {
  const FloodPredictionPage({super.key});

  @override
  State<FloodPredictionPage> createState() => _FloodPredictionPageState();
}

class _FloodPredictionPageState extends State<FloodPredictionPage> {
  String _selectedWard = 'Andheri East';
  bool _isLoading = false;
  Map<String, dynamic>? _predictionData;
  String _errorMessage = '';
  bool _serverHealthy = false;
  String _searchQuery = '';
  
  // Using local data instead of API for wards
  List<Map<String, dynamic>> _mumbaiWards = MumbaiWardsData.allWards;

  @override
  void initState() {
    super.initState();
    _updateFilteredWards();
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    final healthy = await FloodPredictionService.checkServerHealth();
    setState(() {
      _serverHealthy = healthy;
    });
  }

  Future<void> _predictFlood() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _predictionData = null;
    });

    try {
      final result = await FloodPredictionService.predictFlood(_selectedWard);
      
      setState(() {
        _isLoading = false;
        _predictionData = result;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return Icons.check_circle;
      case 'moderate':
        return Icons.warning;
      case 'high':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  // Filter wards based on search query
  List<Map<String, dynamic>> _getFilteredWards() {
    if (_searchQuery.isEmpty) {
      return _mumbaiWards;
    }
    return _mumbaiWards.where((ward) => 
      ward['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
      ward['code'].toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // Cache filtered wards to prevent rebuilds
  List<Map<String, dynamic>> _filteredWards = [];

  void _updateFilteredWards() {
    _filteredWards = _getFilteredWards();
    // If current selected ward is not in filtered list, reset to first item
    if (_filteredWards.isNotEmpty && !_filteredWards.any((ward) => ward['name'] == _selectedWard)) {
      _selectedWard = _filteredWards.first['name'];
    }
  }

  // Get selected ward risk level
  String _getSelectedWardRisk() {
    final ward = _mumbaiWards.firstWhere(
      (ward) => ward['name'] == _selectedWard,
      orElse: () => {'risk': 'Unknown'},
    );
    return ward['risk'] ?? 'Unknown';
  }

  // Get selected ward risk color
  Color _getSelectedWardRiskColor() {
    return _getRiskColor(_getSelectedWardRisk());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 150), // Increased bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Flood Prediction',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22223B),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Smart Analysis using Machine Learning & Weather Data',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),

          // Model Info Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _InfoCard(
                  title: 'Model Accuracy',
                  value: '82.1%',
                  icon: Icons.psychology,
                  color: Color(0xFFF9E79F),
                ),
                SizedBox(width: 16),
                _InfoCard(
                  title: 'Data Sources',
                  value: '19 Features',
                  icon: Icons.analytics,
                  color: Color(0xFFD6EAF8),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Feature Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Wrap(
              spacing: 10,
              children: [
                _FeatureChip(label: 'Weather API', color: Color(0xFFD6EAF8)),
                _FeatureChip(label: 'Rainfall Data', color: Color(0xFFF9E79F)),
                _FeatureChip(label: 'Urban Analysis', color: Color(0xFFB5C7F7)),
                _FeatureChip(label: 'ML Ensemble', color: Color(0xFFE8D5C4)),
              ],
            ),
          ),

          SizedBox(height: 28),

          // City Selection Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: 380, // Increased to handle two-line dropdown items
              ),
              padding: EdgeInsets.all(20), // Increased padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Color(0xFFB5C7F7), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select Mumbai Ward for Analysis (${_mumbaiWards.length} wards)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                      ),
                      if (!_serverHealthy)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'OFFLINE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 18), // Reduced spacing
                  
                  // Search Bar
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _updateFilteredWards();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search ward name (e.g., Andheri, Bandra)...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFFB5C7F7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Color(0xFFB5C7F7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Color(0xFFB5C7F7), width: 2),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12), // Reduced spacing
                  
                  // Selected Ward Display
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFB5C7F7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Color(0xFFB5C7F7).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_city, color: Color(0xFFB5C7F7), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Ward:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              Text(
                                _selectedWard,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getSelectedWardRiskColor(),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _getSelectedWardRisk(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 10), // Reduced spacing
                  
                  // Dropdown for Ward Selection
                  DropdownButtonFormField<String>(
                    value: _filteredWards.any((ward) => ward['name'] == _selectedWard) ? _selectedWard : null,
                    decoration: InputDecoration(
                      labelText: 'Choose Ward',
                      prefixIcon: Icon(Icons.apartment, color: Color(0xFFB5C7F7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Color(0xFFB5C7F7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Color(0xFFB5C7F7), width: 2),
                      ),
                    ),
                    items: _filteredWards.map((ward) {
                      return DropdownMenuItem<String>(
                        value: ward['name'],
                        child: Container(
                          height: 48, // Fixed height to prevent overflow
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: _getRiskColor(ward['risk']),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: ward['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF22223B),
                                        ),
                                      ),
                                      TextSpan(
                                        text: '\nWard ${ward['code']} • ${ward['risk']} Risk',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null && _filteredWards.any((ward) => ward['name'] == value)) {
                        setState(() {
                          _selectedWard = value;
                        });
                      }
                    },
                    isExpanded: true,
                    menuMaxHeight: 180, // Fixed height to prevent overflow
                  ),
                  
                  SizedBox(height: 15), // Reduced spacing
                  
                  // Predict Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _predictFlood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFB5C7F7),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
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
                                  'Analyzing Weather & Terrain...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.psychology, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Predict Flood Risk',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 28),

          // Results Section
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_predictionData != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Main Prediction Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Risk Level
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getRiskIcon(_predictionData!['prediction'] ?? 'Unknown'),
                              color: _getRiskColor(_predictionData!['prediction'] ?? 'Unknown'),
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Flood Risk: ${(_predictionData!['prediction'] ?? 'Unknown').toUpperCase()}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _getRiskColor(_predictionData!['prediction'] ?? 'Unknown'),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Confidence
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Color(0xFFF7F6F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Confidence: ${(_predictionData!['confidence'] ?? 0.0).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22223B),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // Weather Info
                        if (_predictionData!['weather_data'] != null) ...[
                          Divider(color: Colors.grey.shade200),
                          SizedBox(height: 16),
                          Text(
                            'Current Weather in $_selectedWard',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF22223B),
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _WeatherInfo(
                                icon: Icons.thermostat,
                                label: 'Temperature',
                                value: '${_predictionData!['weather_data']['temperature']}°C',
                              ),
                              _WeatherInfo(
                                icon: Icons.water_drop,
                                label: 'Humidity',
                                value: '${_predictionData!['weather_data']['humidity']}%',
                              ),
                              _WeatherInfo(
                                icon: Icons.air,
                                label: 'Wind Speed',
                                value: '${_predictionData!['weather_data']['wind_speed']} m/s',
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Condition: ${_predictionData!['weather_data']['description']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Additional Info
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFFF7F6F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Analysis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This prediction is based on real-time weather data combined with geographic and urban characteristics specific to $_selectedWard ward in Mumbai. The model uses an ensemble of Random Forest and XGBoost algorithms trained on comprehensive flood data.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                        if (_predictionData!['rainfall_estimate'] != null) ...[
                          SizedBox(height: 12),
                          Text(
                            'Estimated Rainfall: ${_predictionData!['rainfall_estimate'].toStringAsFixed(1)} mm',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22223B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 80), // Increased spacing at bottom
        ],
        ),
      ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Color(0xFF22223B), size: 32),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final Color color;

  const _FeatureChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: Color(0xFF22223B)),
      ),
      backgroundColor: color,
      shape: StadiumBorder(),
    );
  }
}

class _WeatherInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF22223B), size: 24),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF22223B),
          ),
        ),
      ],
    );
  }
}
