import 'dart:math';

class FloodData {
  final String area;
  final double waterLevel;
  final String riskLevel;
  final double temperature;
  final double humidity;
  final double rainfall;
  final DateTime timestamp;
  final List<FloodAlert> alerts;

  FloodData({
    required this.area,
    required this.waterLevel,
    required this.riskLevel,
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.timestamp,
    required this.alerts,
  });

  factory FloodData.fromJson(Map<String, dynamic> json) {
    return FloodData(
      area: json['area'] ?? '',
      waterLevel: (json['waterLevel'] ?? 0.0).toDouble(),
      riskLevel: json['riskLevel'] ?? 'Low',
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      rainfall: (json['rainfall'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      alerts: (json['alerts'] as List? ?? []).map((e) => FloodAlert.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'area': area,
      'waterLevel': waterLevel,
      'riskLevel': riskLevel,
      'temperature': temperature,
      'humidity': humidity,
      'rainfall': rainfall,
      'timestamp': timestamp.toIso8601String(),
      'alerts': alerts.map((e) => e.toJson()).toList(),
    };
  }
}

class FloodAlert {
  final String id;
  final String message;
  final String severity;
  final DateTime timestamp;
  final String location;

  FloodAlert({
    required this.id,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.location,
  });

  factory FloodAlert.fromJson(Map<String, dynamic> json) {
    return FloodAlert(
      id: json['id'] ?? '',
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'info',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      location: json['location'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'severity': severity,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
    };
  }
}

class FloodDataService {
  static final List<String> _areas = [
    'Andheri, Mumbai',
    'Bandra, Mumbai',
    'Worli, Mumbai',
    'Chembur, Mumbai',
    'Dadar, Mumbai',
  ];

  static final List<String> _riskLevels = ['Low', 'Moderate', 'High', 'Critical'];

  static FloodData getMockData() {
    final random = Random();
    final area = _areas[random.nextInt(_areas.length)];
    final waterLevel = 1.5 + random.nextDouble() * 3.0; // 1.5m to 4.5m
    final riskLevel = _getRiskLevel(waterLevel);
    final temperature = 25.0 + random.nextDouble() * 10.0; // 25°C to 35°C
    final humidity = 60.0 + random.nextDouble() * 30.0; // 60% to 90%
    final rainfall = random.nextDouble() * 50.0; // 0mm to 50mm

    final alerts = _generateAlerts(area, riskLevel);

    return FloodData(
      area: area,
      waterLevel: waterLevel,
      riskLevel: riskLevel,
      temperature: temperature,
      humidity: humidity,
      rainfall: rainfall,
      timestamp: DateTime.now(),
      alerts: alerts,
    );
  }

  static String _getRiskLevel(double waterLevel) {
    if (waterLevel < 2.0) return 'Low';
    if (waterLevel < 3.0) return 'Moderate';
    if (waterLevel < 4.0) return 'High';
    return 'Critical';
  }

  static List<FloodAlert> _generateAlerts(String area, String riskLevel) {
    final alerts = <FloodAlert>[];
    final random = Random();

    if (riskLevel == 'High' || riskLevel == 'Critical') {
      alerts.add(FloodAlert(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        message: 'High water levels detected in $area. Evacuation recommended.',
        severity: 'warning',
        timestamp: DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
        location: area,
      ));
    }

    if (random.nextBool()) {
      alerts.add(FloodAlert(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch + 1}',
        message: 'Heavy rainfall expected in next 2 hours.',
        severity: 'info',
        timestamp: DateTime.now().subtract(Duration(minutes: random.nextInt(30))),
        location: area,
      ));
    }

    return alerts;
  }

  static List<FloodData> getHistoricalData() {
    final data = <FloodData>[];
    final random = Random();
    
    for (int i = 7; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final area = _areas[random.nextInt(_areas.length)];
      final waterLevel = 1.0 + random.nextDouble() * 4.0;
      final riskLevel = _getRiskLevel(waterLevel);
      final temperature = 24.0 + random.nextDouble() * 12.0;
      final humidity = 55.0 + random.nextDouble() * 35.0;
      final rainfall = random.nextDouble() * 60.0;

      data.add(FloodData(
        area: area,
        waterLevel: waterLevel,
        riskLevel: riskLevel,
        temperature: temperature,
        humidity: humidity,
        rainfall: rainfall,
        timestamp: date,
        alerts: _generateAlerts(area, riskLevel),
      ));
    }

    return data;
  }
} 