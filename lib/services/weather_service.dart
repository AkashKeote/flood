import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flood_data.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _apiKey = 'f215342ef6fb31829da6b26256b5d768'; // Real OpenWeather API key
  
  static final List<Map<String, dynamic>> _mumbaiCities = [
    {"name": "Andheri", "lat": 19.11227, "lon": 72.84067},
    {"name": "Bandra", "lat": 19.05039, "lon": 72.83748},
    {"name": "Worli", "lat": 19.01306, "lon": 72.82333},
    {"name": "Chembur", "lat": 19.05456, "lon": 72.89361},
    {"name": "Dadar", "lat": 19.01417, "lon": 72.84528},
    {"name": "Malad", "lat": 19.18795, "lon": 72.84226},
    {"name": "Goregaon", "lat": 19.16304, "lon": 72.84615},
    {"name": "Kandivali", "lat": 19.20361, "lon": 72.85056},
    {"name": "Borivali", "lat": 19.23246, "lon": 72.85644},
    {"name": "Dahisar", "lat": 19.24758, "lon": 72.86253},
  ];

  static Future<FloodData> getRealTimeData(String cityName) async {
    try {
      // Find city coordinates
      final city = _mumbaiCities.firstWhere(
        (city) => city['name'].toLowerCase() == cityName.toLowerCase(),
        orElse: () => _mumbaiCities[0],
      );

      // Get current weather
      final weatherUrl = '$_baseUrl/weather?lat=${city['lat']}&lon=${city['lon']}&appid=$_apiKey&units=metric';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      
      if (weatherResponse.statusCode != 200) {
        throw Exception('Failed to fetch weather data');
      }

      final weatherData = json.decode(weatherResponse.body);
      
      // Get forecast for rainfall prediction
      final forecastUrl = '$_baseUrl/forecast?lat=${city['lat']}&lon=${city['lon']}&appid=$_apiKey&units=metric';
      final forecastResponse = await http.get(Uri.parse(forecastUrl));
      
      double rainfall = 0.0;
      if (forecastResponse.statusCode == 200) {
        final forecastData = json.decode(forecastResponse.body);
        // Calculate total rainfall for next 24 hours
        for (var item in forecastData['list'].take(8)) { // 24 hours (3-hour intervals)
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
      final alerts = _generateRealAlerts(city['name'], riskLevel, rainfall, temperature);

      return FloodData(
        area: '${city['name']}, Mumbai',
        waterLevel: waterLevel,
        riskLevel: riskLevel,
        temperature: temperature,
        humidity: humidity,
        rainfall: rainfall,
        timestamp: DateTime.now(),
        alerts: alerts,
      );
    } catch (e) {
      // Fallback to mock data if API fails
      return FloodDataService.getMockData();
    }
  }

  static double _calculateWaterLevel(double rainfall, double humidity) {
    // Base water level (1.5m) + rainfall impact + humidity factor
    double baseLevel = 1.5;
    double rainfallImpact = rainfall * 0.1; // 10mm rain = 0.1m water level
    double humidityImpact = (humidity - 60) * 0.01; // High humidity increases water level
    
    return (baseLevel + rainfallImpact + humidityImpact).clamp(1.0, 5.0);
  }

  static String _calculateRiskLevel(double waterLevel, double rainfall) {
    if (waterLevel > 4.0 || rainfall > 50) return 'Critical';
    if (waterLevel > 3.0 || rainfall > 30) return 'High';
    if (waterLevel > 2.0 || rainfall > 15) return 'Moderate';
    return 'Low';
  }

  static List<FloodAlert> _generateRealAlerts(String city, String riskLevel, double rainfall, double temperature) {
    final alerts = <FloodAlert>[];
    final now = DateTime.now();

    if (riskLevel == 'Critical' || riskLevel == 'High') {
      alerts.add(FloodAlert(
        id: 'alert_${now.millisecondsSinceEpoch}',
        message: 'High flood risk detected in $city. Evacuation recommended.',
        severity: 'warning',
        timestamp: now.subtract(Duration(minutes: 5)),
        location: '$city, Mumbai',
      ));
    }

    if (rainfall > 20) {
      alerts.add(FloodAlert(
        id: 'alert_${now.millisecondsSinceEpoch + 1}',
        message: 'Heavy rainfall (${rainfall.toStringAsFixed(1)}mm) in $city. Stay indoors.',
        severity: 'info',
        timestamp: now.subtract(Duration(minutes: 10)),
        location: '$city, Mumbai',
      ));
    }

    if (temperature > 35) {
      alerts.add(FloodAlert(
        id: 'alert_${now.millisecondsSinceEpoch + 2}',
        message: 'High temperature (${temperature.toStringAsFixed(1)}°C) in $city. Stay hydrated.',
        severity: 'info',
        timestamp: now.subtract(Duration(minutes: 15)),
        location: '$city, Mumbai',
      ));
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
} 