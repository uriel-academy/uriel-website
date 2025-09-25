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
        // Web: use signInWithPopup
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Mobile/Desktop: use GoogleSignIn 7.x
        final GoogleSignIn signIn = GoogleSignIn.instance;
        final GoogleSignInAccount user = await signIn.authenticate();
        final GoogleSignInAuthentication googleAuth = user.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      // Handle error
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
