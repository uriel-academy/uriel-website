import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get userChanges => _auth.authStateChanges();

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
          print('Google authentication error: $e');
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
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
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
