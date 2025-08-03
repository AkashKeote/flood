import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/weather_service.dart';
import 'services/user_service.dart';

class FloodPredictionPage extends StatefulWidget {
  const FloodPredictionPage({super.key});

  @override
  State<FloodPredictionPage> createState() => _FloodPredictionPageState();
}

class _FloodPredictionPageState extends State<FloodPredictionPage> {
  Map<String, dynamic>? _predictionData;
  bool _isLoading = false;
  String _selectedCity = '';
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  void _loadCities() {
    _availableCities = WeatherService.getMumbaiCities();
    _selectedCity = UserService.getSelectedCity().isNotEmpty 
        ? UserService.getSelectedCity() 
        : 'Andheri';
  }

  Future<void> _getAIPrediction() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prediction = await WeatherService.getAIPrediction(_selectedCity);
      setState(() {
        _predictionData = prediction;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _predictionData = null;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prediction failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changeCity(String city) {
    setState(() {
      _selectedCity = city;
      _predictionData = null; // Clear previous prediction
    });
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return Color(0xFFF44336);
      case 'high':
        return Color(0xFFFF5722);
      case 'moderate':
        return Color(0xFFFF9800);
      case 'low':
        return Color(0xFF4CAF50);
      case 'very low':
        return Color(0xFF8BC34A);
      default:
        return Color(0xFFB5C7F7);
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return Icons.error_rounded;
      case 'high':
        return Icons.warning_rounded;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'low':
        return Icons.check_circle_rounded;
      case 'very low':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F6F2),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Flood Prediction',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Smart Analysis & Real-time Insights',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Color(0xFF22223B).withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildCitySelector(),
                  ],
                ),
              ),

              // AI Stats Cards
              if (_predictionData != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'AI Confidence',
                          '${_predictionData!['confidencePercent']}%',
                          Color(0xFFF9E79F),
                          Icons.psychology_rounded,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Risk Score',
                          '${_predictionData!['riskScore']}/100',
                          _getRiskColor(_predictionData!['riskLevel']),
                          _getRiskIcon(_predictionData!['riskLevel']),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Rainfall',
                          '${_predictionData!['weatherData']['totalRainfall'].toStringAsFixed(1)}mm',
                          Color(0xFFD6EAF8),
                          Icons.water_drop_rounded,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Humidity',
                          '${_predictionData!['weatherData']['humidity'].toStringAsFixed(0)}%',
                          Color(0xFFE8F4FD),
                          Icons.opacity_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Risk Factors
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Risk Factors',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22223B),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _predictionData!['factors'].map<Widget>((factor) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFFB5C7F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          factor,
                          style: TextStyle(
                            color: Color(0xFF22223B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                SizedBox(height: 24),

                // AI Insights
                if (_predictionData!['insights'].isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'AI Insights',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: _predictionData!['insights'].map<Widget>((insight) {
                        return Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                color: Color(0xFFB5C7F7),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  insight,
                                  style: TextStyle(
                                    color: Color(0xFF22223B),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 24),
                ],

                // Weather Data
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Weather Analysis',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22223B),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildWeatherRow('Temperature', '${_predictionData!['weatherData']['temperature'].toStringAsFixed(1)}°C', Icons.thermostat_rounded),
                        SizedBox(height: 12),
                        _buildWeatherRow('Pressure', '${_predictionData!['weatherData']['pressure'].toStringAsFixed(0)} hPa', Icons.speed_rounded),
                        SizedBox(height: 12),
                        _buildWeatherRow('Wind Speed', '${_predictionData!['weatherData']['windSpeed'].toStringAsFixed(1)} m/s', Icons.air_rounded),
                        SizedBox(height: 12),
                        _buildWeatherRow('Visibility', '${(_predictionData!['weatherData']['visibility'] / 1000).toStringAsFixed(1)} km', Icons.visibility_rounded),
                        SizedBox(height: 12),
                        _buildWeatherRow('Rainy Hours', '${_predictionData!['weatherData']['rainyHours']} hours', Icons.schedule_rounded),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),
              ],

              // Prediction Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _getAIPrediction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFB5C7F7),
                      foregroundColor: Color(0xFF22223B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF22223B),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.psychology_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Get AI Prediction',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Color(0xFFB5C7F7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          icon: Icon(Icons.arrow_drop_down, color: Color(0xFF22223B)),
          style: TextStyle(
            color: Color(0xFF22223B),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _changeCity(newValue);
            }
          },
          items: _availableCities.map<DropdownMenuItem<String>>((String city) {
            return DropdownMenuItem<String>(value: city, child: Text(city));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFF22223B), size: 24),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF22223B),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF22223B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFFB5C7F7), size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Color(0xFF22223B).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Color(0xFF22223B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
