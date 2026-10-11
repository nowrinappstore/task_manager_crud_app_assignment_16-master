import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Email Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Sign Up with Name, Email and Password
  Future<UserCredential> signUp(
    String name,
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user?.updateDisplayName(name.trim());

    return credential;
  }

  // Email Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static bool _googleInitialized = false;

  // Google Sign-In must be initialized exactly once per app run.
  static Future<void> initGoogle() async {
    if (_googleInitialized) return;

    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await initGoogle();

      final googleSignIn = GoogleSignIn.instance;

      final GoogleSignInAccount account = await googleSignIn.authenticate();

      final GoogleSignInAuthentication auth = account.authentication;

      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);

      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in failed: ${e.code}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Google sign-in failed: ${e.code}');
      rethrow;
    }
  }

  // Facebook Sign In
  Future<void> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();

    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw FirebaseAuthException(
        code: 'facebook-sign-in-cancelled',
        message: 'Facebook sign-in was cancelled or failed.',
      );
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );

    await _auth.signInWithCredential(credential);
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out: $e');
    }

    try {
      await FacebookAuth.instance.logOut();
    } catch (e) {
      debugPrint('Facebook sign-out: $e');
    }

    await _auth.signOut();
  }

  // Firebase Error Messages
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'এই ইমেইল দিয়ে আগে থেকেই অ্যাকাউন্ট খোলা আছে।';

        case 'invalid-email':
          return 'সঠিক ইমেইল ঠিকানা লিখুন।';

        case 'weak-password':
          return 'আরও শক্তিশালী পাসওয়ার্ড ব্যবহার করুন।';

        case 'user-not-found':
          return 'এই ইমেইলে কোনো অ্যাকাউন্ট পাওয়া যায়নি।';

        case 'wrong-password':
        case 'invalid-credential':
          return 'ইমেইল অথবা পাসওয়ার্ড সঠিক নয়।';

        case 'network-request-failed':
          return 'ইন্টারনেট সংযোগ পরীক্ষা করুন।';

        case 'too-many-requests':
          return 'অনেকবার চেষ্টা করা হয়েছে। কিছুক্ষণ পরে চেষ্টা করুন।';

        default:
          return error.message ?? 'Authentication ব্যর্থ হয়েছে।';
      }
    }

    return 'একটি সমস্যা হয়েছে: $error';
  }
}
