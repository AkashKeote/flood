import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_data.dart';
import 'firebase_service.dart';

class UserService {
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  
  static UserData? _currentUser;
  static bool _isInitialized = false;

  // Get current user
  static UserData? get currentUser => _currentUser;

  // Check if user is logged in
  static bool get isLoggedIn => _currentUser?.isLoggedIn ?? false;

  // Initialize user service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadUserData();
    _isInitialized = true;
  }

  // Load user data from storage
  static Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson != null) {
        final userMap = json.decode(userJson);
        _currentUser = UserData.fromJson(userMap);
      } else {
        _currentUser = UserData.empty();
      }
    } catch (e) {
      _currentUser = UserData.empty();
    }
  }

  // Save user data to storage
  static Future<void> _saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        final userJson = json.encode(_currentUser!.toJson());
        await prefs.setString(_userKey, userJson);
        await prefs.setBool(_isLoggedInKey, _currentUser!.isLoggedIn);
      }
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  // Login user
  static Future<bool> login(String name, String city) async {
    try {
      // Create user data
      _currentUser = UserData(
        name: name,
        selectedCity: city,
        lastLogin: DateTime.now(),
        isLoggedIn: true,
      );
      
      // Save to local storage
      await _saveUserData();
      
      // Try to save to Firebase (but don't fail if it doesn't work)
      try {
        if (FirebaseService.isInitialized) {
          final userCredential = await FirebaseService.signInAnonymously();
          if (userCredential != null) {
            await FirebaseService.saveUserData(
              userCredential.user!.uid,
              _currentUser!.toJson(),
            );
            
            await FirebaseService.logEvent('user_login', {
              'user_name': name,
              'selected_city': city,
            });
          }
        }
      } catch (firebaseError) {
        print('Firebase error (non-critical): $firebaseError');
        // Continue with local login even if Firebase fails
      }
      
      return true;
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  // Logout user
  static Future<void> logout() async {
    try {
      // Try to log analytics event (but don't fail if it doesn't work)
      try {
        if (FirebaseService.isInitialized) {
          await FirebaseService.logEvent('user_logout', {
            'user_name': _currentUser?.name ?? '',
            'selected_city': _currentUser?.selectedCity ?? '',
          });
          
          await FirebaseService.signOut();
        }
      } catch (firebaseError) {
        print('Firebase error during logout (non-critical): $firebaseError');
      }
      
      _currentUser = UserData.empty();
      await _saveUserData();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Update user's selected city
  static Future<void> updateSelectedCity(String city) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(selectedCity: city);
      await _saveUserData();
    }
  }

  // Update user profile
  static Future<void> updateProfile(String name, String city) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        name: name,
        selectedCity: city,
        lastLogin: DateTime.now(),
      );
      await _saveUserData();
    }
  }

  // Get user's selected city
  static String getSelectedCity() {
    return _currentUser?.selectedCity ?? '';
  }

  // Get user's name
  static String getUserName() {
    return _currentUser?.name ?? '';
  }

  // Clear all user data
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_isLoggedInKey);
      _currentUser = UserData.empty();
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }
} 