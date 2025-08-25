import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_service.dart';
import 'UserSetupPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = 'User';
  String userWard = 'Ward';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await UserService.getUserName();
    final ward = await UserService.getUserWard();
    
    setState(() {
      userName = name ?? 'User';
      userWard = ward ?? 'Ward';
    });
  }

  Future<void> _logout() async {
    await UserService.logout();
    
    // Navigate to UserSetupPage
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
            padding:
                const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
            child: Text(
              'Your Profile\nSettings & Info',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
          ),

          // Profile Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _ComicStatCard(
                  title: 'Alerts',
                  value: '12',
                  color: Color(0xFFF9E79F),
                  icon: Icons.notifications_rounded,
                ),
                SizedBox(width: 16),
                _ComicStatCard(
                  title: 'Reports',
                  value: '5',
                  color: Color(0xFFD6EAF8),
                  icon: Icons.assessment_rounded,
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Profile Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Wrap(
              spacing: 10,
              children: [
                _ComicChip(label: 'Active', color: Color(0xFFD6EAF8)),
                _ComicChip(label: 'Verified', color: Color(0xFFF9E79F)),
                _ComicChip(label: 'Premium', color: Color(0xFFB5C7F7)),
              ],
            ),
          ),

          SizedBox(height: 28),

          // Profile Info Card
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
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFB5C7F7),
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: Color(0xFF22223B),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22223B),
                    ),
                  ),
                  Text(
                    '$userWard, Mumbai',
                    style: TextStyle(
                      color: Color(0xFF22223B).withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ComicInfoItem(
                        icon: Icons.location_on_rounded,
                        label: 'Mumbai',
                        color: Color(0xFFD6EAF8),
                      ),
                      _ComicInfoItem(
                        icon: Icons.phone_rounded,
                        label: '+91 98765 43210',
                        color: Color(0xFFF9E79F),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 28),

          // Settings Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text(
              'Settings',
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
                _ComicSettingCard(
                  icon: Icons.notifications_rounded,
                  title: 'Push Notifications',
                  subtitle: 'Get flood alerts',
                  color: Color(0xFFD6EAF8),
                  onTap: () {},
                ),
                SizedBox(height: 12),
                _ComicSettingCard(
                  icon: Icons.location_on_rounded,
                  title: 'Location Services',
                  subtitle: 'Share your location',
                  color: Color(0xFFF9E79F),
                  onTap: () {},
                ),
                SizedBox(height: 12),
                _ComicSettingCard(
                  icon: Icons.security_rounded,
                  title: 'Privacy Settings',
                  subtitle: 'Manage your data',
                  color: Color(0xFFB5C7F7),
                  onTap: () {},
                ),
                SizedBox(height: 12),
                _ComicSettingCard(
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get assistance',
                  color: Color(0xFFE8D5C4),
                  onTap: () {},
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
                    icon: Icons.edit_rounded,
                    label: 'Edit Profile',
                    color: Color(0xFFF9E79F),
                    onTap: () {},
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _ComicActionCard(
                    icon: Icons.share_rounded,
                    label: 'Share App',
                    color: Color(0xFFD6EAF8),
                    onTap: () {},
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _ComicActionCard(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: Color(0xFFFFCDD2),
                    onTap: _logout,
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

class _ComicInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ComicInfoItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Color(0xFF22223B), size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF22223B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicSettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ComicSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                    subtitle,
                    style: TextStyle(
                      color: Color(0xFF22223B).withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF22223B)),
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
