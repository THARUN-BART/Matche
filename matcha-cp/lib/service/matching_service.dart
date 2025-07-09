import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchingService {
  final String apiBaseUrl;

  MatchingService({required this.apiBaseUrl});

  // Get cluster matches: returns a list of maps with uid and similarity
  Future<List<Map<String, dynamic>>> getClusterMatches(String userId, {int top = 5}) async {
    final url = Uri.parse('$apiBaseUrl/cluster?userId=$userId&top=$top');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch cluster matches:  [31m${response.body}');
    }
  }

  // Fetch user details by UID
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
