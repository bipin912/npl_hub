
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles authentication operations separately from the UI.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  // Prevent repeated initialization of the Google Sign-In SDK.
  Future<void>? _googleInitialization;

  /// Provides the currently signed-in Firebase user, if any.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Initializes Google Sign-In and signs the user into Firebase.
  Future<UserCredential> signInWithGoogle() async {
    // Initialize Google Sign-In only once.
    _googleInitialization ??= _googleSignIn.initialize(
      serverClientId: '1037437956680-l2sn44f6tt531vb6e47b2eo6p96q6l1f.apps.googleusercontent.com',
    );
    await _googleInitialization;

    // Open Google's account selection interface.
    final GoogleSignInAccount googleUser =
    await _googleSignIn.authenticate();

    // Get the ID token needed to authenticate with Firebase.
    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final String? idToken = googleAuth.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    // Exchange Google's ID token for a Firebase user session.
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs the user out of both Firebase and Google.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}
