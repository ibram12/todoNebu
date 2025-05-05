import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'user_preferences.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserPreferences _preferences = UserPreferences();

  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthService() {
    // Initialize user state
    _initializeUser();

    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();

      // Save or clear user info based on auth state
      if (user != null) {
        _saveUserInfo(user);
      }
    });
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize user from saved preferences or Firebase
  Future<void> _initializeUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if the user is already logged in
      final isLoggedIn = await _preferences.isLoggedIn();
      if (isLoggedIn) {
        // If logged in, get the current Firebase user
        _user = _auth.currentUser;
      }
    } catch (e) {
      _error = 'Failed to initialize user: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save user info to preferences
  Future<void> _saveUserInfo(User user) async {
    await _preferences.saveUserLoginInfo(
      userId: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Start the sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null; // User canceled the sign-in flow
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase using the Google credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      _user = userCredential.user;

      // Save user info
      if (_user != null) {
        await _saveUserInfo(_user!);
      }

      _isLoading = false;
      notifyListeners();

      return userCredential.user;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await _preferences.clearUserInfo();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Check current auth state
  Future<bool> isSignedIn() async {
    return _auth.currentUser != null || await _preferences.isLoggedIn();
  }

  // Get current user info
  Map<String, dynamic>? getCurrentUserInfo() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
    };
  }
}
