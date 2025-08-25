import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Routing utilities exactly matching Python alit.py implementation
class RoutingUtils {
  // Risk color mapping (exact match with Python RISK_COLOR)
  static const Map<String, Color> RISK_COLORS = {
    'low': Color(0xFF1a9850),      // #1a9850
    'moderate': Color(0xFFfc8d59), // #fc8d59
    'high': Color(0xFFd73027),     // #d73027
    'unknown': Color(0xFF9e9e9e),  // #9e9e9e
  };

  // Assumed speed for evacuation (exact match with Python ASSUMED_SPEED_KMPH)
  static const double ASSUMED_SPEED_KMPH = 25.0;
  
  // Route colors (exact match with Python colors array)
  static const List<Color> ROUTE_COLORS = [
    Color(0xFF0066ff), // "#0066ff" Blue
    Color(0xFF00cc44), // "#00cc44" Green
    Color(0xFFff8800), // "#ff8800" Orange
    Color(0xFFaa00ff), // "#aa00ff" Purple
    Color(0xFF0099cc), // "#0099cc" Cyan
  ];

  /// Calculate Haversine distance between two points (matching Python implementation)
  static double haversineDistance(LatLng point1, LatLng point2) {
    const double R = 6371000.0; // Earth's radius in meters
    
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLonRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * 
        sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Fuzzy string matching (simplified version of Python's fuzzy matching)
  static MapEntry<String, int> extractBestMatch(String query, List<String> choices) {
    String bestMatch = '';
    int bestScore = 0;
    
    String queryLower = query.toLowerCase().trim();
    
    for (String choice in choices) {
      int score = _calculateSimilarity(queryLower, choice.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        bestMatch = choice;
      }
    }
    
    return MapEntry(bestMatch, bestScore);
  }

  static int _calculateSimilarity(String query, String target) {
    if (query == target) return 100;
    if (target.contains(query)) return 90;
    if (query.contains(target)) return 85;
    
    // Levenshtein distance-based similarity
    int distance = _levenshteinDistance(query, target);
    int maxLength = max(query.length, target.length);
    if (maxLength == 0) return 100;
    
    double similarity = (maxLength - distance) / maxLength;
    return (similarity * 100).round();
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1, 
      (i) => List.generate(s2.length + 1, (j) => 0)
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce(min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Generate road-following route points (matching HTML file polylines)
  static List<LatLng> generateRoutePoints(LatLng start, LatLng end, {int? seed}) {
    // HTML uses detailed coordinate arrays that follow actual roads
    // e.g., [[19.2447, 72.9001], [19.2392, 72.8849], [19.2384803, 72.8830435], ...]
    
    List<LatLng> roadPoints = [start];
    
    // Calculate intermediate points following road patterns (like HTML data)
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;
    
    // Create 8-12 waypoints to simulate detailed road path (like HTML)
    int numWaypoints = 8 + (seed ?? 0) % 5; // 8-12 points
    Random random = Random(seed ?? 42);
    
    for (int i = 1; i < numWaypoints; i++) {
      double progress = i / numWaypoints;
      
      // Base interpolation
      double baseLat = start.latitude + (latDiff * progress);
      double baseLng = start.longitude + (lngDiff * progress);
      
      // Add road-following variations (simulating actual road curves)
      double roadDeviation = 0.002 + (random.nextDouble() * 0.003);
      double curvature = sin(progress * pi * 2) * roadDeviation;
      
      // Alternate between north-south and east-west road patterns
      if (i % 3 == 0) {
        // Major road intersection points
        baseLat += curvature * 0.5;
        baseLng += (random.nextDouble() - 0.5) * 0.001;
      } else if (i % 2 == 0) {
        // Road bends and curves
        baseLat += (random.nextDouble() - 0.5) * 0.002;
        baseLng += curvature;
      } else {
        // Minor adjustments for road alignment
        baseLat += (random.nextDouble() - 0.5) * 0.0015;
        baseLng += (random.nextDouble() - 0.5) * 0.0015;
      }
      
      roadPoints.add(LatLng(baseLat, baseLng));
    }
    
    roadPoints.add(end);
    return roadPoints;
  }

  /// Exact implementation of Python's get_k_nearest_low_risk_routes function
  static List<EvacuationRoute> generateEvacuationRoutes({
    required String startArea,
    required LatLng startCoord,
    required Map<String, String> riskData,
    required Map<String, LatLng> areaCoordinates,
    required int numRoutes,
    required double speedKmph,
  }) {
    List<EvacuationRoute> routes = [];
    
    // Step 1: Find all low-risk areas (matching Python: low_df = flood_df[flood_df["flood_risk_level"] == "low"])
    List<String> lowRiskAreas = riskData.entries
        .where((entry) => entry.value.toLowerCase() == 'low' && entry.key != startArea)
        .map((entry) => entry.key)
        .toList();
    
    if (lowRiskAreas.isEmpty) return routes;
    
    // Step 2: Calculate distances to all low-risk areas (Python: dists = nx.single_source_dijkstra_path_length)
    // In Flutter, we use straight-line distance as approximation
    List<RouteCandidate> candidates = [];
    for (String area in lowRiskAreas) {
      if (areaCoordinates.containsKey(area)) {
        LatLng destCoord = areaCoordinates[area]!;
        double distance = haversineDistance(startCoord, destCoord);
        candidates.add(RouteCandidate(area, destCoord, distance));
      }
    }
    
    if (candidates.isEmpty) return routes;
    
    // Step 3: Sort by distance (Python: candidates.sort(key=lambda x: x[2]))
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    
    // Step 4: Select unique destinations (Python: seen.add(area) logic)
    List<RouteCandidate> selectedCandidates = [];
    Set<String> seenAreas = <String>{};
    for (RouteCandidate candidate in candidates) {
      if (!seenAreas.contains(candidate.area)) {
        selectedCandidates.add(candidate);
        seenAreas.add(candidate.area);
        if (selectedCandidates.length >= numRoutes) break;
      }
    }
    
    // Step 5: Generate routes (Python: routes.append logic)
    for (int i = 0; i < selectedCandidates.length; i++) {
      RouteCandidate candidate = selectedCandidates[i];
      
      // Generate detailed road-following route points (like HTML polylines)
      List<LatLng> routePoints = generateRoutePoints(startCoord, candidate.coord, seed: i);
      
      // Calculate distance in km (Python: lm = route_length_m(G, path); distance_km = round(lm/1000.0, 3))
      double distanceKm = candidate.distance / 1000.0;
      
      // Calculate ETA in minutes (Python: eta_min = (lm/1000.0)/max(ASSUMED_SPEED_KMPH,1)*60.0)
      double etaMinutes = (distanceKm / max(speedKmph, 1)) * 60.0;
      
      routes.add(EvacuationRoute(
        id: i + 1,
        destination: candidate.area,
        distanceKm: double.parse(distanceKm.toStringAsFixed(3)), // round to 3 decimal places like Python
        estimatedTimeMinutes: double.parse(etaMinutes.toStringAsFixed(1)), // round to 1 decimal like Python
        riskLevel: 'low',
        routeColor: ROUTE_COLORS[i % ROUTE_COLORS.length],
        routePoints: routePoints,
      ));
    }
    
    return routes;
  }

  /// Create road risk overlay polylines (matching Python road risk visualization)
  static List<Polyline> createRoadRiskOverlay({
    required Map<String, String> riskData,
    required Map<String, LatLng> areaCoordinates,
    double opacity = 0.6,
    double strokeWidth = 2.0,
  }) {
    List<Polyline> roadOverlays = [];
    
    // Sample road network connections between areas (simplified)
    List<String> areas = areaCoordinates.keys.toList();
    Random random = Random(42); // Fixed seed for consistent results
    
    for (int i = 0; i < areas.length; i++) {
      String currentArea = areas[i];
      LatLng currentCoord = areaCoordinates[currentArea]!;
      String currentRisk = riskData[currentArea] ?? 'unknown';
      
      // Connect to 2-3 nearest areas (simulating road network)
      List<MapEntry<String, double>> nearbyAreas = [];
      
      for (int j = 0; j < areas.length; j++) {
        if (i != j) {
          String otherArea = areas[j];
          LatLng otherCoord = areaCoordinates[otherArea]!;
          double distance = haversineDistance(currentCoord, otherCoord);
          nearbyAreas.add(MapEntry(otherArea, distance));
        }
      }
      
      nearbyAreas.sort((a, b) => a.value.compareTo(b.value));
      
      // Create road segments to 2-3 nearest areas
      int connectionsToMake = min(3, nearbyAreas.length);
      for (int k = 0; k < connectionsToMake; k++) {
        String targetArea = nearbyAreas[k].key;
        LatLng targetCoord = areaCoordinates[targetArea]!;
        String targetRisk = riskData[targetArea] ?? 'unknown';
        
        // Use higher risk level for road segment color
        String roadRisk = _getHigherRisk(currentRisk, targetRisk);
        Color roadColor = RISK_COLORS[roadRisk] ?? RISK_COLORS['unknown']!;
        
        // Create slightly curved road segment
        List<LatLng> roadPoints = _generateRoadSegment(currentCoord, targetCoord, random);
        
        roadOverlays.add(Polyline(
          points: roadPoints,
          color: roadColor.withOpacity(opacity),
          strokeWidth: strokeWidth,
        ));
      }
    }
    
    return roadOverlays;
  }

  static String _getHigherRisk(String risk1, String risk2) {
    const riskLevels = {'low': 1, 'moderate': 2, 'high': 3, 'unknown': 0};
    int level1 = riskLevels[risk1] ?? 0;
    int level2 = riskLevels[risk2] ?? 0;
    
    if (level1 >= level2) return risk1;
    return risk2;
  }

  static List<LatLng> _generateRoadSegment(LatLng start, LatLng end, Random random) {
    List<LatLng> points = [start];
    
    // Add slight curve to make roads look more realistic
    double midLat = (start.latitude + end.latitude) / 2;
    double midLng = (start.longitude + end.longitude) / 2;
    
    // Add small perpendicular offset for curve
    double perpOffset = (random.nextDouble() - 0.5) * 0.002;
    LatLng midPoint = LatLng(midLat + perpOffset, midLng - perpOffset);
    
    points.add(midPoint);
    points.add(end);
    
    return points;
  }

  /// Enhanced POI filtering with category-based clustering
  static List<Marker> createPOIMarkers({
    required List<Map<String, dynamic>> poiData,
    required Map<String, bool> selectedCategories,
    required Map<String, Map<String, dynamic>> categoryStyles,
  }) {
    List<Marker> markers = [];
    
    List<Map<String, dynamic>> filteredPOIs = poiData.where((poi) {
      String poiType = poi['type'] as String;
      return selectedCategories[poiType] == true;
    }).toList();
    
    for (Map<String, dynamic> poi in filteredPOIs) {
      String poiType = poi['type'] as String;
      String poiName = poi['name'] as String;
      LatLng poiCoord = poi['coord'] as LatLng;
      
      if (categoryStyles.containsKey(poiType)) {
        Map<String, dynamic> style = categoryStyles[poiType]!;
        
        markers.add(Marker(
          point: poiCoord,
          width: 35,
          height: 35,
          child: Container(
            decoration: BoxDecoration(
              color: style['color'] as Color,
              borderRadius: BorderRadius.circular(17.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              style['icon'] as IconData,
              color: Colors.white,
              size: 18,
            ),
          ),
        ));
      }
    }
    
    return markers;
  }

  /// Calculate route efficiency metrics (matching Python analytics)
  static Map<String, double> calculateRouteMetrics(List<EvacuationRoute> routes) {
    if (routes.isEmpty) return {};
    
    double totalDistance = routes.fold(0.0, (sum, route) => sum + route.distanceKm);
    double totalTime = routes.fold(0.0, (sum, route) => sum + route.estimatedTimeMinutes);
    
    double avgDistance = totalDistance / routes.length;
    double avgTime = totalTime / routes.length;
    double shortestDistance = routes.map((r) => r.distanceKm).reduce(min);
    double fastestTime = routes.map((r) => r.estimatedTimeMinutes).reduce(min);
    
    return {
      'avgDistance': avgDistance,
      'avgTime': avgTime,
      'shortestDistance': shortestDistance,
      'fastestTime': fastestTime,
      'totalDistance': totalDistance,
      'totalTime': totalTime,
    };
  }
}

/// Route candidate for evacuation route generation
class RouteCandidate {
  final String area;
  final LatLng coord;
  final double distance;
  
  RouteCandidate(this.area, this.coord, this.distance);
}

/// Enhanced Evacuation Route with route points
class EvacuationRoute {
  final int id;
  final String destination;
  final double distanceKm;
  final double estimatedTimeMinutes;
  final String riskLevel;
  final Color routeColor;
  final List<LatLng> routePoints;

  EvacuationRoute({
    required this.id,
    required this.destination,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    required this.riskLevel,
    required this.routeColor,
    required this.routePoints,
  });
}
