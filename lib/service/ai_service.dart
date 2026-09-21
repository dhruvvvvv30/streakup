import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Flask server running on your PC.
  // Your phone/emulator must be able to reach this IP.
  static const String baseUrl = 'http://192.168.1.210:5000';

  // --------------------------------------------------
  // TEST SERVER CONNECTION
  // --------------------------------------------------

  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      print('AI Server response: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('AI Server connection error: $e');
      return false;
    }
  }

  // --------------------------------------------------
  // AI MOOD EMOJI
  // --------------------------------------------------

  static Future<String?> getMood(List<String> journals) async {
    if (journals.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/mood'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'journals': journals}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final emoji = data['emoji'];

        if (emoji is String && emoji.trim().isNotEmpty) {
          return emoji.trim();
        }

        return null;
      }

      print('Mood API error: ${response.statusCode}');
      print('Mood API response: ${response.body}');

      return null;
    } catch (e) {
      print('Mood API connection error: $e');
      return null;
    }
  }

  // --------------------------------------------------
  // AI JOURNAL SUGGESTIONS
  // --------------------------------------------------

  static Future<List<String>> getSuggestions(List<String> journals) async {
    if (journals.isEmpty) {
      return [];
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/suggestions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'journals': journals}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final suggestions = data['suggestions'];

        // If the backend returns a JSON list directly.
        if (suggestions is List) {
          return suggestions
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
        }

        // Current Flask backend returns Gemini's JSON array
        // as a String, so decode it here.
        if (suggestions is String) {
          try {
            final decoded = jsonDecode(suggestions);

            if (decoded is List) {
              return decoded
                  .map((item) => item.toString())
                  .where((item) => item.trim().isNotEmpty)
                  .toList();
            }
          } catch (e) {
            print('Could not decode suggestions: $e');
          }
        }
      }

      print('Suggestions API error: ${response.statusCode}');
      print('Suggestions API response: ${response.body}');

      return [];
    } catch (e) {
      print('Suggestions API connection error: $e');
      return [];
    }
  }

  // --------------------------------------------------
  // AI TASK RECOMMENDATIONS
  // --------------------------------------------------

  static Future<List<Map<String, dynamic>>> getRecommendations({
    required String userId,
    required List<Map<String, dynamic>> userTasks,
    required List<Map<String, dynamic>> friends,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/recommendations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'user_tasks': userTasks,
              'friends': friends,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final recommendations = data['recommendations'];

        if (recommendations is List) {
          return recommendations
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }

      print('Recommendations API error: ${response.statusCode}');
      print('Recommendations API response: ${response.body}');

      return [];
    } catch (e) {
      print('Recommendations API connection error: $e');

      return [];
    }
  }
}
