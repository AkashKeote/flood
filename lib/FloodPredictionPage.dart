import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FloodPredictionPage extends StatefulWidget {
  const FloodPredictionPage({super.key});

  @override
  State<FloodPredictionPage> createState() => _FloodPredictionPageState();
}

class _FloodPredictionPageState extends State<FloodPredictionPage> {
  String _predictionResult = 'No prediction yet.';

  void _getPrediction() {
    setState(() {
      _predictionResult = 'Flood risk: LOW\n(Example prediction)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
            child: Text(
              'AI Flood Prediction\nSmart Analysis',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
          ),

          // Prediction Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
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

          SizedBox(height: 24),

          // Status Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Wrap(
              spacing: 10,
              children: [
                _ComicChip(label: 'Weather', color: Color(0xFFD6EAF8)),
                _ComicChip(label: 'Rainfall', color: Color(0xFFF9E79F)),
                _ComicChip(label: 'Drainage', color: Color(0xFFB5C7F7)),
                _ComicChip(label: 'History', color: Color(0xFFE8D5C4)),
              ],
            ),
          ),

          SizedBox(height: 28),

          // Prediction Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: Color(0xFFB5C7F7), size: 28),
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
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF7F6F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _predictionResult,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF22223B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ComicButton(
                    onPressed: _getPrediction,
                    label: 'Get AI Prediction',
                    color: Color(0xFFB5C7F7),
                    icon: Icons.psychology_rounded,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 28),

          // Features Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text(
              'Prediction Features',
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
            child: Column(
              children: [
                _ComicFeatureCard(
                  icon: Icons.water_drop_rounded,
                  title: 'Water Level Analysis',
                  subtitle: 'Real-time monitoring',
                  color: Color(0xFFD6EAF8),
                ),
                SizedBox(height: 12),
                _ComicFeatureCard(
                  icon: Icons.cloud_rounded,
                  title: 'Weather Integration',
                  subtitle: 'Rainfall prediction',
                  color: Color(0xFFF9E79F),
                ),
                SizedBox(height: 12),
                _ComicFeatureCard(
                  icon: Icons.history_rounded,
                  title: 'Historical Data',
                  subtitle: 'Pattern recognition',
                  color: Color(0xFFE8D5C4),
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

class _ComicChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ComicChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(color: Color(0xFF22223B))),
      backgroundColor: color,
      shape: StadiumBorder(),
    );
  }
}

class _ComicButton extends StatelessWidget {
  final VoidCallback onPressed;
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color(0xFF22223B), size: 24),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
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

class _ComicFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ComicFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF22223B), size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22223B),
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Color(0xFF22223B).withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
