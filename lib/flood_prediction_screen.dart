import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mumbai_areas.dart';
import 'user_service.dart';
import 'fastapi_flood_service.dart';

class FloodPredictionScreen extends StatefulWidget {
  const FloodPredictionScreen({super.key});

  @override
  State<FloodPredictionScreen> createState() => _FloodPredictionScreenState();
}

class _FloodPredictionScreenState extends State<FloodPredictionScreen> {
  String _predictionResult = 'No prediction yet.';
  String? _userArea;
  bool _predicting = false;
  List<String> _availableAreas = [];
  bool _loadingAreas = true;
  Map<String, dynamic>? _predictionData;

  @override
  void initState() {
    super.initState();
    _loadUserArea();
    _loadAvailableAreas();
  }

  Future<void> _loadUserArea() async {
    final data = await UserService.getUserData();
    setState(() {
      _userArea = data?['area']?.toString();
    });
  }

  Future<void> _loadAvailableAreas() async {
    // Use static Mumbai areas list to ensure consistency with UserSetupPage
    setState(() {
      _availableAreas = MumbaiAreas.list;
      _loadingAreas = false;
    });
    print('Using Mumbai areas list with ${MumbaiAreas.list.length} areas');
    print('Mulund in list: ${MumbaiAreas.list.contains('Mulund')}');
  }

  Future<void> _getPrediction() async {
    if (_userArea == null) return;
    setState(() {
      _predicting = true;
      _predictionResult = 'Predicting for ' + _userArea! + '...';
    });
    try {
      print('🔍 Predicting for selected area: $_userArea');
      final res = await FastApiFloodService.predict(_userArea!);
      final risk = (res['flood_risk'] ?? 'Unknown').toString();
      final date = (res['date'] ?? '').toString();
      final rain = (res['rainfall'] ?? 0).toString();
      final matched = (res['matched_area'] ?? _userArea).toString();
      final score = (res['match_score'] ?? 0).toString();

      print('📊 Backend returned matched_area: $matched');
      print('🎯 Will show selected area: $_userArea');

      setState(() {
        _predictionData = res;
        _predictionResult =
            'City: ' +
            _userArea! + // Show selected area instead of matched area
            '\nDate: ' +
            date +
            '\nFlood risk: ' +
            risk +
            '\nRainfall: ' +
            rain +
            ' mm\nMatch score: ' +
            score +
            '%';
      });
    } catch (e) {
      setState(() {
        _predictionResult = 'Error: ' + e.toString();
        _predictionData = null;
      });
    } finally {
      setState(() {
        _predicting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 24.0,
              ),
              child: Text(
                'AI Flood Prediction\nSmart Analysis',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF22223B),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: const [
                  _ComicStatCard(
                    title: 'AI Confidence',
                    value: '85%',
                    color: Color(0xFFF9E79F),
                    icon: Icons.psychology_rounded,
                  ),
                  SizedBox(width: 16),
                  _ComicStatCard(
                    title: 'Data Points',
                    value: '1,247',
                    color: Color(0xFFD6EAF8),
                    icon: Icons.analytics_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Your Area + Dropdown (styled like UserSetupPage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: isDesktop ? 32 : 28,
                          height: isDesktop ? 32 : 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB5C7F7),
                            borderRadius: BorderRadius.circular(
                              isDesktop ? 10 : 8,
                            ),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: isDesktop ? 16 : 12),
                        Expanded(
                          child: Text(
                            'Select your area',
                            style: GoogleFonts.poppins(
                              fontSize: isDesktop ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF22223B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isDesktop ? 20 : 16),
                    _loadingAreas
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20 : 16,
                              vertical: isDesktop ? 20 : 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F6F2),
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 16 : 12,
                              ),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(0xFFB5C7F7),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading areas...',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 18 : 16,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _availableAreas.contains(_userArea)
                                ? _userArea
                                : null,
                            decoration: InputDecoration(
                              hintText: 'Select your area in Mumbai',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isDesktop ? 16 : 12,
                                ),
                                borderSide: const BorderSide(
                                  color: Color(0xFFB5C7F7),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isDesktop ? 16 : 12,
                                ),
                                borderSide: const BorderSide(
                                  color: Color(0xFFB5C7F7),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isDesktop ? 16 : 12,
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7F6F2),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 20 : 16,
                                vertical: isDesktop ? 20 : 16,
                              ),
                            ),
                            items: _availableAreas.map((String ward) {
                              return DropdownMenuItem<String>(
                                value: ward,
                                child: Text(
                                  ward,
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 18 : 16,
                                    color: const Color(0xFF22223B),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
                              if (newValue == null) return;
                              setState(() {
                                _userArea = newValue;
                              });
                              await _getPrediction();
                            },
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFB5C7F7),
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'AI Prediction Result',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_predictionData != null) ...[
                      _buildPredictionCard(),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F6F2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _predictionResult,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF22223B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _ComicButton(
                      onPressed: _predicting || _userArea == null
                          ? null
                          : () {
                              _getPrediction();
                            },
                      label: 'Get AI Prediction',
                      color: const Color(0xFFB5C7F7),
                      icon: Icons.psychology_rounded,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    if (_predictionData == null) return const SizedBox.shrink();

    final risk = _predictionData!['flood_risk']?.toString() ?? 'Unknown';
    final area =
        _userArea ?? 'Unknown'; // Show selected area instead of matched area
    final date = _predictionData!['date']?.toString() ?? 'Unknown';
    final rainfall = _predictionData!['rainfall']?.toString() ?? '0';
    final matchScore = _predictionData!['match_score']?.toString() ?? '0';

    Color riskColor = _getRiskColor(risk);
    IconData riskIcon = _getRiskIcon(risk);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF9E79F).withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with risk level
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9E79F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(riskIcon, color: const Color(0xFF22223B), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flood Risk Prediction',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF22223B),
                      ),
                    ),
                    Text(
                      area,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Prediction details
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Date',
                  date,
                  Icons.calendar_today,
                  const Color(0xFFD6EAF8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDetailItem(
                  'Rainfall',
                  '$rainfall mm',
                  Icons.water_drop,
                  const Color(0xFFD6EAF8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Match Score',
                  '$matchScore%',
                  Icons.analytics,
                  const Color(0xFFF9E79F),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDetailItem(
                  'Confidence',
                  _getConfidenceLevel(double.tryParse(matchScore) ?? 0),
                  Icons.psychology,
                  const Color(0xFFF9E79F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF22223B), size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF22223B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFF1744);
      case 'high':
        return const Color(0xFFFF5722);
      case 'moderate':
        return const Color(0xFFFF9800);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'high':
        return Icons.error_outline;
      case 'moderate':
        return Icons.info_outline;
      case 'low':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getConfidenceLevel(double score) {
    if (score >= 90) return 'Very High';
    if (score >= 80) return 'High';
    if (score >= 70) return 'Medium';
    if (score >= 60) return 'Low';
    return 'Very Low';
  }
}

class _ComicStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _ComicStatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF22223B), size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, color: Color(0xFF22223B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComicButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Color color;
  final IconData icon;

  const _ComicButton({
    required this.onPressed,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: disabled ? color.withOpacity(0.5) : color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF22223B), size: 24),
            const SizedBox(width: 8),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
