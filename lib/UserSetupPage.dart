import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'user_service.dart';
import 'auth_service.dart';
import 'alert_service.dart';

class UserSetupPage extends StatefulWidget {
  const UserSetupPage({super.key});

  @override
  State<UserSetupPage> createState() => _UserSetupPageState();
}

class _UserSetupPageState extends State<UserSetupPage>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _selectedWard;
  List<String> _wards = [];
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  // Mumbai areas from backend dummyFloodData (exact names from your backend)
  final List<String> _mumbaiAreas = [
    'Andheri East',
    'Andheri West', 
    'Bandra East',
    'Bandra West',
    'Borivali East',
    'Borivali West',
    'Colaba',
    'Dadar East',
    'Dadar West',
    'Fort',
    'Ghatkopar East',
    'Ghatkopar West',
    'Juhu',
    'Kandivali East',
    'Kandivali West',
    'Kurla East',
    'Kurla West',
    'Lower Parel',
    'Malad East',
    'Malad West',
    'Marine Lines',
    'Mumbai',
    'Powai',
    'Santa Cruz East',
    'Santa Cruz West',
    'Thane',
    'Thane West',
    'Versova',
    'Vikhroli East',
    'Vikhroli West',
    'Worli'
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Load Mumbai areas and existing user data
    _loadWardsAndUserData();
  }

  Future<void> _loadWardsAndUserData() async {
    // Use Mumbai areas from backend cityService instead of CSV
    if (mounted) {
      setState(() {
        _wards = _mumbaiAreas;
      });
    }

    // Load existing user data
    final name = await UserService.getUserName();
    final area = await UserService.getUserWard(); // Still using getUserWard for backward compatibility
    final email = await UserService.getUserEmail();
    
    if (name != null && name.isNotEmpty) {
      setState(() {
        _nameController.text = name;
      });
    }
    
    if (email != null && email.isNotEmpty) {
      setState(() {
        _emailController.text = email;
      });
    }
    
    if (area != null && area.isNotEmpty) {
      setState(() {
        _selectedWard = area;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _proceedToApp() async {
    if (_nameController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty || 
        _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your name, email and select an area'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save user data locally first
      await UserService.saveUserData(
        _nameController.text.trim(), 
        _selectedWard!, 
        _emailController.text.trim()
      );

      // Register with backend server for email alerts
      final result = await AuthService.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        city: _selectedWard!,
      );

      if (result['success']) {
        // Show success message with backend confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Profile registered successfully with backend!'),
              backgroundColor: Colors.green[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        // Send quick test email for verification
        final direct = await AlertService.sendDirect(
          email: _emailController.text.trim(),
          city: _selectedWard!,
        );
        if (mounted) {
          if (direct['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✉️ Email sent to ${_emailController.text.trim()}'),
                backgroundColor: Colors.green[400],
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Could not send test email: ${direct['error']}'),
                backgroundColor: Colors.orange[400],
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      } else {
        // Check if it's a duplicate email error
        String errorMsg = result['error'] ?? 'Unknown error';
        
        if (errorMsg.toLowerCase().contains('already registered')) {
          // User already exists - this is actually okay
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Welcome back! Email already registered.'),
                backgroundColor: Colors.blue[400],
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          print('✅ User already exists in backend - continuing normally');
          // Still send quick test email so user receives one now
          final direct = await AlertService.sendDirect(
            email: _emailController.text.trim(),
            city: _selectedWard!,
          );
          if (mounted) {
            if (direct['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✉️ Test email sent to ${_emailController.text.trim()}'),
                  backgroundColor: Colors.green[400],
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Could not send test email: ${direct['error']}'),
                  backgroundColor: Colors.orange[400],
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        } else {
          // Other backend error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Saved locally. Backend error: $errorMsg'),
                backgroundColor: Colors.orange[400],
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          print('❌ Backend registration failed: $errorMsg');
          // Attempt direct email even if signup failed (e.g., timeout) so user gets verification
          final direct = await AlertService.sendDirect(
            email: _emailController.text.trim(),
            city: _selectedWard!,
          );
          if (mounted) {
            if (direct['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✉️ Test email sent to ${_emailController.text.trim()}'),
                  backgroundColor: Colors.green[400],
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Could not send test email: ${direct['error']}'),
                  backgroundColor: Colors.orange[400],
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        }
        
        print('📍 User will still be able to use the app locally');
      }

      // Small delay to show the snackbar
      await Future.delayed(Duration(milliseconds: 1000));

      // Navigate to dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DashboardMaterial(),
          ),
        );
      }

    } catch (e) {
      print('Error in _proceedToApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred, please try again'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    
    return Scaffold(
      backgroundColor: Color(0xFFF7F6F2),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7F6F2),
              Color(0xFFB5C7F7).withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 24,
                    vertical: isDesktop ? 40 : 20,
                  ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: isDesktop ? 10 : 20), // Reduced top spacing                      // Animated Logo Container (on background)
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _fadeAnimation.value,
                            child: Container(
                              width: isDesktop ? 140 : 120,
                              height: isDesktop ? 140 : 120,
                              decoration: BoxDecoration(
                                color: Color(0xFFB5C7F7),
                                borderRadius: BorderRadius.circular(isDesktop ? 36 : 32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFB5C7F7).withOpacity(0.3),
                                    blurRadius: isDesktop ? 25 : 20,
                                    offset: Offset(0, isDesktop ? 12 : 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.water_drop_rounded,
                                size: isDesktop ? 70 : 60,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isDesktop ? 30 : 20), // Reduced spacing

                      // Animated Title (on background)
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              'Flood Management',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 32 : 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22223B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isDesktop ? 16 : 8),

                      // Animated Subtitle (on background)
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return SlideTransition(
                            position: _slideAnimation,
                            child: Text(
                              'Stay Safe • Stay Informed',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 18 : 14,
                                color: Color(0xFF22223B).withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isDesktop ? 30 : 20), // Reduced spacing

                      // User Input Container (White Container)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isDesktop ? 32 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              blurRadius: isDesktop ? 20 : 15,
                              offset: Offset(0, isDesktop ? 10 : 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name Input Section
                            Row(
                              children: [
                                Container(
                                  width: isDesktop ? 32 : 28,
                                  height: isDesktop ? 32 : 28,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB5C7F7),
                                    borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: isDesktop ? 18 : 16,
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 16 : 12),
                                Text(
                                  'What is your name?',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF22223B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 20 : 16),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'Enter your name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Color(0xFFB5C7F7)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Color(0xFFB5C7F7), width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Color(0xFFF7F6F2),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 20 : 16, 
                                  vertical: isDesktop ? 20 : 16
                                ),
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 18 : 16,
                                color: Color(0xFF22223B),
                              ),
                            ),
                            
                            SizedBox(height: isDesktop ? 24 : 16), // Reduced spacing
                            
                            // Email Input Section
                            Row(
                              children: [
                                Container(
                                  width: isDesktop ? 32 : 28,
                                  height: isDesktop ? 32 : 28,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB5C7F7),
                                    borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                                  ),
                                  child: Icon(
                                    Icons.email,
                                    color: Colors.white,
                                    size: isDesktop ? 18 : 16,
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 16 : 12),
                                Text(
                                  'Enter your email address',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 18 : 16, // Reduced font size
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF22223B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 16 : 12), // Reduced spacing
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Enter your email address',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Color(0xFFB5C7F7)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Color(0xFFB5C7F7), width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Color(0xFFF7F6F2),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 20 : 16, 
                                  vertical: isDesktop ? 16 : 14 // Reduced padding
                                ),
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 18 : 16,
                                color: Color(0xFF22223B),
                              ),
                            ),
                            
                            SizedBox(height: isDesktop ? 24 : 16), // Reduced spacing
                            
                            // Area Selection Section
                            Row(
                              children: [
                                Container(
                                  width: isDesktop ? 32 : 28,
                                  height: isDesktop ? 32 : 28,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB5C7F7),
                                    borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: isDesktop ? 18 : 16,
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 16 : 12),
                                Text(
                                  'Select your area',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF22223B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 20 : 16),
                            DropdownButtonFormField<String>(
                              value: _wards.contains(_selectedWard) ? _selectedWard : null,
                              decoration: InputDecoration(
                                hintText: 'Select your area in Mumbai',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Color(0xFFB5C7F7)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Color(0xFFB5C7F7), width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Color(0xFFF7F6F2),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 20 : 16, 
                                  vertical: isDesktop ? 20 : 16
                                ),
                              ),
                              items: _wards.map((String ward) {
                                return DropdownMenuItem<String>(
                                  value: ward,
                                  child: Text(
                                    ward,
                                    style: GoogleFonts.poppins(
                                      fontSize: isDesktop ? 18 : 16,
                                      color: Color(0xFF22223B),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) async {
                                String? previousWard = _selectedWard;
                                setState(() {
                                  _selectedWard = newValue;
                                });
                                
                                // When city changes, update user's city in backend
                                if (newValue != null && newValue != previousWard) {
                                  print('🏙️ City changed from $previousWard to $newValue');
                                  final email = _emailController.text.trim();
                                  if (email.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Enter email first to update city'),
                                        backgroundColor: Colors.orange[400],
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Updating your area to $newValue...'),
                                        ],
                                      ),
                                      backgroundColor: Colors.blue[400],
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );

                                  final updateResult = await AlertService.updateCity(
                                    email: email,
                                    newCity: newValue,
                                  );

                                  if (updateResult['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✅ Area updated to $newValue'),
                                        backgroundColor: Colors.green[400],
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('⚠️ Update failed: ${updateResult['error']}'),
                                        backgroundColor: Colors.orange[400],
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isDesktop ? 30 : 20), // Reduced spacing

                      // Continue Button
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proceedToApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFB5C7F7),
                            foregroundColor: Color(0xFF22223B),
                            padding: EdgeInsets.symmetric(
                              vertical: isDesktop ? 22 : 18
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                            ),
                            elevation: 5,
                            shadowColor: Color(0xFFB5C7F7).withOpacity(0.3),
                          ),
                          child: _isLoading 
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22223B)),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: isDesktop ? 20 : 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: isDesktop ? 12 : 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: isDesktop ? 24 : 20,
                                  ),
                                ],
                              ),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 20 : 12), // Reduced bottom spacing
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
