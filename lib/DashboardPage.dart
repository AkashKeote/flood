import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/flood_data.dart';
import 'services/weather_service.dart';
import 'services/user_service.dart';
import 'services/firebase_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late FloodData _currentData;
  bool _isLoading = true;
  String _selectedCity = 'Andheri';
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _availableCities = WeatherService.getMumbaiCities();
    _selectedCity = UserService.getSelectedCity().isNotEmpty
        ? UserService.getSelectedCity()
        : 'Andheri';
    _loadData();
  }

  void _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cityData = await WeatherService.getRealTimeData(_selectedCity);
      setState(() {
        _currentData = cityData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentData = FloodDataService.getMockData();
        _isLoading = false;
      });
    }
  }

  void _changeCity(String city) async {
    setState(() {
      _selectedCity = city;
    });
    await UserService.updateSelectedCity(city);
    
    // Try to log analytics event (but don't fail if it doesn't work)
    try {
      if (FirebaseService.isInitialized) {
        await FirebaseService.logEvent('city_changed', {
          'previous_city': _selectedCity,
          'new_city': city,
          'user_name': UserService.getUserName(),
        });
      }
    } catch (firebaseError) {
      print('Firebase error (non-critical): $firebaseError');
    }
    
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return Scaffold(
      backgroundColor: Color(0xFFF7F6F2),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${UserService.getUserName().isNotEmpty ? UserService.getUserName() : 'User'}!',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Stay safe this monsoon',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Color(0xFF22223B).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _loadData,
                          icon: Icon(Icons.refresh_rounded),
                          color: Color(0xFF22223B),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildCitySelector(),
                  ],
                ),
              ),

              // Stats Cards
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Risk Level',
                        _currentData.riskLevel,
                        _getRiskColor(_currentData.riskLevel),
                        _getRiskIcon(_currentData.riskLevel),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Water Level',
                        '${_currentData.waterLevel.toStringAsFixed(1)}m',
                        Color(0xFFD6EAF8),
                        Icons.water_drop_rounded,
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
                        'Temperature',
                        '${_currentData.temperature.toStringAsFixed(1)}°C',
                        Color(0xFFFFE5B4),
                        Icons.thermostat_rounded,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Humidity',
                        '${_currentData.humidity.toStringAsFixed(1)}%',
                        Color(0xFFE8F4FD),
                        Icons.opacity_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Flood Status Card
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      Text(
                        'Flood Status',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22223B),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            _getRiskIcon(_currentData.riskLevel),
                            color: _getRiskColor(_currentData.riskLevel),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentData.area,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Risk: ${_currentData.riskLevel}',
                                  style: TextStyle(
                                    color: _getRiskColor(
                                      _currentData.riskLevel,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _getRiskProgress(_currentData.riskLevel),
                        backgroundColor: Color(0xFFF7F6F2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getRiskColor(_currentData.riskLevel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Alerts Section
              if (_currentData.alerts.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Recent Alerts',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22223B),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                ..._currentData.alerts
                    .map((alert) => _buildAlertCard(alert))
                    .toList(),
                SizedBox(height: 24),
              ],

              // Quick Actions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Quick Actions',
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
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        Icons.report_rounded,
                        'Report',
                        Color(0xFFF9E79F),
                        () => _showReportDialog(),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        Icons.phone_rounded,
                        'Emergency',
                        Color(0xFFD6EAF8),
                        () => _callEmergency(),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        Icons.map_rounded,
                        'Map',
                        Color(0xFFB5C7F7),
                        () => _navigateToMap(),
                      ),
                    ),
                  ],
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

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
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
          Icon(icon, color: Color(0xFF22223B), size: 28),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF22223B),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
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
    );
  }

  Widget _buildAlertCard(FloodAlert alert) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getAlertColor(alert.severity),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(_getAlertIcon(alert.severity), color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.message,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${alert.location} • ${_formatTime(alert.timestamp)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color(0xFF22223B), size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF22223B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Color(0xFFF7F6F2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5C7F7)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading flood data...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Color(0xFF22223B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Color(0xFF4CAF50);
      case 'moderate':
        return Color(0xFFFF9800);
      case 'high':
        return Color(0xFFFF5722);
      case 'critical':
        return Color(0xFFF44336);
      default:
        return Color(0xFFB5C7F7);
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Icons.check_circle_rounded;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.warning_rounded;
      case 'critical':
        return Icons.error_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  double _getRiskProgress(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return 0.25;
      case 'moderate':
        return 0.5;
      case 'high':
        return 0.75;
      case 'critical':
        return 1.0;
      default:
        return 0.25;
    }
  }

  Color _getAlertColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'warning':
        return Color(0xFFFF9800);
      case 'error':
        return Color(0xFFF44336);
      case 'info':
        return Color(0xFF2196F3);
      default:
        return Color(0xFF4CAF50);
    }
  }

  IconData _getAlertIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'warning':
        return Icons.warning_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'info':
        return Icons.info_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Flood'),
        content: Text(
          'This feature will allow users to report flood incidents in their area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _callEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emergency Contact'),
        content: Text(
          'Calling emergency services...\n\nEmergency: 100\nFlood Control: 022-24937746',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToMap() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Navigating to Map...')));
  }
}
