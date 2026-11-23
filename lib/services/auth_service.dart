import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    return cred.user;
  }

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<void> signOut() => _auth.signOut();

  /// Turns a Firebase error into a short message for the screen.
  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists. Try logging in.';
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is wrong.';
        case 'network-request-failed':
          return 'No internet connection. Check your network and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        default:
          return error.message ?? 'Something went wrong. Try again.';
      }
    }
    return 'Something went wrong. Try again.';
  }
}
