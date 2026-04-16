import 'package:firebase_auth/firebase_auth.dart';
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
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // If currently anonymous, link to Google account
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        return await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          // Google account already exists — sign in to it instead
          return await _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }

    return await _auth.signInWithCredential(credential);
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
