// OpenStreetMap API Service
// Fetches real-time road network data from OSM Overpass API

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSMService {
  // Overpass API endpoint for querying OpenStreetMap data
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  
  // Cache for road data to avoid repeated API calls
  static final Map<String, List<OSMRoad>> _roadCache = {};
  
  /// Fetch roads for Mumbai area using Overpass API
  static Future<List<OSMRoad>> fetchMumbaiRoads({
    double southLat = 18.8,
    double westLon = 72.7,
    double northLat = 19.3,
    double eastLon = 73.1,
  }) async {
    
    String cacheKey = "${southLat}_${westLon}_${northLat}_$eastLon";
    if (_roadCache.containsKey(cacheKey)) {
      print('🗂️ Using cached road data for Mumbai');
      return _roadCache[cacheKey]!;
    }
    
    try {
      print('🌐 Fetching Mumbai roads from OpenStreetMap API...');
      
      // Overpass QL query for major roads in Mumbai
      String query = '''
        [out:json][timeout:30];
        (
          way["highway"~"^(primary|secondary|tertiary|trunk|motorway)"][bbox:$southLat,$westLon,$northLat,$eastLon];
        );
        out geom;
      ''';
      
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=$query',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<OSMRoad> roads = [];
        
        if (data['elements'] != null) {
          for (var element in data['elements']) {
            if (element['type'] == 'way' && element['geometry'] != null) {
              roads.add(OSMRoad.fromOverpassData(element));
            }
          }
        }
        
        // Cache the results
        _roadCache[cacheKey] = roads;
        
        print('✅ Fetched ${roads.length} roads from OpenStreetMap');
        return roads;
        
      } else {
        print('❌ Failed to fetch roads: ${response.statusCode}');
        return [];
      }
      
    } catch (e) {
      print('❌ Error fetching roads from OSM: $e');
      return [];
    }
  }
  
  /// Fetch specific area roads with risk assessment
  static Future<List<OSMRoad>> fetchAreaRoads(String areaName, LatLng center, {double radiusKm = 5.0}) async {
    // Calculate bounding box around the area
    double latDelta = radiusKm / 111.32; // rough conversion km to degrees
    double lonDelta = radiusKm / (111.32 * cos(center.latitude * pi / 180));
    
    return await fetchMumbaiRoads(
      southLat: center.latitude - latDelta,
      westLon: center.longitude - lonDelta,
      northLat: center.latitude + latDelta,
      eastLon: center.longitude + lonDelta,
    );
  }
  
  /// Simulate risk assessment based on area and road type
  static int assessRoadRisk(String? areaName, String roadType, LatLng position) {
    // High risk areas (simulated based on Mumbai flood-prone areas)
    List<String> highRiskAreas = [
      'sion', 'kurla', 'chembur', 'ghatkopar', 'mulund', 'bhandup',
      'vikhroli', 'powai', 'andheri', 'malad', 'kandivali', 'borivali'
    ];
    
    List<String> moderateRiskAreas = [
      'dadar', 'mahim', 'bandra', 'santacruz', 'vile parle', 'jogeshwari',
      'goregaon', 'thane', 'navi mumbai'
    ];
    
    // Check if area is in high risk zone
    if (areaName != null) {
      String lowerArea = areaName.toLowerCase();
      if (highRiskAreas.any((area) => lowerArea.contains(area))) {
        return 2; // High risk
      }
      if (moderateRiskAreas.any((area) => lowerArea.contains(area))) {
        return 1; // Moderate risk
      }
    }
    
    // Risk also depends on road type and elevation (simulated)
    if (roadType.contains('motorway') || roadType.contains('trunk')) {
      return 0; // Major roads usually safer (elevated)
    }
    
    // Default to low risk for other areas
    return 0; // Low risk
  }
}

class OSMRoad {
  final String id;
  final List<LatLng> coordinates;
  final String roadType;
  final String? name;
  final int riskLevel;
  
  OSMRoad({
    required this.id,
    required this.coordinates,
    required this.roadType,
    this.name,
    required this.riskLevel,
  });
  
  factory OSMRoad.fromOverpassData(Map<String, dynamic> data) {
    List<LatLng> coords = [];
    
    if (data['geometry'] != null) {
      for (var point in data['geometry']) {
        coords.add(LatLng(point['lat'].toDouble(), point['lon'].toDouble()));
      }
    }
    
    String roadType = data['tags']?['highway'] ?? 'unknown';
    String? roadName = data['tags']?['name'];
    String? areaName = data['tags']?['addr:city'] ?? data['tags']?['place'];
    
    // Calculate center point for risk assessment
    LatLng center = coords.isNotEmpty 
        ? LatLng(
            coords.map((c) => c.latitude).reduce((a, b) => a + b) / coords.length,
            coords.map((c) => c.longitude).reduce((a, b) => a + b) / coords.length,
          )
        : LatLng(19.0760, 72.8777);
    
    int risk = OSMService.assessRoadRisk(areaName, roadType, center);
    
    return OSMRoad(
      id: data['id']?.toString() ?? '',
      coordinates: coords,
      roadType: roadType,
      name: roadName,
      riskLevel: risk,
    );
  }
}
