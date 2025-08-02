import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/flood_data.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late FloodData _currentData;
  late List<FloodData> _historicalData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call delay
    Future.delayed(Duration(milliseconds: 800), () {
      setState(() {
        _currentData = FloodDataService.getMockData();
        _historicalData = FloodDataService.getHistoricalData();
        _isLoading = false;
      });
    });
  }

  void _refreshData() {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 24.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Hello, Akash!\nStay safe this monsoon.',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshData,
                    icon: Icon(Icons.refresh_rounded),
                    color: Color(0xFF22223B),
                  ),
                ],
              ),
            ),
            // Quick Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _PastelStatCard(
                    title: 'Current Risk',
                    value: _currentData.riskLevel,
                    color: _getRiskColor(_currentData.riskLevel),
                    icon: _getRiskIcon(_currentData.riskLevel),
                  ),
                  SizedBox(width: 16),
                  _PastelStatCard(
                    title: 'Water Level',
                    value: '${_currentData.waterLevel.toStringAsFixed(1)}m',
                    color: Color(0xFFD6EAF8),
                    icon: Icons.water_drop_rounded,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Additional Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _PastelStatCard(
                    title: 'Temperature',
                    value: '${_currentData.temperature.toStringAsFixed(1)}°C',
                    color: Color(0xFFFFE5B4),
                    icon: Icons.thermostat_rounded,
                  ),
                  SizedBox(width: 16),
                  _PastelStatCard(
                    title: 'Rainfall',
                    value: '${_currentData.rainfall.toStringAsFixed(1)}mm',
                    color: Color(0xFFE8F4FD),
                    icon: Icons.cloud_rounded,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Wrap(
                spacing: 10,
                children: [
                  _PastelChip(label: _currentData.area.split(',')[0], color: Color(0xFFF9E79F)),
                  _PastelChip(label: _currentData.alerts.isNotEmpty ? 'Alert' : 'Safe', 
                    color: _currentData.alerts.isNotEmpty ? Color(0xFFFF6B6B) : Color(0xFFB5C7F7)),
                ],
              ),
            ),
            SizedBox(height: 28),
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Text(
                'Flood Status',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22223B),
                ),
              ),
            ),
            SizedBox(height: 14),
            // Flood Status Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
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
                    Text(
                      'Area: ${_currentData.area}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Risk: ${_currentData.riskLevel}',
                      style: TextStyle(color: _getRiskColor(_currentData.riskLevel)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Water Level: ${_currentData.waterLevel.toStringAsFixed(1)}m',
                      style: TextStyle(color: Color(0xFF22223B)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Humidity: ${_currentData.humidity.toStringAsFixed(1)}%',
                      style: TextStyle(color: Color(0xFF22223B)),
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
            SizedBox(height: 28),
            // Alerts Section
            if (_currentData.alerts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Text(
                  'Recent Alerts',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22223B),
                  ),
                ),
              ),
              SizedBox(height: 14),
              ..._currentData.alerts.map((alert) => _buildAlertCard(alert)).toList(),
              SizedBox(height: 28),
            ],
            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22223B),
                ),
              ),
            ),
            SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _PastelActionCard(
                      icon: Icons.report,
                      label: 'Report Flood',
                      color: Color(0xFFF9E79F),
                      onTap: () => _showReportDialog(),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _PastelActionCard(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Call Emergency',
                      color: Color(0xFFD6EAF8),
                      onTap: () => _callEmergency(),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _PastelActionCard(
                      icon: Icons.map_rounded,
                      label: 'View Map',
                      color: Color(0xFFB5C7F7),
                      onTap: () => _navigateToMap(),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
    );
  }

  Widget _buildAlertCard(FloodAlert alert) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getAlertColor(alert.severity),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _getAlertIcon(alert.severity),
              color: Colors.white,
              size: 24,
            ),
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
        content: Text('This feature will allow users to report flood incidents in their area.'),
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
        content: Text('Calling emergency services...\n\nEmergency: 100\nFlood Control: 022-24937746'),
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
    // This will be handled by the main navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigating to Map...')),
    );
  }
}

class _PastelStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const _PastelStatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
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
              style: TextStyle(fontSize: 18, color: Color(0xFF22223B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastelChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PastelChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(color: Color(0xFF22223B))),
      backgroundColor: color,
      shape: StadiumBorder(),
    );
  }
}

class _PastelActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PastelActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color(0xFF22223B), size: 28),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
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
