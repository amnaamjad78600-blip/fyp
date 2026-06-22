import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// LOGIN
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        final uid = result.user!.uid;
        // Self-healing: Automatically restore/create user profile document if missing
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'email': email.trim(),
            'username': email.split('@')[0],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      return result.user;
    } on FirebaseAuthException catch (e) {

      if (e.code == 'user-not-found') {
        throw "No account found. Please signup.";
      } else if (e.code == 'wrong-password') {
        throw "Incorrect password.";
      } else if (e.code == 'invalid-email') {
        throw "Invalid email format.";
      } else {
        throw e.message ?? "Login failed";
      }
    }
  }

  /// SIGNUP
  Future<User?> signup(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        final uid = result.user!.uid;
        // Initialize user profile document in Firestore users collection
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email.trim(),
          'username': email.split('@')[0],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return result.user;
    } on FirebaseAuthException catch (e) {

      if (e.code == 'email-already-in-use') {
        throw "Email already exists. Please login.";
      } else if (e.code == 'weak-password') {
        throw "Password must be strong.";
      } else {
        throw e.message ?? "Signup failed";
      }
    }
  }

  /// LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}