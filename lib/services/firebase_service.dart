import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseService {
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static FirebaseAnalytics? _analytics;
  static bool _isInitialized = false;

  static FirebaseAuth get auth => _auth!;
  static FirebaseFirestore get firestore => _firestore!;
  static FirebaseAnalytics get analytics => _analytics!;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDTfDY09FerSxWpd3srb_zHC_WhRPyNzsM",
          authDomain: "flood-management-193b1.firebaseapp.com",
          projectId: "flood-management-193b1",
          storageBucket: "flood-management-193b1.firebasestorage.app",
          messagingSenderId: "1089627754003",
          appId: "1:1089627754003:web:e4ec97c8ead510dec739e6",
          measurementId: "G-G95DJLY46M",
        ),
      );

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _analytics = FirebaseAnalytics.instance;
      
      _isInitialized = true;
      print('Firebase initialized successfully');
    } catch (e) {
      print('Error initializing Firebase: $e');
      _isInitialized = false;
    }
  }

  // User authentication methods
  static Future<UserCredential?> signInAnonymously() async {
    if (!_isInitialized) await initialize();
    try {
      return await _auth!.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    if (!_isInitialized) return;
    try {
      await _auth!.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Firestore methods for storing user data
  static Future<void> saveUserData(String userId, Map<String, dynamic> userData) async {
    if (!_isInitialized) await initialize();
    try {
      await _firestore!.collection('users').doc(userId).set(userData);
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (!_isInitialized) await initialize();
    try {
      final doc = await _firestore!.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Analytics methods
  static Future<void> logEvent(String eventName, Map<String, Object>? parameters) async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics!.logEvent(name: eventName, parameters: parameters);
    } catch (e) {
      print('Error logging analytics event: $e');
    }
  }

  // Flood data storage methods
  static Future<void> saveFloodData(String city, Map<String, dynamic> floodData) async {
    if (!_isInitialized) await initialize();
    try {
      await _firestore!.collection('flood_data').doc(city).set({
        ...floodData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving flood data: $e');
    }
  }

  static Future<Map<String, dynamic>?> getFloodData(String city) async {
    if (!_isInitialized) await initialize();
    try {
      final doc = await _firestore!.collection('flood_data').doc(city).get();
      return doc.data();
    } catch (e) {
      print('Error getting flood data: $e');
      return null;
    }
  }

  // Emergency contacts storage
  static Future<void> saveEmergencyContact(String userId, Map<String, dynamic> contact) async {
    if (!_isInitialized) await initialize();
    try {
      await _firestore!.collection('users').doc(userId)
          .collection('emergency_contacts').add(contact);
    } catch (e) {
      print('Error saving emergency contact: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getEmergencyContacts(String userId) async {
    if (!_isInitialized) await initialize();
    try {
      final querySnapshot = await _firestore!.collection('users').doc(userId)
          .collection('emergency_contacts').get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting emergency contacts: $e');
      return [];
    }
  }
} 