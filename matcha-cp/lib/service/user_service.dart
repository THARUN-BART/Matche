import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<void> updateProfile({
    required String name,
    required List<String> skills,
    required List<String> interests,
    required List<String> availability,
    required String personalityType,
  }) async {
    await _firestore.collection('users').doc(currentUserId).set({
      'name': name,
      'skills': skills,
      'interests': interests,
      'availability': availability,
      'personalityType': personalityType,
      'online': true,
      'email': _auth.currentUser?.email,
    }, SetOptions(merge: true));
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    await _firestore.collection('users').doc(currentUserId).update({
      'online': isOnline,
    });
  }

  Stream<DocumentSnapshot> getUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
} 