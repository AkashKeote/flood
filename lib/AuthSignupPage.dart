import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'UserSetupPage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthSignupPage extends StatefulWidget {
  const AuthSignupPage({super.key});

  @override
  State<AuthSignupPage> createState() => _AuthSignupPageState();
}

class _AuthSignupPageState extends State<AuthSignupPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (name.isEmpty) {
      _toast('Please enter your name');
      return;
    }
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _toast('Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _toast('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      _toast('Passwords do not match');
      return;
    }

    setState(() { _isLoading = true; });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email sent. Please check your inbox.'),
            backgroundColor: Colors.blue[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const UserSetupPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 24, vertical: isDesktop ? 40 : 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: isDesktop ? 20 : 30),
                  Container(
                    width: isDesktop ? 140 : 120,
                    height: isDesktop ? 140 : 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5C7F7),
                      borderRadius: BorderRadius.circular(isDesktop ? 36 : 32),
                    ),
                    child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 60),
                  ),
                  SizedBox(height: isDesktop ? 24 : 18),
                  Text('Create your account', style: GoogleFonts.poppins(fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.bold, color: const Color(0xFF22223B))),
                  SizedBox(height: isDesktop ? 30 : 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 32 : 24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isDesktop ? 24 : 20), boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: isDesktop ? 20 : 15, offset: Offset(0, isDesktop ? 10 : 8)),
                    ]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Name', style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: _inputDecoration(isDesktop, 'Enter your name'),
                        style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, color: const Color(0xFF22223B)),
                      ),
                      SizedBox(height: isDesktop ? 18 : 14),
                      Text('Email', style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(isDesktop, 'your@email.com'),
                        style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, color: const Color(0xFF22223B)),
                      ),
                      SizedBox(height: isDesktop ? 18 : 14),
                      Text('Password', style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(isDesktop, 'Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, color: const Color(0xFF22223B)),
                      ),
                      SizedBox(height: isDesktop ? 18 : 14),
                      Text('Confirm Password', style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: _inputDecoration(isDesktop, 'Re-enter password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, color: const Color(0xFF22223B)),
                      ),
                      SizedBox(height: isDesktop ? 24 : 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB5C7F7),
                            foregroundColor: const Color(0xFF22223B),
                            padding: EdgeInsets.symmetric(vertical: isDesktop ? 18 : 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDesktop ? 14 : 12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Sign Up', style: GoogleFonts.poppins(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 12 : 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account? ", style: GoogleFonts.poppins(fontSize: isDesktop ? 14 : 12)),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const UserSetupPage()),
                            ),
                            child: Text('Back to Login', style: GoogleFonts.poppins(fontSize: isDesktop ? 14 : 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      )
                    ]),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDesktop, String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        borderSide: const BorderSide(color: Color(0xFFB5C7F7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        borderSide: const BorderSide(color: Color(0xFFB5C7F7), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      filled: true,
      fillColor: const Color(0xFFF7F6F2),
      contentPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16, vertical: isDesktop ? 16 : 14),
    );
  }
}


