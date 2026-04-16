import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Display name and email for UI
  String get displayName =>
      _auth.currentUser?.displayName ??
      _auth.currentUser?.email ??
      'BioVolt User';
  String? get email => _auth.currentUser?.email;
  String? get photoUrl => _auth.currentUser?.photoURL;

  /// Sign in with Google.
  /// If user was previously anonymous, links the accounts so
  /// all existing data is preserved under the same UID.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Force account picker to show even if already signed in to Google
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      debugPrint('Google user: ${googleUser?.email}');

      if (googleUser == null) {
        debugPrint('Google sign-in cancelled by user');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      debugPrint('Got google auth tokens');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          final result = await currentUser.linkWithCredential(credential);
          debugPrint('Linked anonymous to Google: ${result.user?.uid}');
          return result;
        } on FirebaseAuthException catch (e) {
          debugPrint('Link failed (${e.code}), signing in directly');
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            return await _auth.signInWithCredential(credential);
          }
          rethrow;
        }
      }

      final result = await _auth.signInWithCredential(credential);
      debugPrint('Signed in: ${result.user?.uid}');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'FirebaseAuthException in signInWithGoogle: ${e.code} ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error in signInWithGoogle: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Sign in anonymously as guest.
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Get user ID, signing in anonymously if needed.
  Future<String> getUserId() async {
    User? user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user!;
    }
    return user.uid;
  }
}
