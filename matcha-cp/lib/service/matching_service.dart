import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchingService {
  final String apiBaseUrl;

  MatchingService({String? apiBaseUrl}) : apiBaseUrl = apiBaseUrl ?? 'https://backend-u5oi.onrender.com';

  Future<List<Map<String, dynamic>>> getClusterMatches(String userId, {int top = 5}) async {
    final url = Uri.parse('$apiBaseUrl/cluster?userId=$userId&top=$top');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      final List<Map<String, dynamic>> detailedMatches = [];

      for (final match in data) {
        final uid = match['uid'];
        final similarity = match['similarity'];

        if (uid != null) {
          try {
            final userDetails = await getUserDetails(uid);
            detailedMatches.add({
              'uid': uid,
              'similarity': similarity,
              ...userDetails,
            });
          } catch (e) {
            print('Failed to fetch user details for $uid: $e');
          }
        }
      }

      return detailedMatches;
    } else {
      throw Exception('Failed to fetch cluster matches: ${response.body}');
    }
  }


  Future<Map<String, dynamic>> getUserDetails(String uid) async {
    final url = Uri.parse('$apiBaseUrl/user/$uid');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch user details:  [31m${response.body}');
    }
  }
}
