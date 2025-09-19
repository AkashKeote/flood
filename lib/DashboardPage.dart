import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_service.dart';
import 'UserSetupPage.dart';
import 'fastapi_flood_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userName = 'User';
  String userWard = 'Ward';
  String currentRisk = 'Loading...';
  String waterLevel = 'Loading...';
  bool isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRealTimeData();
  }

  Future<void> _loadUserData() async {
    final name = await UserService.getUserName();
    final ward = await UserService.getUserWard();

    setState(() {
      userName = name ?? 'User';
      userWard = ward ?? 'Ward';
    });
  }

  Future<void> _loadRealTimeData() async {
    try {
      // Get real flood risk for user's area
      final userData = await UserService.getUserData();
      String userArea = userData?['area']?.toString() ?? userWard;

      if (userArea != 'Ward') {
        final prediction = await FastApiFloodService.predict(userArea);
        setState(() {
          currentRisk = prediction['flood_risk'] ?? 'Unknown';
          // Use real water level from API instead of hardcoded calculation
          waterLevel = '${prediction['water_level'] ?? 2.0}m';
          isLoadingData = false;
        });
      } else {
        setState(() {
          currentRisk = 'Moderate';
          waterLevel = '2.0m';
          isLoadingData = false;
        });
      }
    } catch (e) {
      print('Error loading real-time data: $e');
      setState(() {
        currentRisk = 'Moderate';
        waterLevel = '2.3m';
        isLoadingData = false;
      });
    }
  }

  double _getWaterLevelProgress() {
    // Calculate progress bar width based on actual water level
    if (isLoadingData) return 0.0;

    // Extract numeric value from water level string (e.g., "1.8m" -> 1.8)
    String levelStr = waterLevel
        .replaceAll('m', '')
        .replaceAll('Loading...', '2.0');
    double level = double.tryParse(levelStr) ?? 2.0;

    // Scale to progress (0.0 to 1.0) based on realistic range (1.0m to 4.0m)
    double progress = (level - 1.0) / 3.0; // 1.0m = 0%, 4.0m = 100%
    return progress.clamp(0.0, 1.0);
  }

  Color _getWaterLevelColor() {
    // Get color based on risk level
    if (isLoadingData) return Color(0xFFE0E0E0);

    switch (currentRisk.toLowerCase()) {
      case 'high':
        return Color(0xFFE74C3C); // Red for high risk
      case 'moderate':
        return Color(0xFFF39C12); // Orange for moderate risk
      case 'low':
        return Color(0xFF27AE60); // Green for low risk
      default:
        return Color(0xFFB5C7F7); // Default blue
    }
  }

  Future<void> _logout() async {
    await UserService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const UserSetupPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $userName!',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22223B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Color(0xFF666666),
                          ),
                          SizedBox(width: 4),
                          Text(
                            userWard,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Stay safe this monsoon.',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF22223B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFB5C7F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _logout,
                    icon: Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF22223B),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Color(0xFFF9E79F),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFF22223B),
                          size: 32,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Current Risk',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          isLoadingData ? 'Loading...' : currentRisk,
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF22223B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Color(0xFFD6EAF8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          color: Color(0xFF22223B),
                          size: 32,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Water Level',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          isLoadingData ? 'Loading...' : waterLevel,
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF22223B),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                Chip(label: Text('River'), backgroundColor: Color(0xFFF9E79F)),
                Chip(label: Text('Alert'), backgroundColor: Color(0xFFB5C7F7)),
              ],
            ),
          ),

          SizedBox(height: 28),

          // Flood Status Section
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
          SizedBox(height: 16),

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
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Area: $userWard, Mumbai',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22223B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Risk: ${isLoadingData ? 'Loading...' : currentRisk}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Water Level: ${isLoadingData ? 'Loading...' : waterLevel}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22223B),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Progress bar for water level
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _getWaterLevelProgress(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getWaterLevelColor(),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 28),

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

          // 2x2 Grid Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Color(0xFFF9E79F),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.report,
                              color: Color(0xFF22223B),
                              size: 28,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Report Flood',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22223B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Color(0xFFD6EAF8),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_in_talk_rounded,
                              color: Color(0xFF22223B),
                              size: 28,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Call Emergency',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22223B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Color(0xFFB5C7F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.map_rounded,
                              color: Color(0xFF22223B),
                              size: 28,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'View Map',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22223B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8D5C4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_rounded,
                              color: Color(0xFF22223B),
                              size: 28,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Safe Routes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22223B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }
}
