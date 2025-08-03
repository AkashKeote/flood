import 'dart:convert';
import 'package:http/http.dart' as http;

class TwitterService {
  // Twitter API Keys
  static const String _apiKey = '9Jshl8MlhVhkmGNgh950lGSiP';
  static const String _apiKeySecret = 'xjBtqyXFpYZGpNzYVOAFPATYAZXCVw7iby0SST6C9lnWhcKbVb';
  static const String _accessToken = '1945124378473312256-bm3qpILCEfMs6SLB0yN2hXasDTvF0C';
  static const String _accessTokenSecret = '4Y5N7KYg77itwRqGZZW6EgYYbSBFG1eHHwDD2cTiBdnFt';
  static const String _bearerToken = 'AAAAAAAAAAAAAAAAAAAAADRN3AEAAAAAS5bsqT5yGeH1LGbS4BRbU5ctzO8%3D3JxJCqTJ6ofNekABlzW7cC9Z3AYnidQYkj1syhMQw6v5Dc64RL';

  // Twitter API URLs
  static const String _baseUrl = 'https://api.twitter.com/2';
  static const String _tweetsUrl = '$_baseUrl/tweets';

  // Share flood alert on Twitter
  static Future<Map<String, dynamic>> shareFloodAlert({
    required String cityName,
    required String riskLevel,
    required String riskScore,
    required Map<String, dynamic> weatherData,
    required List<String> insights,
  }) async {
    try {
      // Create tweet content
      final tweetContent = _createFloodAlertTweet(
        cityName: cityName,
        riskLevel: riskLevel,
        riskScore: riskScore,
        weatherData: weatherData,
        insights: insights,
      );

      // Post tweet
      final response = await http.post(
        Uri.parse(_tweetsUrl),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': tweetContent,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'tweetId': data['data']['id'],
          'tweetUrl': 'https://twitter.com/user/status/${data['data']['id']}',
          'message': 'Flood alert shared successfully on Twitter',
        };
      } else {
        throw Exception('Twitter API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Twitter share error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to share on Twitter',
      };
    }
  }

  // Share emergency alert
  static Future<Map<String, dynamic>> shareEmergencyAlert({
    required String cityName,
    required String emergencyType,
    required String message,
  }) async {
    try {
      final tweetContent = '''
🚨 EMERGENCY ALERT 🚨
Location: $cityName
Type: $emergencyType
Message: $message

#FloodAlert #Emergency #Mumbai #StaySafe
''';

      final response = await http.post(
        Uri.parse(_tweetsUrl),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': tweetContent,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'tweetId': data['data']['id'],
          'tweetUrl': 'https://twitter.com/user/status/${data['data']['id']}',
          'message': 'Emergency alert shared on Twitter',
        };
      } else {
        throw Exception('Twitter API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Emergency Twitter share error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to share emergency alert',
      };
    }
  }

  // Share weather update
  static Future<Map<String, dynamic>> shareWeatherUpdate({
    required String cityName,
    required Map<String, dynamic> weatherData,
  }) async {
    try {
      final tweetContent = '''
🌧️ Weather Update - $cityName
Temperature: ${weatherData['temperature']}°C
Humidity: ${weatherData['humidity']}%
Rainfall: ${weatherData['totalRainfall']}mm
Wind: ${weatherData['windSpeed']} m/s

#WeatherUpdate #Mumbai #FloodManagement
''';

      final response = await http.post(
        Uri.parse(_tweetsUrl),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': tweetContent,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'tweetId': data['data']['id'],
          'tweetUrl': 'https://twitter.com/user/status/${data['data']['id']}',
          'message': 'Weather update shared on Twitter',
        };
      } else {
        throw Exception('Twitter API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Weather Twitter share error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to share weather update',
      };
    }
  }

  // Create flood alert tweet content
  static String _createFloodAlertTweet({
    required String cityName,
    required String riskLevel,
    required String riskScore,
    required Map<String, dynamic> weatherData,
    required List<String> insights,
  }) {
    String emoji = '🟢';
    if (riskLevel.toLowerCase() == 'critical') emoji = '🔴';
    else if (riskLevel.toLowerCase() == 'high') emoji = '🟠';
    else if (riskLevel.toLowerCase() == 'moderate') emoji = '🟡';

    final tweet = '''
$emoji Flood Alert - $cityName
Risk Level: $riskLevel ($riskScore/100)
Temperature: ${weatherData['temperature']}°C
Rainfall: ${weatherData['totalRainfall']}mm
Humidity: ${weatherData['humidity']}%

${insights.take(2).join('\n')}

#FloodAlert #Mumbai #StaySafe #FloodManagement
''';

    return tweet;
  }

  // Get trending flood-related hashtags
  static Future<List<String>> getTrendingHashtags() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tweets/search/recent?query=flood%20mumbai&max_results=10'),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> hashtags = [];
        
        if (data['data'] != null) {
          for (var tweet in data['data']) {
            final text = tweet['text'] as String;
            final matches = RegExp(r'#\w+').allMatches(text);
            hashtags.addAll(matches.map((m) => m.group(0)!));
          }
        }
        
        return hashtags.take(5).toList();
      } else {
        return ['#FloodAlert', '#Mumbai', '#StaySafe', '#Emergency', '#Weather'];
      }
    } catch (e) {
      print('Error getting trending hashtags: $e');
      return ['#FloodAlert', '#Mumbai', '#StaySafe', '#Emergency', '#Weather'];
    }
  }

  // Share AI prediction results
  static Future<Map<String, dynamic>> shareAIPrediction({
    required String cityName,
    required String riskLevel,
    required int aiConfidence,
    required Map<String, dynamic> grokAnalysis,
    required Map<String, dynamic> geminiAnalysis,
  }) async {
    try {
      final tweetContent = '''
🤖 AI Flood Prediction - $cityName
Risk Level: $riskLevel
AI Confidence: ${aiConfidence}%

Grok-4 Analysis: ${grokAnalysis['recommendations'] ?? 'Analysis available'}
Gemini Analysis: ${geminiAnalysis['safetyTips'] ?? 'Safety tips available'}

#AIPrediction #FloodAlert #Mumbai #AI
''';

      final response = await http.post(
        Uri.parse(_tweetsUrl),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': tweetContent,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'tweetId': data['data']['id'],
          'tweetUrl': 'https://twitter.com/user/status/${data['data']['id']}',
          'message': 'AI prediction shared on Twitter',
        };
      } else {
        throw Exception('Twitter API error: ${response.statusCode}');
      }
    } catch (e) {
      print('AI prediction Twitter share error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to share AI prediction',
      };
    }
  }
} 