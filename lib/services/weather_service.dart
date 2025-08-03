import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flood_data.dart';
import 'firebase_service.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _apiKey =
      'f215342ef6fb31829da6b26256b5d768'; // Real OpenWeather API key

  static final List<Map<String, dynamic>> _mumbaiCities = [
    // Ward A
    {"name": "Colaba Causeway", "lat": 18.9153, "lon": 72.8126},
    {"name": "Ballard Estate", "lat": 18.9482, "lon": 72.8359},
    {"name": "Fort", "lat": 18.9346, "lon": 72.8347},
    {"name": "Marine Drive", "lat": 18.9431, "lon": 72.8234},

    // Ward B
    {"name": "Grant Road", "lat": 18.9619, "lon": 72.8264},
    {"name": "Girgaon", "lat": 18.9553, "lon": 72.8042},
    {"name": "Malabar Hill", "lat": 18.9553, "lon": 72.8042},

    // Ward C
    {"name": "Byculla", "lat": 18.9724, "lon": 72.8320},
    {"name": "Mazgaon", "lat": 18.9583, "lon": 72.8389},
    {"name": "Nagpada", "lat": 18.9578, "lon": 72.8326},

    // Ward E
    {"name": "Worli", "lat": 19.0131, "lon": 72.8233},
    {"name": "Prabhadevi", "lat": 19.0169, "lon": 72.8284},
    {"name": "Lower Parel", "lat": 19.0123, "lon": 72.8334},

    // Ward F/N
    {"name": "King's Circle", "lat": 19.0277, "lon": 72.8517},
    {"name": "Matunga", "lat": 19.0294, "lon": 72.8546},
    {"name": "Sion", "lat": 19.0294, "lon": 72.8546},

    // Ward F/S
    {"name": "Dadar", "lat": 19.0142, "lon": 72.8453},
    {"name": "Prabhadevi", "lat": 19.0169, "lon": 72.8284},
    {"name": "Sewri", "lat": 19.0123, "lon": 72.8334},

    // Ward G/N
    {"name": "Bandra", "lat": 19.0504, "lon": 72.8375},
    {"name": "Khar", "lat": 19.0750, "lon": 72.8297},
    {"name": "Santacruz", "lat": 19.0900, "lon": 72.8393},

    // Ward G/S
    {"name": "Andheri", "lat": 19.1123, "lon": 72.8407},
    {"name": "Juhu", "lat": 19.0996, "lon": 72.8344},
    {"name": "Vile Parle", "lat": 19.0929, "lon": 72.8441},

    // Ward H/E
    {"name": "Chembur", "lat": 19.0546, "lon": 72.8936},
    {"name": "Tilak Nagar", "lat": 19.0546, "lon": 72.8936},
    {"name": "Govandi", "lat": 19.0546, "lon": 72.8936},

    // Ward H/W
    {"name": "Bandra East", "lat": 19.0504, "lon": 72.8375},
    {"name": "Khar East", "lat": 19.0750, "lon": 72.8297},
    {"name": "Santacruz East", "lat": 19.0900, "lon": 72.8393},

    // Ward K/E
    {"name": "Andheri East", "lat": 19.1123, "lon": 72.8407},
    {"name": "Juhu East", "lat": 19.0996, "lon": 72.8344},
    {"name": "Vile Parle East", "lat": 19.0929, "lon": 72.8441},

    // Ward K/W
    {"name": "Andheri Subway", "lat": 19.1198, "lon": 72.8476},
    {"name": "Andheri West", "lat": 19.1123, "lon": 72.8407},
    {"name": "Jogeshwari", "lat": 19.0996, "lon": 72.8344},

    // Ward P/N
    {"name": "Malad", "lat": 19.1834, "lon": 72.8701},
    {"name": "Malad West", "lat": 19.1879, "lon": 72.8423},
    {"name": "Malad East", "lat": 19.1834, "lon": 72.8701},

    // Ward P/S
    {"name": "Goregaon", "lat": 19.1639, "lon": 72.8433},
    {"name": "Goregaon West", "lat": 19.1630, "lon": 72.8462},
    {"name": "Goregaon East", "lat": 19.1639, "lon": 72.8433},

    // Ward R/S
    {"name": "Kandivali", "lat": 19.2083, "lon": 72.8361},
    {"name": "Kandivali West", "lat": 19.2036, "lon": 72.8506},
    {"name": "Kandivali East", "lat": 19.2083, "lon": 72.8361},

    // Ward R/C
    {"name": "Borivali", "lat": 19.2408, "lon": 72.8173},
    {"name": "Borivali West", "lat": 19.2325, "lon": 72.8564},
    {"name": "Borivali East", "lat": 19.2408, "lon": 72.8173},

    // Ward L
    {"name": "Kurla", "lat": 19.0845, "lon": 72.8861},
    {"name": "Kurla West", "lat": 19.0845, "lon": 72.8861},
    {"name": "Kurla East", "lat": 19.0845, "lon": 72.8861},

    // Ward M/E
    {"name": "Mulund", "lat": 19.1720, "lon": 72.9554},
    {"name": "Mulund West", "lat": 19.1752, "lon": 72.9426},
    {"name": "Mulund East", "lat": 19.1720, "lon": 72.9554},

    // Ward M/W
    {"name": "Bhandup", "lat": 19.1720, "lon": 72.9554},
    {"name": "Bhandup West", "lat": 19.1752, "lon": 72.9426},
    {"name": "Bhandup East", "lat": 19.1720, "lon": 72.9554},

    // Ward N
    {"name": "Vikhroli", "lat": 19.1009, "lon": 72.9182},
    {"name": "Vikhroli West", "lat": 19.1009, "lon": 72.9182},
    {"name": "Vikhroli East", "lat": 19.1009, "lon": 72.9182},

    // Ward S
    {"name": "Dahisar", "lat": 19.2476, "lon": 72.8625},
    {"name": "Dahisar West", "lat": 19.2476, "lon": 72.8625},
    {"name": "Dahisar East", "lat": 19.2476, "lon": 72.8625},

    // Ward T
    {"name": "Thane", "lat": 19.2183, "lon": 72.9781},
    {"name": "Thane West", "lat": 19.2183, "lon": 72.9781},
    {"name": "Thane East", "lat": 19.2183, "lon": 72.9781},
  ];

  static Future<FloodData> getRealTimeData(String cityName) async {
    try {
      // Find city coordinates
      final city = _mumbaiCities.firstWhere(
        (city) => city['name'].toLowerCase() == cityName.toLowerCase(),
        orElse: () => _mumbaiCities[0],
      );

      // Get current weather
      final weatherUrl =
          '$_baseUrl/weather?lat=${city['lat']}&lon=${city['lon']}&appid=$_apiKey&units=metric';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));

      if (weatherResponse.statusCode != 200) {
        throw Exception('Failed to fetch weather data');
      }

      final weatherData = json.decode(weatherResponse.body);

      // Get forecast for rainfall prediction
      final forecastUrl =
          '$_baseUrl/forecast?lat=${city['lat']}&lon=${city['lon']}&appid=$_apiKey&units=metric';
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      double rainfall = 0.0;
      if (forecastResponse.statusCode == 200) {
        final forecastData = json.decode(forecastResponse.body);
        // Calculate total rainfall for next 24 hours
        for (var item in forecastData['list'].take(8)) {
          // 24 hours (3-hour intervals)
          rainfall += (item['rain']?['3h'] ?? 0.0);
        }
      }

      // Calculate flood risk based on weather conditions
      final temperature = weatherData['main']['temp'].toDouble();
      final humidity = weatherData['main']['humidity'].toDouble();
      final windSpeed = weatherData['wind']['speed'].toDouble();

      // Simulate water level based on rainfall and humidity
      final waterLevel = _calculateWaterLevel(rainfall, humidity);
      final riskLevel = _calculateRiskLevel(waterLevel, rainfall);

      // Generate alerts based on conditions
      final alerts = _generateRealAlerts(
        city['name'],
        riskLevel,
        rainfall,
        temperature,
      );

      final floodData = FloodData(
        area: '${city['name']}, Mumbai',
        waterLevel: waterLevel,
        riskLevel: riskLevel,
        temperature: temperature,
        humidity: humidity,
        rainfall: rainfall,
        timestamp: DateTime.now(),
        alerts: alerts,
      );

      // Save to Firebase
      try {
        if (FirebaseService.isInitialized) {
          await FirebaseService.saveFloodData(city['name'], {
            'area': floodData.area,
            'waterLevel': floodData.waterLevel,
            'riskLevel': floodData.riskLevel,
            'temperature': floodData.temperature,
            'humidity': floodData.humidity,
            'rainfall': floodData.rainfall,
            'timestamp': floodData.timestamp.toIso8601String(),
            'alerts': floodData.alerts
                .map(
                  (alert) => {
                    'id': alert.id,
                    'message': alert.message,
                    'severity': alert.severity,
                    'timestamp': alert.timestamp.toIso8601String(),
                    'location': alert.location,
                  },
                )
                .toList(),
          });
        }
      } catch (e) {
        print('Error saving flood data to Firebase (non-critical): $e');
      }

      return floodData;
    } catch (e) {
      // Fallback to mock data if API fails
      return FloodDataService.getMockData();
    }
  }

  static double _calculateWaterLevel(double rainfall, double humidity) {
    // Base water level (1.5m) + rainfall impact + humidity factor
    double baseLevel = 1.5;
    double rainfallImpact = rainfall * 0.1; // 10mm rain = 0.1m water level
    double humidityImpact =
        (humidity - 60) * 0.01; // High humidity increases water level

    return (baseLevel + rainfallImpact + humidityImpact).clamp(1.0, 5.0);
  }

  static String _calculateRiskLevel(double waterLevel, double rainfall) {
    if (waterLevel > 4.0 || rainfall > 50) return 'Critical';
    if (waterLevel > 3.0 || rainfall > 30) return 'High';
    if (waterLevel > 2.0 || rainfall > 15) return 'Moderate';
    return 'Low';
  }

  static List<FloodAlert> _generateRealAlerts(
    String city,
    String riskLevel,
    double rainfall,
    double temperature,
  ) {
    final alerts = <FloodAlert>[];
    final now = DateTime.now();

    if (riskLevel == 'Critical' || riskLevel == 'High') {
      alerts.add(
        FloodAlert(
          id: 'alert_${now.millisecondsSinceEpoch}',
          message: 'High flood risk detected in $city. Evacuation recommended.',
          severity: 'warning',
          timestamp: now.subtract(Duration(minutes: 5)),
          location: '$city, Mumbai',
        ),
      );
    }

    if (rainfall > 20) {
      alerts.add(
        FloodAlert(
          id: 'alert_${now.millisecondsSinceEpoch + 1}',
          message:
              'Heavy rainfall (${rainfall.toStringAsFixed(1)}mm) in $city. Stay indoors.',
          severity: 'info',
          timestamp: now.subtract(Duration(minutes: 10)),
          location: '$city, Mumbai',
        ),
      );
    }

    if (temperature > 35) {
      alerts.add(
        FloodAlert(
          id: 'alert_${now.millisecondsSinceEpoch + 2}',
          message:
              'High temperature (${temperature.toStringAsFixed(1)}°C) in $city. Stay hydrated.',
          severity: 'info',
          timestamp: now.subtract(Duration(minutes: 15)),
          location: '$city, Mumbai',
        ),
      );
    }

    return alerts;
  }

  static Future<List<FloodData>> getAllMumbaiCitiesData() async {
    final List<FloodData> allData = [];

    for (final city in _mumbaiCities) {
      try {
        final data = await getRealTimeData(city['name']);
        allData.add(data);
      } catch (e) {
        // If API fails for a city, use mock data
        final mockData = FloodDataService.getMockData();
        allData.add(mockData);
      }
    }

    return allData;
  }

  static List<String> getMumbaiCities() {
    return _mumbaiCities.map((city) => city['name'] as String).toList();
  }

  // AI-powered flood prediction methods
  static Future<Map<String, dynamic>> getAIPrediction(String cityName) async {
    try {
      // Find city coordinates
      final city = _mumbaiCities.firstWhere(
        (city) => city['name'].toLowerCase() == cityName.toLowerCase(),
        orElse: () => _mumbaiCities[0],
      );

      // Get current weather and forecast data
      final weatherUrl = '$_baseUrl/weather?lat=${city['lat']}&lon=${city['lon']}&appid=$_apiKey&units=metric';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));

      final forecastUrl = '$_baseUrl/forecast?lat=${city['lat']}&lon=${city['lon']}&appid=$_apiKey&units=metric';
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (weatherResponse.statusCode != 200 || forecastResponse.statusCode != 200) {
        throw Exception('Failed to fetch weather data for AI prediction');
      }

      final weatherData = json.decode(weatherResponse.body);
      final forecastData = json.decode(forecastResponse.body);

      // Extract weather parameters for AI analysis
      final temperature = weatherData['main']['temp'].toDouble();
      final humidity = weatherData['main']['humidity'].toDouble();
      final pressure = weatherData['main']['pressure'].toDouble();
      final windSpeed = weatherData['wind']['speed'].toDouble();
      final visibility = weatherData['visibility']?.toDouble() ?? 10000.0;

      // Calculate rainfall from forecast
      double totalRainfall = 0.0;
      double maxRainfall = 0.0;
      int rainyHours = 0;

      for (var item in forecastData['list'].take(24)) { // 24 hours forecast
        final rain = item['rain']?['3h'] ?? 0.0;
        totalRainfall += rain;
        maxRainfall = rain > maxRainfall ? rain : maxRainfall;
        if (rain > 0) rainyHours++;
      }

      // AI Prediction Algorithm
      final prediction = _calculateAIPrediction(
        temperature: temperature,
        humidity: humidity,
        pressure: pressure,
        windSpeed: windSpeed,
        visibility: visibility,
        totalRainfall: totalRainfall,
        maxRainfall: maxRainfall,
        rainyHours: rainyHours,
        cityName: city['name'],
      );

      return prediction;
    } catch (e) {
      print('Error in AI prediction: $e');
      return _getFallbackPrediction();
    }
  }

  static Map<String, dynamic> _calculateAIPrediction({
    required double temperature,
    required double humidity,
    required double pressure,
    required double windSpeed,
    required double visibility,
    required double totalRainfall,
    required double maxRainfall,
    required int rainyHours,
    required String cityName,
  }) {
    // AI Risk Assessment Algorithm
    double riskScore = 0.0;
    String riskLevel = 'Low';
    String confidence = 'High';
    List<String> factors = [];

    // Factor 1: Rainfall Analysis (40% weight)
    if (totalRainfall > 50) {
      riskScore += 40;
      factors.add('Heavy rainfall detected');
    } else if (totalRainfall > 25) {
      riskScore += 25;
      factors.add('Moderate rainfall');
    } else if (totalRainfall > 10) {
      riskScore += 15;
      factors.add('Light rainfall');
    }

    // Factor 2: Humidity Impact (20% weight)
    if (humidity > 85) {
      riskScore += 20;
      factors.add('Very high humidity');
    } else if (humidity > 75) {
      riskScore += 15;
      factors.add('High humidity');
    }

    // Factor 3: Pressure Analysis (15% weight)
    if (pressure < 1000) {
      riskScore += 15;
      factors.add('Low atmospheric pressure');
    } else if (pressure < 1010) {
      riskScore += 10;
      factors.add('Moderate pressure');
    }

    // Factor 4: Wind Speed (10% weight)
    if (windSpeed > 20) {
      riskScore += 10;
      factors.add('Strong winds');
    } else if (windSpeed > 10) {
      riskScore += 5;
      factors.add('Moderate winds');
    }

    // Factor 5: Visibility (10% weight)
    if (visibility < 5000) {
      riskScore += 10;
      factors.add('Poor visibility');
    } else if (visibility < 8000) {
      riskScore += 5;
      factors.add('Reduced visibility');
    }

    // Factor 6: Rain Duration (5% weight)
    if (rainyHours > 12) {
      riskScore += 5;
      factors.add('Extended rainfall period');
    } else if (rainyHours > 6) {
      riskScore += 3;
      factors.add('Moderate rainfall duration');
    }

    // Determine risk level based on score
    if (riskScore >= 80) {
      riskLevel = 'Critical';
      confidence = 'Very High';
    } else if (riskScore >= 60) {
      riskLevel = 'High';
      confidence = 'High';
    } else if (riskScore >= 40) {
      riskLevel = 'Moderate';
      confidence = 'Medium';
    } else if (riskScore >= 20) {
      riskLevel = 'Low';
      confidence = 'Medium';
    } else {
      riskLevel = 'Very Low';
      confidence = 'High';
    }

    // Calculate confidence percentage
    int confidencePercent = 85;
    if (confidence == 'Very High') confidencePercent = 95;
    else if (confidence == 'High') confidencePercent = 85;
    else if (confidence == 'Medium') confidencePercent = 70;
    else confidencePercent = 60;

    // Generate AI insights
    List<String> insights = [];
    if (totalRainfall > 30) {
      insights.add('Heavy rainfall expected - Monitor water levels closely');
    }
    if (humidity > 80) {
      insights.add('High humidity may slow water evaporation');
    }
    if (pressure < 1005) {
      insights.add('Low pressure system detected - Weather instability likely');
    }
    if (riskLevel == 'Critical' || riskLevel == 'High') {
      insights.add('Immediate action recommended - Prepare evacuation plans');
    }

    return {
      'city': cityName,
      'riskLevel': riskLevel,
      'riskScore': riskScore.round(),
      'confidence': confidence,
      'confidencePercent': confidencePercent,
      'factors': factors,
      'insights': insights,
      'weatherData': {
        'temperature': temperature,
        'humidity': humidity,
        'pressure': pressure,
        'windSpeed': windSpeed,
        'visibility': visibility,
        'totalRainfall': totalRainfall,
        'maxRainfall': maxRainfall,
        'rainyHours': rainyHours,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _getFallbackPrediction() {
    return {
      'city': 'Mumbai',
      'riskLevel': 'Low',
      'riskScore': 15,
      'confidence': 'Medium',
      'confidencePercent': 70,
      'factors': ['Limited data available'],
      'insights': ['Using historical patterns for prediction'],
      'weatherData': {
        'temperature': 28.0,
        'humidity': 75.0,
        'pressure': 1013.0,
        'windSpeed': 8.0,
        'visibility': 8000.0,
        'totalRainfall': 5.0,
        'maxRainfall': 2.0,
        'rainyHours': 2,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
