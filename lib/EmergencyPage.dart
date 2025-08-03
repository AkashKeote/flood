import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'services/firebase_service.dart';
import 'services/user_service.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool _isSOSActive = false;
  final List<EmergencyContact> _emergencyContacts = [
    EmergencyContact(
      name: 'Police Control',
      number: '100',
      icon: Icons.local_police_rounded,
      color: Color(0xFFD6EAF8),
      description: 'General emergency and police assistance',
    ),
    EmergencyContact(
      name: 'Fire Brigade',
      number: '101',
      icon: Icons.fire_truck_rounded,
      color: Color(0xFFF9E79F),
      description: 'Fire emergencies and rescue operations',
    ),
    EmergencyContact(
      name: 'Ambulance',
      number: '102',
      icon: Icons.medical_services_rounded,
      color: Color(0xFFFF6B6B),
      description: 'Medical emergencies and ambulance service',
    ),
    EmergencyContact(
      name: 'Flood Control',
      number: '022-24937746',
      icon: Icons.water_drop_rounded,
      color: Color(0xFFB5C7F7),
      description: 'Mumbai flood control and drainage',
    ),
    EmergencyContact(
      name: 'NDRF Helpline',
      number: '011-23438000',
      icon: Icons.security_rounded,
      color: Color(0xFF4CAF50),
      description: 'National Disaster Response Force',
    ),
    EmergencyContact(
      name: 'Weather Alert',
      number: '1800-180-1717',
      icon: Icons.cloud_rounded,
      color: Color(0xFFE8F4FD),
      description: 'Weather updates and storm warnings',
    ),
  ];

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

          // SOS Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: _isSOSActive ? Color(0xFFF44336) : Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isSOSActive ? Color(0xFFF44336) : Color(0xFF4CAF50))
                            .withOpacity(0.3),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _toggleSOS,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSOSActive
                              ? Icons.emergency_rounded
                              : Icons.sos_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          _isSOSActive ? 'SOS ACTIVE' : 'SOS EMERGENCY',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 24),

          // Emergency Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _ComicStatCard(
                  title: 'Response Time',
                  value: '2 min',
                  color: Color(0xFFF9E79F),
                  icon: Icons.timer_rounded,
                ),
                SizedBox(width: 16),
                _ComicStatCard(
                  title: 'Active Alerts',
                  value: '3',
                  color: Color(0xFFD6EAF8),
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Emergency Protocols
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text(
              'Emergency Protocols',
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
                _ProtocolCard(
                  title: 'Flood Evacuation',
                  description:
                      'Move to higher ground immediately. Do not walk through moving water.',
                  icon: Icons.directions_run_rounded,
                  color: Color(0xFFFF6B6B),
                  onTap: () => _showProtocolDetails('Flood Evacuation'),
                ),
                SizedBox(height: 12),
                _ProtocolCard(
                  title: 'Emergency Kit',
                  description:
                      'Keep essential items ready: water, food, medicines, documents.',
                  icon: Icons.medical_services_rounded,
                  color: Color(0xFF4CAF50),
                  onTap: () => _showProtocolDetails('Emergency Kit'),
                ),
                SizedBox(height: 12),
                _ProtocolCard(
                  title: 'Stay Informed',
                  description:
                      'Monitor weather updates and official announcements.',
                  icon: Icons.info_rounded,
                  color: Color(0xFF2196F3),
                  onTap: () => _showProtocolDetails('Stay Informed'),
                ),
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
              children: _emergencyContacts
                  .map(
                    (contact) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _ComicContactCard(
                        icon: contact.icon,
                        title: contact.name,
                        number: contact.number,
                        color: contact.color,
                        onTap: () => _callEmergency(contact),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  void _toggleSOS() async {
    setState(() {
      _isSOSActive = !_isSOSActive;
    });

    if (_isSOSActive) {
      // Log SOS activation to Firebase
      await FirebaseService.logEvent('sos_activated', {
        'user_name': UserService.getUserName(),
        'user_city': UserService.getSelectedCity(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      _showSOSDialog();
    } else {
      // Log SOS deactivation to Firebase
      await FirebaseService.logEvent('sos_deactivated', {
        'user_name': UserService.getUserName(),
        'user_city': UserService.getSelectedCity(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SOS deactivated'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency_rounded, color: Color(0xFFF44336)),
            SizedBox(width: 8),
            Text('SOS ACTIVATED'),
          ],
        ),
        content: Text(
          'Emergency services are being notified. Stay calm and follow instructions.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isSOSActive = false;
              });
            },
            child: Text('Cancel SOS'),
          ),
        ],
      ),
    );
  }

  void _callEmergency(EmergencyContact contact) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(contact.icon, color: contact.color),
            SizedBox(width: 8),
            Text(contact.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.description),
            SizedBox(height: 8),
            Text('Number: ${contact.number}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Log emergency call to Firebase
              await FirebaseService.logEvent('emergency_call', {
                'contact_name': contact.name,
                'contact_number': contact.number,
                'user_name': UserService.getUserName(),
                'user_city': UserService.getSelectedCity(),
                'timestamp': DateTime.now().toIso8601String(),
              });
              _makeCall(contact.number);
            },
            child: Text('Call Now'),
          ),
        ],
      ),
    );
  }

  void _makeCall(String number) {
    // In a real app, this would use url_launcher package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $number...'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _showProtocolDetails(String protocol) {
    String content = '';
    switch (protocol) {
      case 'Flood Evacuation':
        content = '''
• Move to higher ground immediately
• Do not walk through moving water
• Avoid driving through flooded areas
• Stay away from downed power lines
• Listen to emergency broadcasts
• Follow evacuation orders
        ''';
        break;
      case 'Emergency Kit':
        content = '''
• Water (1 gallon per person per day)
• Non-perishable food
• First aid kit and medicines
• Flashlight and batteries
• Important documents
• Cash and credit cards
• Phone charger and power bank
        ''';
        break;
      case 'Stay Informed':
        content = '''
• Monitor weather updates
• Listen to official announcements
• Follow local emergency services
• Check flood warnings regularly
• Have multiple information sources
• Share information with neighbors
        ''';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(protocol),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

class EmergencyContact {
  final String name;
  final String number;
  final IconData icon;
  final Color color;
  final String description;

  EmergencyContact({
    required this.name,
    required this.number,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _ProtocolCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProtocolCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
            ],
          ),
        ),
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
