import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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
            child: Text(
              'Hello, Akash!\nStay safe this monsoon.',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
          ),
          // Quick Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _PastelStatCard(
                  title: 'Current Risk',
                  value: 'Moderate',
                  color: Color(0xFFF9E79F),
                  icon: Icons.warning_amber_rounded,
                ),
                SizedBox(width: 16),
                _PastelStatCard(
                  title: 'Water Level',
                  value: '2.3m',
                  color: Color(0xFFD6EAF8),
                  icon: Icons.water_drop_rounded,
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
                //_PastelChip(label: 'Drainage', color: Color(0xFFD6EAF8)),
                _PastelChip(label: 'River', color: Color(0xFFF9E79F)),
                _PastelChip(label: 'Alert', color: Color(0xFFB5C7F7)),
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
                    'Area: Andheri, Mumbai',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Risk: Moderate',
                    style: TextStyle(color: Color(0xFFB5C7F7)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Water Level: 2.3m',
                    style: TextStyle(color: Color(0xFF22223B)),
                  ),
                  SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 0.7,
                    backgroundColor: Color(0xFFF7F6F2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFB5C7F7),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _PastelActionCard(
                    icon: Icons.report,
                    label: 'Report Flood',
                    color: Color(0xFFF9E79F),
                    onTap: () {},
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _PastelActionCard(
                    icon: Icons.phone_in_talk_rounded,
                    label: 'Call Emergency',
                    color: Color(0xFFD6EAF8),
                    onTap: () {},
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _PastelActionCard(
                    icon: Icons.map_rounded,
                    label: 'View Map',
                    color: Color(0xFFB5C7F7),
                    onTap: () {},
                  ),
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
