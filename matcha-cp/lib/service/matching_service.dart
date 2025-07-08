import 'firestore_service.dart';

class MatchingService {
  final FirestoreService _firestoreService;

  MatchingService(this._firestoreService);

  /// Finds best matches based on skills, interests, availability, and personality
  Future<List<Map<String, dynamic>>> findMatches() async {
    final currentUserId = _firestoreService.currentUserId;

    // Fetch current user data
    final currentUserSnapshot = await _firestoreService.getUserById(currentUserId);

    if (!currentUserSnapshot.exists) return [];

    final currentUserData = currentUserSnapshot.data() as Map<String, dynamic>;

    // Fetch all users except current
    final allUsersSnapshot = await _firestoreService.getAllUsersExceptCurrent().first;

    List<Map<String, dynamic>> matches = [];

    for (var doc in allUsersSnapshot.docs) {
      final userData = doc.data() as Map<String, dynamic>;

      // Optionally: skip if user already connected
      // You could load connection list and filter here if needed

      final score = _calculateMatchScore(currentUserData, userData);

      matches.add({
        ...userData,
        'id': doc.id,
        'matchScore': score,
      });
    }

    // Sort by score descending
    matches.sort((a, b) => b['matchScore'].compareTo(a['matchScore']));

    return matches;
  }

  /// Calculates a match score (max 100)
  int _calculateMatchScore(Map<String, dynamic> user1, Map<String, dynamic> user2) {
    int score = 0;

    final skills1 = (user1['skills'] as List<dynamic>?) ?? [];
    final skills2 = (user2['skills'] as List<dynamic>?) ?? [];
    final commonSkills = skills1.toSet().intersection(skills2.toSet());
    score += commonSkills.length * 10;

    final interests1 = (user1['interests'] as List<dynamic>?) ?? [];
    final interests2 = (user2['interests'] as List<dynamic>?) ?? [];
    final commonInterests = interests1.toSet().intersection(interests2.toSet());
    score += commonInterests.length * 15;

    if (user1['availability'] == user2['availability']) {
      score += 20;
    }

    if (user1['personalityType'] == user2['personalityType']) {
      score += 25;
    }

    return score.clamp(0, 100);
  }

  // This would call your ML model (local or via API)
  Future<List<String>> getRecommendedPeerIds(Map<String, dynamic> userProfile) async {
    // Call your ML model here and return a list of user IDs
    // Example: return await MyMLApi.getRecommendations(userProfile);
    return [];
  }

  Future<List<String>> getRecommendedGroupIds(Map<String, dynamic> userProfile) async {
    // Call your ML model here and return a list of group IDs
    return [];
  }
}
