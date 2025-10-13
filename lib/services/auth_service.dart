import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _tokenRefreshTimer;

  Stream<User?> get userChanges => _auth.authStateChanges();

  // Constructor to start token refresh monitoring
  AuthService() {
    _initTokenRefresh();
  }

  // Initialize token refresh to prevent session timeouts
  void _initTokenRefresh() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // Cancel existing timer if any
        _tokenRefreshTimer?.cancel();
        
        // Refresh token every 50 minutes (tokens expire after 1 hour)
        _tokenRefreshTimer = Timer.periodic(
          const Duration(minutes: 50),
          (_) => _refreshToken(user),
        );
      } else {
        // Cancel timer when user logs out
        _tokenRefreshTimer?.cancel();
      }
    });
  }

  // Refresh the user's auth token
  Future<void> _refreshToken(User user) async {
    try {
      await user.getIdToken(true); // Force token refresh
      debugPrint('Auth token refreshed successfully');
    } catch (e) {
      debugPrint('Token refresh error: $e');
    }
  }

  // Manually trigger token refresh if needed
  Future<void> refreshCurrentUserToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _refreshToken(user);
    }
  }

  // Dispose timer when service is destroyed
  void dispose() {
    _tokenRefreshTimer?.cancel();
  }

  Future<User?> signInWithEmail(String email, String pwd) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pwd,
      );
      return cred.user;
    } catch (e) {
      // Handle error (e.g., log or rethrow)
      return null;
    }
  }

  Future<User?> registerWithEmail(String email, String pwd) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pwd,
      );
      return cred.user;
    } catch (e) {
      // Handle error
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Optimized popup with better error handling
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        final UserCredential userCredential = await _auth
            .signInWithPopup(googleProvider)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Sign-in timeout. Please try again.'),
            );
        return userCredential.user;
      } else {
        // Mobile/Desktop: Use the working authenticate method with optimizations
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;
        
        // Note: Removed signOut() to improve speed - authenticate() will handle existing sessions
        
        // Use authenticate method with timeout handling
        GoogleSignInAccount? googleUser;
        try {
          googleUser = await googleSignIn
              .authenticate()
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          // Handle timeout or any other error
          debugPrint('Google authentication error: $e');
          return null;
        }

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        
        final UserCredential userCredential = await _auth
            .signInWithCredential(credential)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception('Firebase authentication timeout'),
            );
            
        return userCredential.user;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
