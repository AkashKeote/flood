import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // API Keys
  static const String _openRouterApiKey = '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';
  static const String _geminiApiKey = 'AIzaSyCb4iaXNreYfK8-ZFy8nl0ZXynGW5tdsC8';
  
  // API URLs
  static const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  // OpenRouter (Grok-4) for advanced flood analysis
  static Future<Map<String, dynamic>> getGrokAnalysis({
    required Map<String, dynamic> weatherData,
    required String cityName,
    required double riskScore,
    required String riskLevel,
  }) async {
    try {
      final prompt = '''
You are an expert flood prediction AI. Analyze the following weather data for $cityName and provide detailed insights:

Weather Data:
- Temperature: ${weatherData['temperature']}°C
- Humidity: ${weatherData['humidity']}%
- Pressure: ${weatherData['pressure']} hPa
- Wind Speed: ${weatherData['windSpeed']} m/s
- Total Rainfall: ${weatherData['totalRainfall']} mm
- Rainy Hours: ${weatherData['rainyHours']} hours
- Visibility: ${(weatherData['visibility'] / 1000).toStringAsFixed(1)} km

Current Risk Assessment:
- Risk Score: $riskScore/100
- Risk Level: $riskLevel

Please provide:
1. Detailed analysis of flood risk factors
2. Specific recommendations for residents
3. Emergency preparedness advice
4. Historical pattern analysis
5. Future weather impact predictions
6. Safety measures and evacuation tips

Format your response as JSON with keys: analysis, recommendations, emergencyAdvice, safetyMeasures, historicalPatterns, futurePredictions
''';

      final response = await http.post(
        Uri.parse(_openRouterUrl),
        headers: {
          'Authorization': 'Bearer $_openRouterApiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://akashkeote.github.io/flood/',
          'X-Title': 'Flood Management System',
        },
        body: json.encode({
          'model': 'x-ai/grok-4',
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Try to parse as JSON, if not, format the text response
        try {
          return json.decode(content);
        } catch (e) {
          return {
            'analysis': content,
            'recommendations': 'Based on AI analysis',
            'emergencyAdvice': 'Follow local authorities',
            'safetyMeasures': 'Stay informed and prepared',
            'historicalPatterns': 'Analyzing weather patterns',
            'futurePredictions': 'Monitoring conditions',
          };
        }
      } else {
        throw Exception('OpenRouter API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Grok analysis error: $e');
      return _getFallbackGrokAnalysis();
    }
  }

  // Gemini AI for weather pattern analysis
  static Future<Map<String, dynamic>> getGeminiAnalysis({
    required Map<String, dynamic> weatherData,
    required String cityName,
  }) async {
    try {
      final prompt = '''
Analyze the weather patterns for $cityName and provide flood risk insights:

Weather Data:
- Temperature: ${weatherData['temperature']}°C
- Humidity: ${weatherData['humidity']}%
- Pressure: ${weatherData['pressure']} hPa
- Wind Speed: ${weatherData['windSpeed']} m/s
- Rainfall: ${weatherData['totalRainfall']} mm
- Rain Duration: ${weatherData['rainyHours']} hours

Provide a detailed analysis including:
1. Weather pattern analysis
2. Flood risk assessment
3. Safety recommendations
4. Emergency preparedness tips
5. Historical context for Mumbai floods

Format as JSON with: weatherAnalysis, floodRisk, safetyTips, emergencyPrep, historicalContext
''';

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt,
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1500,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        
        try {
          return json.decode(content);
        } catch (e) {
          return {
            'weatherAnalysis': content,
            'floodRisk': 'Moderate risk detected',
            'safetyTips': 'Stay informed and prepared',
            'emergencyPrep': 'Follow local guidelines',
            'historicalContext': 'Mumbai has experienced significant floods',
          };
        }
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini analysis error: $e');
      return _getFallbackGeminiAnalysis();
    }
  }

  // Combined AI Analysis
  static Future<Map<String, dynamic>> getCombinedAIAnalysis({
    required Map<String, dynamic> weatherData,
    required String cityName,
    required double riskScore,
    required String riskLevel,
  }) async {
    try {
      // Get analysis from both AI models
      final grokAnalysis = await getGrokAnalysis(
        weatherData: weatherData,
        cityName: cityName,
        riskScore: riskScore,
        riskLevel: riskLevel,
      );

      final geminiAnalysis = await getGeminiAnalysis(
        weatherData: weatherData,
        cityName: cityName,
      );

      return {
        'grokAnalysis': grokAnalysis,
        'geminiAnalysis': geminiAnalysis,
        'combinedInsights': _combineInsights(grokAnalysis, geminiAnalysis),
        'aiConfidence': _calculateAIConfidence(grokAnalysis, geminiAnalysis),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Combined AI analysis error: $e');
      return _getFallbackCombinedAnalysis();
    }
  }

  static Map<String, dynamic> _combineInsights(
    Map<String, dynamic> grokAnalysis,
    Map<String, dynamic> geminiAnalysis,
  ) {
    List<String> insights = [];
    
    // Combine recommendations
    if (grokAnalysis['recommendations'] != null) {
      insights.add('Grok AI: ${grokAnalysis['recommendations']}');
    }
    
    if (geminiAnalysis['safetyTips'] != null) {
      insights.add('Gemini AI: ${geminiAnalysis['safetyTips']}');
    }

    return {
      'insights': insights,
      'emergencyAdvice': grokAnalysis['emergencyAdvice'] ?? 'Stay prepared',
      'safetyMeasures': grokAnalysis['safetyMeasures'] ?? 'Follow guidelines',
    };
  }

  static int _calculateAIConfidence(
    Map<String, dynamic> grokAnalysis,
    Map<String, dynamic> geminiAnalysis,
  ) {
    // Calculate confidence based on response quality
    int confidence = 70;
    
    if (grokAnalysis['analysis'] != null && grokAnalysis['analysis'].toString().length > 100) {
      confidence += 10;
    }
    
    if (geminiAnalysis['weatherAnalysis'] != null && geminiAnalysis['weatherAnalysis'].toString().length > 100) {
      confidence += 10;
    }
    
    return confidence.clamp(60, 95);
  }

  static Map<String, dynamic> _getFallbackGrokAnalysis() {
    return {
      'analysis': 'Advanced AI analysis temporarily unavailable',
      'recommendations': 'Monitor weather conditions closely',
      'emergencyAdvice': 'Follow local emergency guidelines',
      'safetyMeasures': 'Stay informed through official channels',
      'historicalPatterns': 'Historical data analysis unavailable',
      'futurePredictions': 'Continue monitoring weather updates',
    };
  }

  static Map<String, dynamic> _getFallbackGeminiAnalysis() {
    return {
      'weatherAnalysis': 'Weather pattern analysis temporarily unavailable',
      'floodRisk': 'Moderate risk - stay prepared',
      'safetyTips': 'Follow local safety guidelines',
      'emergencyPrep': 'Keep emergency supplies ready',
      'historicalContext': 'Mumbai has experienced significant flood events',
    };
  }

  static Map<String, dynamic> _getFallbackCombinedAnalysis() {
    return {
      'grokAnalysis': _getFallbackGrokAnalysis(),
      'geminiAnalysis': _getFallbackGeminiAnalysis(),
      'combinedInsights': {
        'insights': ['AI analysis temporarily unavailable - using basic predictions'],
        'emergencyAdvice': 'Follow local emergency guidelines',
        'safetyMeasures': 'Stay informed and prepared',
      },
      'aiConfidence': 60,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
} 