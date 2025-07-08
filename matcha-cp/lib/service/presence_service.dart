import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<void> setOnline() async {
    await _firestore.collection('users').doc(currentUserId).update({'online': true});
  }

  Future<void> setOffline() async {
    await _firestore.collection('users').doc(currentUserId).update({'online': false});
  }

  Stream<bool> isUserOnline(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
        (doc) => (doc.data()?['online'] ?? false) as bool
    );
  }
}