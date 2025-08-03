import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/weather_service.dart';
import 'services/user_service.dart';
import 'services/twitter_service.dart';

class FloodPredictionPage extends StatefulWidget {
  const FloodPredictionPage({super.key});

  @override
  State<FloodPredictionPage> createState() => _FloodPredictionPageState();
}

class _FloodPredictionPageState extends State<FloodPredictionPage> {
  Map<String, dynamic>? _predictionData;
  bool _isLoading = false;
  bool _isSharing = false;
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

  Future<void> _shareOnTwitter() async {
    if (_predictionData == null) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final result = await TwitterService.shareAIPrediction(
        cityName: _selectedCity,
        riskLevel: _predictionData!['riskLevel'],
        aiConfidence: _predictionData!['aiConfidence'] ?? 85,
        grokAnalysis: _predictionData!['grokAnalysis'] ?? {},
        geminiAnalysis: _predictionData!['geminiAnalysis'] ?? {},
      );

      setState(() {
        _isSharing = false;
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message']}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Tweet',
              onPressed: () {
                // Open tweet URL
                // You can add URL launcher here
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSharing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareFloodAlert() async {
    if (_predictionData == null) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final result = await TwitterService.shareFloodAlert(
        cityName: _selectedCity,
        riskLevel: _predictionData!['riskLevel'],
        riskScore: _predictionData!['riskScore'].toString(),
        weatherData: _predictionData!['weatherData'],
        insights: _predictionData!['factors'] ?? [],
      );

      setState(() {
        _isSharing = false;
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Flood alert shared on Twitter!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to share flood alert'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSharing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing alert: $e'),
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
                      'Advanced AI Flood Prediction',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Powered by Grok-4 & Gemini AI',
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

              // AI Models Info
              if (_predictionData != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        Text(
                          'AI Models Used',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: Color(0xFFB5C7F7),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Grok-4 (OpenRouter)',
                              style: TextStyle(
                                color: Color(0xFF22223B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFF9E79F),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Gemini Pro (Google)',
                              style: TextStyle(
                                color: Color(0xFF22223B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Enhanced AI Stats Cards
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'AI Confidence',
                          '${_predictionData!['aiConfidence'] ?? 85}%',
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

                // Twitter Share Buttons
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildShareButton(
                          'Share AI Prediction',
                          Icons.psychology_rounded,
                          Color(0xFF1DA1F2),
                          _shareOnTwitter,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildShareButton(
                          'Share Flood Alert',
                          Icons.warning_rounded,
                          Color(0xFFFF5722),
                          _shareFloodAlert,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Grok AI Analysis
                if (_predictionData!['grokAnalysis'] != null) ...[
                  _buildAIAnalysisSection(
                    'Grok-4 AI Analysis',
                    _predictionData!['grokAnalysis'],
                    Color(0xFFB5C7F7),
                    Icons.psychology_rounded,
                  ),

                  SizedBox(height: 16),
                ],

                // Gemini AI Analysis
                if (_predictionData!['geminiAnalysis'] != null) ...[
                  _buildAIAnalysisSection(
                    'Gemini AI Analysis',
                    _predictionData!['geminiAnalysis'],
                    Color(0xFFF9E79F),
                    Icons.auto_awesome_rounded,
                  ),

                  SizedBox(height: 16),
                ],

                // Combined AI Insights
                if (_predictionData!['combinedInsights'] != null) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Combined AI Insights',
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                color: Color(0xFFB5C7F7),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'AI Recommendations',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (_predictionData!['combinedInsights']['insights'] !=
                              null)
                            ...(_predictionData!['combinedInsights']['insights']
                                    as List)
                                .map<Widget>((insight) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF4CAF50),
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            insight.toString(),
                                            style: TextStyle(
                                              color: Color(0xFF22223B),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          SizedBox(height: 16),
                          if (_predictionData!['combinedInsights']['emergencyAdvice'] !=
                              null)
                            _buildInsightItem(
                              'Emergency Advice',
                              _predictionData!['combinedInsights']['emergencyAdvice'],
                              Icons.emergency_rounded,
                              Color(0xFFFF5722),
                            ),
                          SizedBox(height: 12),
                          if (_predictionData!['combinedInsights']['safetyMeasures'] !=
                              null)
                            _buildInsightItem(
                              'Safety Measures',
                              _predictionData!['combinedInsights']['safetyMeasures'],
                              Icons.security_rounded,
                              Color(0xFF4CAF50),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),
                ],

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
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                        _buildWeatherRow(
                          'Temperature',
                          '${_predictionData!['weatherData']['temperature'].toStringAsFixed(1)}°C',
                          Icons.thermostat_rounded,
                        ),
                        SizedBox(height: 12),
                        _buildWeatherRow(
                          'Pressure',
                          '${_predictionData!['weatherData']['pressure'].toStringAsFixed(0)} hPa',
                          Icons.speed_rounded,
                        ),
                        SizedBox(height: 12),
                        _buildWeatherRow(
                          'Wind Speed',
                          '${_predictionData!['weatherData']['windSpeed'].toStringAsFixed(1)} m/s',
                          Icons.air_rounded,
                        ),
                        SizedBox(height: 12),
                        _buildWeatherRow(
                          'Visibility',
                          '${(_predictionData!['weatherData']['visibility'] / 1000).toStringAsFixed(1)} km',
                          Icons.visibility_rounded,
                        ),
                        SizedBox(height: 12),
                        _buildWeatherRow(
                          'Rainy Hours',
                          '${_predictionData!['weatherData']['rainyHours']} hours',
                          Icons.schedule_rounded,
                        ),
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
                                'Get Advanced AI Prediction',
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

  Widget _buildShareButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 45,
      child: ElevatedButton(
        onPressed: _isSharing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSharing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
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

  Widget _buildAIAnalysisSection(
    String title,
    Map<String, dynamic> analysis,
    Color color,
    IconData icon,
  ) {
    return Padding(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22223B),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (analysis['analysis'] != null)
              _buildAnalysisItem('Analysis', analysis['analysis']),
            if (analysis['recommendations'] != null)
              _buildAnalysisItem(
                'Recommendations',
                analysis['recommendations'],
              ),
            if (analysis['weatherAnalysis'] != null)
              _buildAnalysisItem(
                'Weather Analysis',
                analysis['weatherAnalysis'],
              ),
            if (analysis['floodRisk'] != null)
              _buildAnalysisItem('Flood Risk', analysis['floodRisk']),
            if (analysis['safetyTips'] != null)
              _buildAnalysisItem('Safety Tips', analysis['safetyTips']),
            if (analysis['emergencyAdvice'] != null)
              _buildAnalysisItem(
                'Emergency Advice',
                analysis['emergencyAdvice'],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(String label, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF22223B),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              color: Color(0xFF22223B).withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    String label,
    String content,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF22223B),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  color: Color(0xFF22223B).withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
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
