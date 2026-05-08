import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Stream ────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ── Email / Password register ─────────────
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    File? avatarFile,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // Upload avatar if provided
    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _uploadAvatar(uid, avatarFile);
    }

    // Update Firebase Auth display name
    await credential.user!.updateDisplayName(displayName.trim());
    if (avatarUrl != null) {
      await credential.user!.updatePhotoURL(avatarUrl);
    }

    final user = UserModel(
      uid: uid,
      displayName: displayName.trim(),
      email: email.trim(),
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .set(user.toFirestore());

    return user;
  }

  // ── Email / Password login ────────────────
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _fetchOrCreateUserDoc(credential.user!);
  }

  // ── Google Sign-In ────────────────────────
  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in was cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return _fetchOrCreateUserDoc(userCredential.user!);
  }

  // ── Microsoft OAuth (OIDC) ────────────────
  // Uses Firebase's OAuthProvider for Microsoft.
  // The tenant and client ID are configured in the Firebase console under
  // Authentication → Sign-in method → Microsoft.
  Future<UserModel> signInWithMicrosoft() async {
    final provider = OAuthProvider('microsoft.com')
      ..addScope('email')
      ..addScope('openid')
      ..addScope('profile');

    final userCredential = await _auth.signInWithProvider(provider);
    return _fetchOrCreateUserDoc(userCredential.user!);
  }

  // ── Password reset ────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign out ──────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Update profile ────────────────────────
  Future<UserModel> updateProfile({
    required String uid,
    String? displayName,
    File? avatarFile,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (displayName != null && displayName.trim().isNotEmpty) {
      updates['displayName'] = displayName.trim();
      await _auth.currentUser?.updateDisplayName(displayName.trim());
    }

    if (avatarFile != null) {
      final avatarUrl = await _uploadAvatar(uid, avatarFile);
      updates['avatarUrl'] = avatarUrl;
      await _auth.currentUser?.updatePhotoURL(avatarUrl);
    }

    await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .update(updates);

    final doc = await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .get();
    return UserModel.fromFirestore(doc);
  }

  // ── Fetch current user doc ─────────────────
  Future<UserModel?> fetchUserDoc(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ── Private helpers ───────────────────────
  Future<String> _uploadAvatar(String uid, File file) async {
  final ref = _storage
      .ref()
      .child('${AppConstants.storageAvatars}/$uid/avatar.jpg');
  await ref.putFile(file);
  return ref.getDownloadURL();
}

  Future<UserModel> _fetchOrCreateUserDoc(User firebaseUser) async {
    final docRef = _firestore
        .collection(AppConstants.colUsers)
        .doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }

    // First-time social login — create Firestore record
    final user = UserModel(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'MindMate User',
      email: firebaseUser.email ?? '',
      avatarUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(user.toFirestore());
    return user;
  }

  // ── Human-readable Firebase error messages ─
  static String parseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
