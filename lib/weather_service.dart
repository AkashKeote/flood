import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1';

  // Fetch 7-day weather forecast for a location
  static Future<Map<String, dynamic>> getWeatherForecast({
    required double latitude,
    required double longitude,
  }) async {
    print('🌦️ Fetching weather for lat: $latitude, lon: $longitude');
    
    try {
      final uri = Uri.parse('$_baseUrl/forecast').replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'daily': 'precipitation_sum,precipitation_hours,temperature_2m_max,temperature_2m_min,wind_speed_10m_max',
        'hourly': 'precipitation,relative_humidity_2m,wind_speed_10m',
        'forecast_days': '7',
        'timezone': 'auto',
      });

      print('🌐 Weather API URL: $uri');

      final response = await http.get(uri).timeout(Duration(seconds: 15));
      
      print('📡 Weather API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Process the weather data for flood risk analysis
        final processedData = _processWeatherData(data);
        
        print('✅ Weather data processed successfully');
        return {
          'success': true,
          'data': processedData,
        };
      } else {
        print('❌ Weather API Error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Weather service unavailable (${response.statusCode})',
        };
      }
    } catch (e) {
      print('❌ Weather Service Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Process raw weather data into flood-relevant metrics
  static Map<String, dynamic> _processWeatherData(Map<String, dynamic> rawData) {
    try {
      final daily = rawData['daily'];
      
      List<Map<String, dynamic>> dailyForecasts = [];
      
      // Process daily data
      for (int i = 0; i < 7; i++) {
        final date = daily['time'][i];
        final precipitationSum = daily['precipitation_sum'][i]?.toDouble() ?? 0.0;
        final precipitationHours = daily['precipitation_hours'][i]?.toDouble() ?? 0.0;
        final tempMax = daily['temperature_2m_max'][i]?.toDouble() ?? 25.0;
        final tempMin = daily['temperature_2m_min'][i]?.toDouble() ?? 20.0;
        final windMax = daily['wind_speed_10m_max'][i]?.toDouble() ?? 0.0;
        
        // Calculate rainfall intensity (mm/hr)
        double rainfallIntensity = 0.0;
        if (precipitationHours > 0) {
          rainfallIntensity = precipitationSum / precipitationHours;
        }
        
        // Calculate flood risk factors
        double rainfallRisk = _calculateRainfallRisk(precipitationSum, rainfallIntensity);
        
        dailyForecasts.add({
          'date': date,
          'precipitation_mm': precipitationSum,
          'precipitation_hours': precipitationHours,
          'rainfall_intensity': rainfallIntensity,
          'rainfall_risk_factor': rainfallRisk,
          'temperature_max': tempMax,
          'temperature_min': tempMin,
          'wind_speed_max': windMax,
          'rainfall_day_flag': precipitationSum > 0 ? 1 : 0,
        });
      }
      
      // Calculate 7-day metrics
      double totalRainfall = dailyForecasts.fold(0.0, (sum, day) => sum + day['precipitation_mm']);
      double maxIntensity = dailyForecasts.fold(0.0, (max, day) => 
        day['rainfall_intensity'] > max ? day['rainfall_intensity'] : max);
      int rainyDays = dailyForecasts.where((day) => day['rainfall_day_flag'] == 1).length;
      
      return {
        'daily_forecasts': dailyForecasts,
        'summary': {
          'total_rainfall_7days': totalRainfall,
          'max_intensity': maxIntensity,
          'rainy_days_count': rainyDays,
          'average_daily_rainfall': totalRainfall / 7,
        },
      };
    } catch (e) {
      print('❌ Weather data processing error: $e');
      return {
        'daily_forecasts': [],
        'summary': {
          'total_rainfall_7days': 0.0,
          'max_intensity': 0.0,
          'rainy_days_count': 0,
          'average_daily_rainfall': 0.0,
        },
      };
    }
  }

  // Calculate rainfall risk factor (0.0 to 1.0)
  static double _calculateRainfallRisk(double precipitation, double intensity) {
    double risk = 0.0;
    
    // Precipitation amount risk
    if (precipitation > 100) risk += 0.4;      // Very heavy rain
    else if (precipitation > 50) risk += 0.3;  // Heavy rain
    else if (precipitation > 25) risk += 0.2;  // Moderate rain
    else if (precipitation > 10) risk += 0.1;  // Light rain
    
    // Intensity risk
    if (intensity > 20) risk += 0.4;          // Very intense
    else if (intensity > 10) risk += 0.3;     // High intensity
    else if (intensity > 5) risk += 0.2;      // Moderate intensity
    else if (intensity > 2) risk += 0.1;      // Low intensity
    
    return risk > 1.0 ? 1.0 : risk;
  }

  // Get current weather conditions
  static Future<Map<String, dynamic>> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/forecast').replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,precipitation,relative_humidity_2m,wind_speed_10m',
        'timezone': 'auto',
      });

      final response = await http.get(uri).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        
        return {
          'success': true,
          'data': {
            'temperature': current['temperature_2m']?.toDouble() ?? 25.0,
            'precipitation': current['precipitation']?.toDouble() ?? 0.0,
            'humidity': current['relative_humidity_2m']?.toDouble() ?? 60.0,
            'wind_speed': current['wind_speed_10m']?.toDouble() ?? 0.0,
            'timestamp': current['time'],
          },
        };
      } else {
        return {
          'success': false,
          'error': 'Current weather unavailable',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
