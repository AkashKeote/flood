import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_service.dart';
import 'UserSetupPage.dart';
import 'EditProfilePage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = 'User';
  String userWard = 'Ward';
  String userEmail = '';
  String userPhone = '';
  bool notificationsEnabled = true;
  bool locationEnabled = true;
  bool privacyEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  Future<void> _loadUserData() async {
    final name = await UserService.getUserName();
    final ward = await UserService.getUserWard();
    final email = await UserService.getUserEmail();
    final phone = await UserService.getUserPhone();

    setState(() {
      userName = name ?? 'User';
      userWard = ward ?? 'Ward';
      userEmail = email ?? '';
      userPhone = phone ?? '+91 98765 43210';
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      locationEnabled = prefs.getBool('location_enabled') ?? true;
      privacyEnabled = prefs.getBool('privacy_enabled') ?? true;
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

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          currentName: userName,
          currentWard: userWard,
          currentEmail: userEmail,
          currentPhone: userPhone,
        ),
      ),
    );

    if (result == true) {
      // Reload user data after editing
      await _loadUserData();
    }
  }

  Future<void> _toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = !notificationsEnabled;
    });
    await prefs.setBool('notifications_enabled', notificationsEnabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notificationsEnabled
              ? 'Push notifications enabled'
              : 'Push notifications disabled',
        ),
        backgroundColor: notificationsEnabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _toggleLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      locationEnabled = !locationEnabled;
    });
    await prefs.setBool('location_enabled', locationEnabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          locationEnabled
              ? 'Location services enabled'
              : 'Location services disabled',
        ),
        backgroundColor: locationEnabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _togglePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      privacyEnabled = !privacyEnabled;
    });
    await prefs.setBool('privacy_enabled', privacyEnabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          privacyEnabled
              ? 'Privacy settings enabled'
              : 'Privacy settings disabled',
        ),
        backgroundColor: privacyEnabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _showHelpSupport() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Here are some options:'),
            SizedBox(height: 16),
            Text('📧 Email: support@floodapp.com'),
            Text('📞 Phone: +91 98765 43210'),
            Text('💬 Live Chat: Available 24/7'),
            SizedBox(height: 16),
            Text('Common Issues:'),
            Text('• Reset password'),
            Text('• Update location'),
            Text('• Report bugs'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareApp() async {
    // This would typically use a share package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share functionality would open here'),
        backgroundColor: Colors.blue,
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
                        label: userPhone,
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
                  subtitle: notificationsEnabled ? 'Enabled' : 'Disabled',
                  color: Color(0xFFD6EAF8),
                  onTap: _toggleNotifications,
                  trailing: Switch(
                    value: notificationsEnabled,
                    onChanged: (value) => _toggleNotifications(),
                    activeColor: Color(0xFF22223B),
                  ),
                ),
                SizedBox(height: 12),
                _ComicSettingCard(
                  icon: Icons.location_on_rounded,
                  title: 'Location Services',
                  subtitle: locationEnabled ? 'Enabled' : 'Disabled',
                  color: Color(0xFFF9E79F),
                  onTap: _toggleLocation,
                  trailing: Switch(
                    value: locationEnabled,
                    onChanged: (value) => _toggleLocation(),
                    activeColor: Color(0xFF22223B),
                  ),
                ),
                SizedBox(height: 12),
                _ComicSettingCard(
                  icon: Icons.security_rounded,
                  title: 'Privacy Settings',
                  subtitle: privacyEnabled ? 'Enabled' : 'Disabled',
                  color: Color(0xFFB5C7F7),
                  onTap: _togglePrivacy,
                  trailing: Switch(
                    value: privacyEnabled,
                    onChanged: (value) => _togglePrivacy(),
                    activeColor: Color(0xFF22223B),
                  ),
                ),
                SizedBox(height: 12),
                _ComicSettingCard(
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get assistance',
                  color: Color(0xFFE8D5C4),
                  onTap: _showHelpSupport,
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
                    onTap: _editProfile,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _ComicActionCard(
                    icon: Icons.share_rounded,
                    label: 'Share App',
                    color: Color(0xFFD6EAF8),
                    onTap: _shareApp,
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
  final Widget? trailing;

  const _ComicSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
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
            trailing ??
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
