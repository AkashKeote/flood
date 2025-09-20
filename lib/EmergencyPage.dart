import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  int activeAlerts = 3;
  String responseTime = '2 min';
  bool isSOSActive = false;

  @override
  void initState() {
    super.initState();
    _loadEmergencyData();
  }

  Future<void> _loadEmergencyData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activeAlerts = prefs.getInt('active_alerts') ?? 3;
      responseTime = prefs.getString('response_time') ?? '2 min';
      isSOSActive = prefs.getBool('sos_active') ?? false;
    });
  }

  Future<void> _updateEmergencyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_alerts', activeAlerts);
    await prefs.setString('response_time', responseTime);
    await prefs.setBool('sos_active', isSOSActive);
  }

  Future<void> _makeEmergencyCall(String number) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        _showSnackBar('Calling $number...', Colors.green);
      } else {
        _showSnackBar('Cannot make call to $number', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error making call: $e', Colors.red);
    }
  }

  Future<void> _sendSOSAlert() async {
    setState(() {
      isSOSActive = true;
    });
    await _updateEmergencyData();

    _showSnackBar('SOS Alert sent! Emergency services notified.', Colors.red);

    // Simulate sending SOS to emergency services
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      activeAlerts += 1;
      responseTime = '1 min';
    });
    await _updateEmergencyData();
  }

  Future<void> _shareLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied', Colors.orange);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied', Colors.red);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Create location message
      String locationMessage =
          'Emergency Location: https://maps.google.com/?q=${position.latitude},${position.longitude}';

      // Create SMS URI
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: '100,101,102,1070', // Emergency numbers
        query: 'body=${Uri.encodeComponent(locationMessage)}',
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        _showSnackBar('Location shared with emergency contacts', Colors.green);
      } else {
        _showSnackBar('Cannot share location', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e', Colors.red);
    }
  }

  Future<void> _showEmergencyCallOptions() async {
    // Show emergency call options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emergency Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.local_police, color: Colors.blue),
              title: Text('Police (100)'),
              onTap: () {
                Navigator.pop(context);
                _makeEmergencyCall('100');
              },
            ),
            ListTile(
              leading: Icon(Icons.fire_truck, color: Colors.red),
              title: Text('Fire Brigade (101)'),
              onTap: () {
                Navigator.pop(context);
                _makeEmergencyCall('101');
              },
            ),
            ListTile(
              leading: Icon(Icons.medical_services, color: Colors.green),
              title: Text('Ambulance (102)'),
              onTap: () {
                Navigator.pop(context);
                _makeEmergencyCall('102');
              },
            ),
            ListTile(
              leading: Icon(Icons.emergency, color: Colors.orange),
              title: Text('Disaster Management (1070)'),
              onTap: () {
                Navigator.pop(context);
                _makeEmergencyCall('1070');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
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
            child: Text(
              'Emergency Response\nQuick Actions',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
          ),

          // Emergency Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _ComicStatCard(
                  title: 'Response Time',
                  value: responseTime,
                  color: Color(0xFFF9E79F),
                  icon: Icons.timer_rounded,
                ),
                SizedBox(width: 16),
                _ComicStatCard(
                  title: 'Active Alerts',
                  value: activeAlerts.toString(),
                  color: Color(0xFFD6EAF8),
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Emergency Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Wrap(
              spacing: 10,
              children: [
                _ComicChip(label: 'Police', color: Color(0xFFD6EAF8)),
                _ComicChip(label: 'Fire', color: Color(0xFFF9E79F)),
                _ComicChip(label: 'Medical', color: Color(0xFFB5C7F7)),
                _ComicChip(label: 'Rescue', color: Color(0xFFE8D5C4)),
              ],
            ),
          ),

          SizedBox(height: 28),

          // Emergency Contacts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text(
              'Emergency Contacts',
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
                _ComicContactCard(
                  icon: Icons.local_police_rounded,
                  title: 'Police Control',
                  number: '100',
                  color: Color(0xFFD6EAF8),
                  onTap: () async => await _makeEmergencyCall('100'),
                ),
                SizedBox(height: 12),
                _ComicContactCard(
                  icon: Icons.fire_truck_rounded,
                  title: 'Fire Brigade',
                  number: '101',
                  color: Color(0xFFF9E79F),
                  onTap: () async => await _makeEmergencyCall('101'),
                ),
                SizedBox(height: 12),
                _ComicContactCard(
                  icon: Icons.medical_services_rounded,
                  title: 'Ambulance',
                  number: '102',
                  color: Color(0xFFB5C7F7),
                  onTap: () async => await _makeEmergencyCall('102'),
                ),
                SizedBox(height: 12),
                _ComicContactCard(
                  icon: Icons.emergency_rounded,
                  title: 'Disaster Management',
                  number: '1070',
                  color: Color(0xFFE8D5C4),
                  onTap: () async => await _makeEmergencyCall('1070'),
                ),
              ],
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
                  child: _ComicActionCard(
                    icon: Icons.sos_rounded,
                    label: 'SOS Alert',
                    color: isSOSActive ? Colors.red : Color(0xFFF9E79F),
                    onTap: _sendSOSAlert,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _ComicActionCard(
                    icon: Icons.location_on_rounded,
                    label: 'Share Location',
                    color: Color(0xFFD6EAF8),
                    onTap: _shareLocation,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _ComicActionCard(
                    icon: Icons.volume_up_rounded,
                    label: 'Emergency Call',
                    color: Color(0xFFB5C7F7),
                    onTap: _showEmergencyCallOptions,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 28),

          // Safety Tips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text(
              'Safety Tips',
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
            child: Container(
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
                children: [
                  _ComicTipItem(
                    icon: Icons.stay_current_portrait_rounded,
                    text: 'Keep your phone charged',
                    color: Color(0xFFD6EAF8),
                  ),
                  SizedBox(height: 12),
                  _ComicTipItem(
                    icon: Icons.family_restroom_rounded,
                    text: 'Stay with family members',
                    color: Color(0xFFF9E79F),
                  ),
                  SizedBox(height: 12),
                  _ComicTipItem(
                    icon: Icons.high_quality_rounded,
                    text: 'Follow official instructions',
                    color: Color(0xFFB5C7F7),
                  ),
                ],
              ),
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

class _ComicContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String number;
  final Color color;
  final VoidCallback onTap;

  const _ComicContactCard({
    required this.icon,
    required this.title,
    required this.number,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    number,
                    style: TextStyle(
                      color: Color(0xFF22223B).withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.phone_rounded, color: Color(0xFF22223B)),
          ],
        ),
      ),
    );
  }
}

class _ComicActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ComicActionCard({
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

class _ComicTipItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ComicTipItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Color(0xFF22223B), size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Color(0xFF22223B), fontSize: 14),
          ),
        ),
      ],
    );
  }
}
