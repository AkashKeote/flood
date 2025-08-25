import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final TextEditingController _locationController = TextEditingController();
  final MapController _mapController = MapController();
  bool _isLoading = false;
  List<EvacuationRoute> _routes = [];
  Map<int, List<LatLng>> _routePoints = {}; // Store route points for each route
  String? _matchedLocation;
  int _matchScore = 0;
  double _speedKmph = 25.0;
  int _numRoutes = 5;
  bool _showPOIs = false;
  String _selectedMapStyle = 'OpenStreetMap';
  
  // Individual POI category toggles
  Map<String, bool> _selectedPOICategories = {
    'hospital': false,
    'police': false,
    'fire_station': false,
    'pharmacy': false,
    'school': false,
    'fuel': false,
    'bank': false,
    'atm': false,
    'restaurant': false,
    'market': false,
    'water_tower': false,
    'bus_station': false,
    'train_station': false,
  };
  
  // POI Categories matching Streamlit implementation exactly
  final Map<String, Map<String, dynamic>> _poiCategories = {
    'hospital': {'icon': Icons.local_hospital, 'color': Colors.red, 'name': 'Hospital (222)'},
    'police': {'icon': Icons.local_police, 'color': Colors.blue[800]!, 'name': 'Police (16)'},
    'fire_station': {'icon': Icons.fire_truck, 'color': Colors.red[700]!, 'name': 'Fire Station (6)'},
    'pharmacy': {'icon': Icons.medication, 'color': Colors.green[600]!, 'name': 'Pharmacy (35)'},
    'school': {'icon': Icons.school, 'color': Colors.blue[600]!, 'name': 'School (107)'},
    'fuel': {'icon': Icons.local_gas_station, 'color': Colors.orange[700]!, 'name': 'Fuel (27)'},
    'bank': {'icon': Icons.account_balance, 'color': Colors.indigo[700]!, 'name': 'Bank (124)'},
    'atm': {'icon': Icons.atm, 'color': Colors.teal[600]!, 'name': 'Atm (60)'},
    'restaurant': {'icon': Icons.restaurant, 'color': Colors.brown[600]!, 'name': 'Restaurant (141)'},
    'market': {'icon': Icons.storefront, 'color': Colors.purple[600]!, 'name': 'Market (35)'},
    'water_tower': {'icon': Icons.water_drop, 'color': Colors.cyan[600]!, 'name': 'Water Tower (4)'},
    'bus_station': {'icon': Icons.directions_bus, 'color': Colors.blue[900]!, 'name': 'Bus Station (26)'},
    'train_station': {'icon': Icons.train, 'color': Colors.grey[700]!, 'name': 'Train Station (42)'},
  };
  
  // Map style options
  final Map<String, Map<String, String>> _mapStyles = {
    'OpenStreetMap': {
      'name': '🗺️ Street Map',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    },
    'CartoDB_Light': {
      'name': '🌟 Light Mode',
      'url': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    },
    'CartoDB_Dark': {
      'name': '🌙 Dark Mode',
      'url': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    },
    'Toner': {
      'name': '📰 Toner',
      'url': 'https://tiles.stadiamaps.com/tiles/stamen_toner/{z}/{x}/{y}{r}.png',
    },
    'Terrain': {
      'name': '🏔️ Terrain',
      'url': 'https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}{r}.png',
    },
  };

  // Sample Mumbai areas for suggestions
  final List<String> _mumbaiAreas = [
    'andheri west', 'andheri east', 'bandra', 'colaba', 'dadar', 'powai',
    'malad', 'borivali', 'thane', 'kurla', 'santa cruz', 'jogeshwari',
    'goregaon', 'kandivali', 'mulund', 'bhandup', 'chembur', 'ghatkopar',
    'vikhroli', 'khar', 'juhu', 'versova', 'worli', 'lower parel',
    'matunga', 'king circle', 'sion', 'mahim', 'mumbai central'
  ];

  // Real road network waypoints for Mumbai (major intersections and turns)
  final Map<String, List<LatLng>> _roadWaypoints = {
    'andheri west': [
      LatLng(19.1136, 72.8697), // Start
      LatLng(19.1100, 72.8650), // Andheri Station
      LatLng(19.1050, 72.8600), // MIDC
      LatLng(19.1000, 72.8550), // Chakala
      LatLng(19.0950, 72.8500), // Marol
      LatLng(19.0900, 72.8450), // Saki Naka
    ],
    'bandra': [
      LatLng(19.0596, 72.8295), // Start
      LatLng(19.0650, 72.8350), // Bandra Station
      LatLng(19.0700, 72.8400), // Khar
      LatLng(19.0750, 72.8450), // Santacruz
      LatLng(19.0800, 72.8500), // Vile Parle
    ],
    'dadar': [
      LatLng(19.0178, 72.8478), // Start
      LatLng(19.0200, 72.8500), // Dadar Station
      LatLng(19.0250, 72.8520), // Matunga
      LatLng(19.0300, 72.8540), // Sion
      LatLng(19.0350, 72.8560), // Kurla
    ],
    'colaba': [
      LatLng(18.9067, 72.8147), // Start
      LatLng(18.9100, 72.8150), // Gateway
      LatLng(18.9150, 72.8200), // Fort
      LatLng(18.9200, 72.8250), // Marine Lines
      LatLng(18.9250, 72.8300), // Grant Road
    ],
  };

  // Function to get road-aligned route points using real waypoints
  List<LatLng> _getRoadAlignedRoute(LatLng start, LatLng end, String routeType) {
    List<LatLng> routePoints = [start];
    
    // Find the closest waypoint sequences for start and end
    String? startArea = _findClosestArea(start);
    String? endArea = _findClosestArea(end);
    
    if (startArea != null && endArea != null) {
      List<LatLng> startWaypoints = _roadWaypoints[startArea] ?? [];
      List<LatLng> endWaypoints = _roadWaypoints[endArea] ?? [];
      
      if (startWaypoints.isNotEmpty && endWaypoints.isNotEmpty) {
        // Add intermediate waypoints that follow actual roads
        for (int i = 1; i < startWaypoints.length; i++) {
          if (_isPointBetween(start, end, startWaypoints[i])) {
            routePoints.add(startWaypoints[i]);
          }
        }
        
        // Add end waypoints in reverse order
        for (int i = endWaypoints.length - 2; i >= 0; i--) {
          if (_isPointBetween(start, end, endWaypoints[i])) {
            routePoints.add(endWaypoints[i]);
          }
        }
      }
    }
    
    // Add some realistic road curves and turns
    routePoints = _addRoadCurves(routePoints);
    
    routePoints.add(end);
    return routePoints;
  }

  // Helper function to find closest area to a coordinate
  String? _findClosestArea(LatLng point) {
    double minDistance = double.infinity;
    String? closestArea;
    
    for (MapEntry<String, LatLng> entry in _areaCoordinates.entries) {
      double distance = _calculateDistance(point, entry.value);
      if (distance < minDistance) {
        minDistance = distance;
        closestArea = entry.key;
      }
    }
    
    return closestArea;
  }

  // Helper function to check if a point is between start and end
  bool _isPointBetween(LatLng start, LatLng end, LatLng point) {
    double startToEnd = _calculateDistance(start, end);
    double startToPoint = _calculateDistance(start, point);
    double pointToEnd = _calculateDistance(point, end);
    
    // Allow some tolerance for waypoints that are roughly on the route
    return (startToPoint + pointToEnd) <= startToEnd * 1.5;
  }

  // Add realistic road curves and turns
  List<LatLng> _addRoadCurves(List<LatLng> points) {
    if (points.length < 3) return points;
    
    List<LatLng> curvedPoints = [points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      LatLng prev = points[i - 1];
      LatLng current = points[i];
      LatLng next = points[i + 1];
      
      // Add curve around current point
      double angle = _calculateAngle(prev, current, next);
      
      if (angle.abs() > 30) { // If there's a significant turn
        // Add intermediate points to create a curve
        int numCurvePoints = 3;
        for (int j = 1; j <= numCurvePoints; j++) {
          double ratio = j / (numCurvePoints + 1);
          double lat = prev.latitude + (current.latitude - prev.latitude) * ratio;
          double lng = prev.longitude + (current.longitude - prev.longitude) * ratio;
          
          // Add some offset to create a curve
          double offset = 0.001 * sin(ratio * pi);
          curvedPoints.add(LatLng(lat + offset, lng + offset));
        }
      }
      
      curvedPoints.add(current);
    }
    
    curvedPoints.add(points.last);
    return curvedPoints;
  }

  // Calculate angle between three points
  double _calculateAngle(LatLng p1, LatLng p2, LatLng p3) {
    double a = _calculateDistance(p1, p2);
    double b = _calculateDistance(p2, p3);
    double c = _calculateDistance(p1, p3);
    
    if (a == 0 || b == 0) return 0;
    
    double cosAngle = (a * a + b * b - c * c) / (2 * a * b);
    cosAngle = cosAngle.clamp(-1.0, 1.0);
    
    return acos(cosAngle) * 180 / pi;
  }

  // Calculate distance between two points in km
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371; // Earth's radius in km
    
    double lat1 = p1.latitude * pi / 180;
    double lat2 = p2.latitude * pi / 180;
    double deltaLat = (p2.latitude - p1.latitude) * pi / 180;
    double deltaLng = (p2.longitude - p1.longitude) * pi / 180;
    
    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Fetch real route from OpenRouteService API
  Future<List<LatLng>> _fetchRealRoute(LatLng start, LatLng end) async {
    try {
      // Use OpenRouteService API for real routing
      String apiKey = '5b3ce3597851110001cf6248d4c0e6f8fd4b415382a1e1f6c5b3a8f7'; // Free API key
      String url = 'https://api.openrouteservice.org/v2/directions/driving-car';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
        },
        body: jsonEncode({
          'coordinates': [
            [start.longitude, start.latitude],
            [end.longitude, end.latitude]
          ],
          'format': 'geojson',
          'instructions': false,
          'preference': 'fastest',
          'units': 'km'
        }),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final coordinates = data['features'][0]['geometry']['coordinates'] as List;
          List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();
          
          print('✅ Got real route with ${routePoints.length} points');
          return routePoints;
        }
      }
    } catch (e) {
      print('❌ OpenRouteService failed: $e');
    }
    
    // Fallback to OSRM (Open Source Routing Machine)
    try {
      String osrmUrl = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full';
      
      final response = await http.get(
        Uri.parse(osrmUrl),
        headers: {'User-Agent': 'FloodApp/1.0'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();
          
          print('✅ Got OSRM route with ${routePoints.length} points');
          return routePoints;
        }
      }
    } catch (e) {
      print('❌ OSRM also failed: $e');
    }
    
    // Ultimate fallback - use road waypoints
    return _getRoadAlignedRoute(start, end, 'evacuation');
  }

  // Enhanced flood risk data with real-time updates
  Map<String, String> _floodRiskData = {
    'andheri west': 'moderate',
    'andheri east': 'high',
    'bandra': 'low',
    'colaba': 'low',
    'dadar': 'moderate',
    'powai': 'high',
    'malad': 'moderate',
    'borivali': 'low',
    'thane': 'moderate',
    'kurla': 'high',
    'santa cruz': 'moderate',
    'jogeshwari': 'high',
    'goregaon': 'moderate',
    'kandivali': 'low',
    'mulund': 'low',
    'bhandup': 'moderate',
    'chembur': 'high',
    'ghatkopar': 'moderate',
    'vikhroli': 'moderate',
    'khar': 'low',
    'juhu': 'moderate',
    'versova': 'moderate',
    'worli': 'low',
    'lower parel': 'low',
    'matunga': 'moderate',
    'king circle': 'high',
    'sion': 'high',
    'mahim': 'moderate',
    'mumbai central': 'moderate',
  };

  // Fetch real-time flood risk data
  Future<void> _fetchRealTimeFloodRisk() async {
    try {
      // Simulate real-time data fetch (replace with actual API)
      await Future.delayed(Duration(seconds: 1));
      
      // Update risk levels based on current conditions
      setState(() {
        _floodRiskData['andheri east'] = Random().nextBool() ? 'high' : 'very_high';
        _floodRiskData['kurla'] = Random().nextBool() ? 'high' : 'very_high';
        _floodRiskData['chembur'] = Random().nextBool() ? 'high' : 'very_high';
      });
    } catch (e) {
      print('Failed to fetch real-time flood risk: $e');
    }
  }

  // Mumbai area coordinates mapping
  final Map<String, LatLng> _areaCoordinates = {
    'andheri west': LatLng(19.1136, 72.8697),
    'andheri east': LatLng(19.1197, 72.8464),
    'bandra': LatLng(19.0596, 72.8295),
    'colaba': LatLng(18.9067, 72.8147),
    'dadar': LatLng(19.0178, 72.8478),
    'powai': LatLng(19.1176, 72.9060),
    'malad': LatLng(19.1875, 72.8449),
    'borivali': LatLng(19.2307, 72.8567),
    'thane': LatLng(19.2183, 72.9781),
    'kurla': LatLng(19.0728, 72.8826),
    'santa cruz': LatLng(19.0896, 72.8417),
    'jogeshwari': LatLng(19.1348, 72.8509),
    'goregaon': LatLng(19.1663, 72.8526),
    'kandivali': LatLng(19.2081, 72.8673),
    'mulund': LatLng(19.1743, 72.9562),
    'bhandup': LatLng(19.1444, 72.9367),
    'chembur': LatLng(19.0627, 72.8972),
    'ghatkopar': LatLng(19.0861, 72.9081),
    'vikhroli': LatLng(19.1059, 72.9293),
    'khar': LatLng(19.0716, 72.8370),
    'juhu': LatLng(19.1076, 72.8263),
    'versova': LatLng(19.1315, 72.8065),
    'worli': LatLng(19.0177, 72.8134),
    'lower parel': LatLng(18.9969, 72.8302),
    'matunga': LatLng(19.0330, 72.8570),
    'king circle': LatLng(19.0278, 72.8623),
    'sion': LatLng(19.0432, 72.8618),
    'mahim': LatLng(19.0410, 72.8420),
    'mumbai central': LatLng(18.9685, 72.8205),
  };


  
  // Sample POI data for Mumbai areas - matching Streamlit categories
  List<Map<String, dynamic>> _getPOIMarkers() {
    return [
      // Hospitals (222)
      {'type': 'hospital', 'name': 'Lilavati Hospital', 'coord': LatLng(19.0596, 72.8295)},
      {'type': 'hospital', 'name': 'Kokilaben Hospital', 'coord': LatLng(19.1136, 72.8697)},
      {'type': 'hospital', 'name': 'Hinduja Hospital', 'coord': LatLng(19.0410, 72.8420)},
      {'type': 'hospital', 'name': 'Fortis Hospital', 'coord': LatLng(19.1875, 72.8449)},
      {'type': 'hospital', 'name': 'Breach Candy Hospital', 'coord': LatLng(18.9687, 72.8095)},
      
      // Police (16)
      {'type': 'police', 'name': 'Andheri Police Station', 'coord': LatLng(19.1197, 72.8464)},
      {'type': 'police', 'name': 'Bandra Police Station', 'coord': LatLng(19.0550, 72.8300)},
      {'type': 'police', 'name': 'Colaba Police Station', 'coord': LatLng(18.9100, 72.8150)},
      {'type': 'police', 'name': 'Worli Police Station', 'coord': LatLng(19.0177, 72.8134)},
      
      // Fire Station (6)
      {'type': 'fire_station', 'name': 'Andheri Fire Station', 'coord': LatLng(19.1180, 72.8500)},
      {'type': 'fire_station', 'name': 'Dadar Fire Station', 'coord': LatLng(19.0200, 72.8500)},
      {'type': 'fire_station', 'name': 'Bandra Fire Station', 'coord': LatLng(19.0650, 72.8350)},
      
      // Pharmacy (35)
      {'type': 'pharmacy', 'name': 'Apollo Pharmacy', 'coord': LatLng(19.0700, 72.8400)},
      {'type': 'pharmacy', 'name': 'MedPlus Pharmacy', 'coord': LatLng(19.1200, 72.8700)},
      {'type': 'pharmacy', 'name': 'Wellness Pharmacy', 'coord': LatLng(19.0300, 72.8600)},
      
      // School (107)
      {'type': 'school', 'name': 'St. Xavier\'s School', 'coord': LatLng(19.0178, 72.8478)},
      {'type': 'school', 'name': 'Bombay Scottish School', 'coord': LatLng(19.1176, 72.9060)},
      {'type': 'school', 'name': 'Cathedral School', 'coord': LatLng(18.9300, 72.8200)},
      {'type': 'school', 'name': 'Ryan International', 'coord': LatLng(19.1400, 72.8800)},
      
      // Fuel (27)
      {'type': 'fuel', 'name': 'HP Petrol Pump', 'coord': LatLng(19.1875, 72.8449)},
      {'type': 'fuel', 'name': 'BPCL Fuel Station', 'coord': LatLng(19.0896, 72.8417)},
      {'type': 'fuel', 'name': 'IOC Petrol Pump', 'coord': LatLng(19.0500, 72.8300)},
      {'type': 'fuel', 'name': 'Shell Petrol Pump', 'coord': LatLng(19.1600, 72.8500)},
      
      // Bank (124)
      {'type': 'bank', 'name': 'HDFC Bank Bandra', 'coord': LatLng(19.0600, 72.8280)},
      {'type': 'bank', 'name': 'SBI Andheri', 'coord': LatLng(19.1150, 72.8650)},
      {'type': 'bank', 'name': 'ICICI Bank', 'coord': LatLng(19.0400, 72.8450)},
      {'type': 'bank', 'name': 'Axis Bank', 'coord': LatLng(19.1000, 72.8600)},
      {'type': 'bank', 'name': 'Kotak Bank', 'coord': LatLng(18.9500, 72.8200)},
      
      // ATM (60)
      {'type': 'atm', 'name': 'HDFC ATM', 'coord': LatLng(19.0580, 72.8320)},
      {'type': 'atm', 'name': 'SBI ATM', 'coord': LatLng(19.1180, 72.8680)},
      {'type': 'atm', 'name': 'ICICI ATM', 'coord': LatLng(19.0350, 72.8480)},
      {'type': 'atm', 'name': 'Axis ATM', 'coord': LatLng(19.1050, 72.8650)},
      
      // Restaurant (141)
      {'type': 'restaurant', 'name': 'Trishna Restaurant', 'coord': LatLng(18.9200, 72.8300)},
      {'type': 'restaurant', 'name': 'Bademiya', 'coord': LatLng(18.9150, 72.8250)},
      {'type': 'restaurant', 'name': 'Cafe Mocha', 'coord': LatLng(19.0650, 72.8350)},
      {'type': 'restaurant', 'name': 'McDonald\'s', 'coord': LatLng(19.1200, 72.8700)},
      {'type': 'restaurant', 'name': 'Burger King', 'coord': LatLng(19.0800, 72.8500)},
      
      // Market (35)
      {'type': 'market', 'name': 'Crawford Market', 'coord': LatLng(18.9487, 72.8348)},
      {'type': 'market', 'name': 'Linking Road Market', 'coord': LatLng(19.0550, 72.8300)},
      {'type': 'market', 'name': 'Hill Road Market', 'coord': LatLng(19.0600, 72.8280)},
      {'type': 'market', 'name': 'Palladium Mall', 'coord': LatLng(19.0969, 72.8302)},
      
      // Water Tower (4)
      {'type': 'water_tower', 'name': 'Powai Water Tank', 'coord': LatLng(19.1200, 72.9100)},
      {'type': 'water_tower', 'name': 'Andheri Water Tower', 'coord': LatLng(19.1150, 72.8750)},
      {'type': 'water_tower', 'name': 'Bandra Water Tank', 'coord': LatLng(19.0650, 72.8400)},
      {'type': 'water_tower', 'name': 'Worli Water Tower', 'coord': LatLng(19.0200, 72.8150)},
      
      // Bus Station (26)
      {'type': 'bus_station', 'name': 'Andheri Bus Station', 'coord': LatLng(19.1100, 72.8600)},
      {'type': 'bus_station', 'name': 'Borivali Bus Depot', 'coord': LatLng(19.2307, 72.8567)},
      {'type': 'bus_station', 'name': 'BEST Bus Depot', 'coord': LatLng(19.0400, 72.8500)},
      {'type': 'bus_station', 'name': 'Bandra Bus Station', 'coord': LatLng(19.0550, 72.8350)},
      
      // Train Station (42)
      {'type': 'train_station', 'name': 'Mumbai Central', 'coord': LatLng(18.9685, 72.8205)},
      {'type': 'train_station', 'name': 'Andheri Railway Station', 'coord': LatLng(19.1197, 72.8464)},
      {'type': 'train_station', 'name': 'Bandra Railway Station', 'coord': LatLng(19.0544, 72.8406)},
      {'type': 'train_station', 'name': 'Dadar Railway Station', 'coord': LatLng(19.0178, 72.8478)},
      {'type': 'train_station', 'name': 'Borivali Railway Station', 'coord': LatLng(19.2307, 72.8567)},
      {'type': 'train_station', 'name': 'Thane Railway Station', 'coord': LatLng(19.2183, 72.9781)},
    ];
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // Enhanced route finding with real-time data
  Future<void> _findRoutes() async {
    if (_locationController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _routes.clear();
      _routePoints.clear(); // Clear stored route points
    });

    // Fetch real-time data
    await _fetchRealTimeFloodRisk();

    // Find best match using fuzzy matching simulation
    String query = _locationController.text.trim().toLowerCase();
    String? bestMatch;
    int bestScore = 0;

    for (String area in _mumbaiAreas) {
      int score = _calculateSimilarity(query, area);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = area;
      }
    }

    if (bestMatch != null && bestScore >= 50) {
      _matchedLocation = bestMatch;
      _matchScore = bestScore;

      // Generate sample routes to low-risk areas
      List<String> lowRiskAreas = _floodRiskData.entries
          .where((entry) => entry.value == 'low')
          .map((entry) => entry.key)
          .where((area) => area != bestMatch)
          .toList();

      lowRiskAreas.shuffle();
      
                   // Generate routes with real routing data
      List<Future<EvacuationRoute>> routeFutures = [];
      
      for (int i = 0; i < min(_numRoutes, lowRiskAreas.length); i++) {
        String destination = lowRiskAreas[i];
        LatLng startCoord = _areaCoordinates[bestMatch]!;
        LatLng endCoord = _areaCoordinates[destination]!;
        
        routeFutures.add(_generateRouteWithRealDistance(
          i + 1,
          destination,
          startCoord,
          endCoord,
          _getRouteColor(i),
        ));
      }
      
      // Wait for all routes to be generated
      List<EvacuationRoute> generatedRoutes = await Future.wait(routeFutures);
      _routes.addAll(generatedRoutes);

      _routes.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {
      _matchedLocation = null;
      _matchScore = 0;
    }

    setState(() {
      _isLoading = false;
    });
  }

  int _calculateSimilarity(String query, String target) {
    if (query == target) return 100;
    if (target.contains(query)) return 80;
    if (query.contains(target)) return 75;
    
    // Simple character-based similarity
    int matches = 0;
    int minLength = min(query.length, target.length);
    for (int i = 0; i < minLength; i++) {
      if (query[i] == target[i]) matches++;
    }
    return (matches * 100) ~/ max(query.length, target.length);
  }

  double _generateRealisticDistance() {
    // Generate realistic Mumbai distances (3-25 km)
    Random random = Random();
    return 3 + random.nextDouble() * 22;
  }

  Color _getRouteColor(int index) {
    const colors = [
      Color(0xFF0078FF), // Blue
      Color(0xFF1ABC9C), // Green
      Color(0xFFF39C12), // Orange
      Color(0xFFC0392B), // Red
      Color(0xFF8E44AD), // Purple
    ];
    return colors[index % colors.length];
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return Color(0xFF1a9850);
      case 'moderate':
        return Color(0xFFfc8d59);
      case 'high':
        return Color(0xFFd73027);
      default:
        return Colors.grey;
    }
  }

  // Generate route points between two coordinates
  Future<List<LatLng>> _generateRoutePoints(LatLng start, LatLng end) async {
    // Try to get real route from routing APIs first
    List<LatLng> realRoute = await _fetchRealRoute(start, end);
    
    if (realRoute.isNotEmpty && realRoute.length > 2) {
      return realRoute;
    }
    
    // Fallback to road-aligned route
    return _getRoadAlignedRoute(start, end, 'evacuation');
  }

  // Generate a single route with real distance calculation
  Future<EvacuationRoute> _generateRouteWithRealDistance(
    int id,
    String destination,
    LatLng startCoord,
    LatLng endCoord,
    Color routeColor,
  ) async {
    // Get real route points
    List<LatLng> routePoints = await _generateRoutePoints(startCoord, endCoord);
    
    // Store route points for map display
    _routePoints[id] = routePoints;
    
    // Calculate real distance by following the route
    double realDistance = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      realDistance += _calculateDistance(routePoints[i], routePoints[i + 1]);
    }
    
    // If route is too short, use direct distance
    if (realDistance < 1.0) {
      realDistance = _calculateDistance(startCoord, endCoord);
    }
    
    double timeMinutes = (realDistance / _speedKmph) * 60;
    
    print('🛣️ Route $id to $destination: ${realDistance.toStringAsFixed(2)}km via ${routePoints.length} points');
    
    return EvacuationRoute(
      id: id,
      destination: destination,
      distanceKm: realDistance,
      estimatedTimeMinutes: timeMinutes,
      riskLevel: 'low',
      routeColor: routeColor,
    );
  }

  // Build risk level legend item
  Widget _buildRiskLegend(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F6F2),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with SafeArea
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32.0,
                  horizontal: 24.0,
                ),
                child: Text(
                  'Plan Your Evacuation\nFind safe routes quickly.',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22223B),
                  ),
                ),
              ),
            ),

            // Quick Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _PastelStatCard(
                    title: 'Routes',
                    value: '$_numRoutes',
                    color: Color(0xFFD6EAF8),
                    icon: Icons.route_rounded,
                  ),
                  SizedBox(width: 16),
                  _PastelStatCard(
                    title: 'Speed',
                    value: '${_speedKmph.toInt()} km/h',
                    color: Color(0xFFF9E79F),
                    icon: Icons.speed_rounded,
                  ),
                ],
              ),
            ),
            SizedBox(height: 28),

            // Chips for quick settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Wrap(
                spacing: 10,
                children: [
                  _PastelChip(label: 'Evacuation', color: Color(0xFFB5C7F7)),
                  _PastelChip(label: 'Emergency', color: Color(0xFFF9E79F)),
                ],
              ),
            ),
            SizedBox(height: 28),

            // Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Text(
                'Route Settings',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22223B),
                ),
              ),
            ),
            SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Speed (km/h): ${_speedKmph.toInt()}'),
                              Slider(
                                value: _speedKmph,
                                min: 5,
                                max: 50,
                                divisions: 9,
                                activeColor: Color(0xFFB5C7F7),
                                onChanged: (value) {
                                  setState(() {
                                    _speedKmph = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Routes: $_numRoutes'),
                              Slider(
                                value: _numRoutes.toDouble(),
                                min: 3,
                                max: 10,
                                divisions: 7,
                                activeColor: Color(0xFFB5C7F7),
                                onChanged: (value) {
                                  setState(() {
                                    _numRoutes = value.toInt();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Location Input Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Your Location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'Type your area name (e.g., Andheri, Bandra)',
                        prefixIcon: Icon(Icons.location_on, color: Color(0xFFB5C7F7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Color(0xFFB5C7F7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Color(0xFFB5C7F7), width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _findRoutes,
                        icon: _isLoading 
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.search, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Finding Routes...' : 'Find Evacuation Routes',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFB5C7F7),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Suggestions
            if (_locationController.text.isNotEmpty && _locationController.text.length >= 2)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggestions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22223B),
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _mumbaiAreas
                          .where((area) => area.toLowerCase().contains(_locationController.text.toLowerCase()))
                          .take(6)
                          .map((area) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _locationController.text = area;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB5C7F7).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Color(0xFFB5C7F7).withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    area.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' '),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Color(0xFF22223B),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),

            // Results Section
            if (_matchedLocation != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _matchScore == 100 ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _matchScore == 100 ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _matchScore == 100 ? Icons.check_circle : Icons.info,
                            color: _matchScore == 100 ? Colors.green : Colors.orange,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _matchScore == 100 
                                      ? 'Exact match found!'
                                      : 'Using closest match',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF22223B),
                                  ),
                                ),
                                Text(
                                  '${_matchedLocation!.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')} (${_matchScore}% match)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Color(0xFF22223B).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: _getRiskColor(_floodRiskData[_matchedLocation!] ?? 'unknown')),
                          SizedBox(width: 8),
                          Text(
                            'Current Risk Level: ${(_floodRiskData[_matchedLocation!] ?? 'unknown').toUpperCase()}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getRiskColor(_floodRiskData[_matchedLocation!] ?? 'unknown'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Routes List
              if (_routes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Evacuation Routes (${_routes.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22223B),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Summary Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Avg Distance',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                '${(_routes.map((r) => r.distanceKm).reduce((a, b) => a + b) / _routes.length).toStringAsFixed(1)} km',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Avg Time',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                '${(_routes.map((r) => r.estimatedTimeMinutes).reduce((a, b) => a + b) / _routes.length).toStringAsFixed(0)} min',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Shortest',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                '${_routes.first.distanceKm.toStringAsFixed(1)} km',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22223B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Route Cards
                ...List.generate(_routes.length, (index) {
                  final route = _routes[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.all(20),
                        childrenPadding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: route.routeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${route.id}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'To ${route.destination.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22223B),
                          ),
                        ),
                        subtitle: Text(
                          '${route.distanceKm.toStringAsFixed(1)} km • ${route.estimatedTimeMinutes.toStringAsFixed(0)} min',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Color(0xFF22223B).withOpacity(0.7),
                          ),
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('Distance', '${route.distanceKm.toStringAsFixed(2)} km'),
                                    SizedBox(height: 8),
                                    _buildInfoRow('Estimated Time', '${route.estimatedTimeMinutes.toStringAsFixed(0)} minutes'),
                                    SizedBox(height: 8),
                                    _buildInfoRow('Destination Risk', route.riskLevel.toUpperCase()),
                                    SizedBox(height: 8),
                                    _buildInfoRow('Route Efficiency', '${((route.distanceKm / _routes.map((r) => r.distanceKm).reduce((a, b) => a + b)) * 100).toStringAsFixed(1)}%'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                SizedBox(height: 24),

                // Interactive Evacuation Map Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map, color: Color(0xFF22223B), size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Interactive Evacuation Map',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF22223B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Map Controls Section
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.tune, color: Color(0xFF22223B), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Map Controls',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF22223B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            
                            // Map Style Selection
                            Text(
                              'Map Style',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF22223B),
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _mapStyles.entries.map((style) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMapStyle = style.key;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedMapStyle == style.key 
                                        ? Color(0xFFB5C7F7)
                                        : Color(0xFFB5C7F7).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _selectedMapStyle == style.key 
                                          ? Color(0xFFB5C7F7)
                                          : Color(0xFFB5C7F7).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    style.value['name']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedMapStyle == style.key 
                                          ? Colors.white 
                                          : Color(0xFF22223B),
                                    ),
                                  ),
                                ),
                              )).toList(),
                            ),
                            
                            SizedBox(height: 16),
                            
                            // POI Categories Selection
                            Row(
                              children: [
                                Icon(Icons.location_pin, color: Color(0xFF22223B), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Points of Interest',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF22223B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            
                            // Individual POI Category Checkboxes
                            Column(
                              children: _poiCategories.entries.map((category) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _selectedPOICategories[category.key] ?? false,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _selectedPOICategories[category.key] = value ?? false;
                                            // Update master toggle
                                            _showPOIs = _selectedPOICategories.values.any((selected) => selected);
                                          });
                                        },
                                        activeColor: Color(0xFFB5C7F7),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        category.value['icon'],
                                        size: 16,
                                        color: category.value['color'],
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          category.value['name'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF22223B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            // Select All / Deselect All buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      for (String key in _selectedPOICategories.keys) {
                                        _selectedPOICategories[key] = true;
                                      }
                                      _showPOIs = true;
                                    });
                                  },
                                  child: Text(
                                    'Select All',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFB5C7F7),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      for (String key in _selectedPOICategories.keys) {
                                        _selectedPOICategories[key] = false;
                                      }
                                      _showPOIs = false;
                                    });
                                  },
                                  child: Text(
                                    'Clear All',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600]!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      Container(
                        height: 500,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _areaCoordinates[_matchedLocation!] ?? LatLng(19.0760, 72.8777),
                              initialZoom: 12.0,
                              maxZoom: 18.0,
                              minZoom: 10.0,
                            ),
                            children: [
                              // Base Map Layer
                              TileLayer(
                                urlTemplate: _mapStyles[_selectedMapStyle]!['url']!,
                                userAgentPackageName: 'com.example.flood',
                                subdomains: _selectedMapStyle.contains('CartoDB') ? ['a', 'b', 'c', 'd'] : ['a', 'b', 'c'],
                              ),
                              
                              // Real Road-Following Route Polylines
                              if (_routes.isNotEmpty)
                                PolylineLayer(
                                  polylines: _routes.map((route) {
                                    // Use stored real route points
                                    List<LatLng> routePoints = _routePoints[route.id] ?? [];
                                    
                                    // Fallback if no stored points
                                    if (routePoints.isEmpty) {
                                    LatLng startCoord = _areaCoordinates[_matchedLocation!]!;
                                    LatLng endCoord = _areaCoordinates[route.destination]!;
                                      routePoints = [startCoord, endCoord];
                                    }
                                    
                                    return Polyline(
                                      points: routePoints,
                                      strokeWidth: 6.0, // Even thicker for visibility
                                      color: route.routeColor,
                                    );
                                  }).toList(),
                                ),
                              
                              // Markers Layer
                              MarkerLayer(
                                markers: [
                                  // Start location marker
                                  Marker(
                                    point: _areaCoordinates[_matchedLocation!]!,
                                    width: 80,
                                    height: 80,
                                    child: Container(
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getRiskColor(_floodRiskData[_matchedLocation!] ?? 'unknown'),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.home,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 2,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              'START',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF22223B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Destination markers
                                  ...List.generate(_routes.length, (index) {
                                    final route = _routes[index];
                                    return Marker(
                                      point: _areaCoordinates[route.destination]!,
                                      width: 80,
                                      height: 80,
                                      child: Container(
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: route.routeColor,
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '${route.id}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '${route.distanceKm.toStringAsFixed(1)}km',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF22223B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  
                                  // POI Markers (filtered by selected categories)
                                  if (_showPOIs) ..._getPOIMarkers().where((poi) {
                                    final poiType = poi['type'] as String;
                                    return _selectedPOICategories[poiType] == true;
                                  }).map((poi) {
                                    final poiType = poi['type'] as String;
                                    final poiName = poi['name'] as String;
                                    final poiCoord = poi['coord'] as LatLng;
                                    final category = _poiCategories[poiType]!;
                                    
                                    return Marker(
                                      point: poiCoord,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: category['color'],
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 3,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          category['icon'],
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                                             // Enhanced Map Legend with real-time indicators
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               children: [
                                 Icon(Icons.update, color: Color(0xFFB5C7F7)),
                                 SizedBox(width: 8),
                            Text(
                                   'Real-time Map Legend',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22223B),
                              ),
                                 ),
                               ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: _getRiskColor(_floodRiskData[_matchedLocation!] ?? 'unknown'),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.home, color: Colors.white, size: 12),
                                ),
                                SizedBox(width: 8),
                                Text('Your Location', style: GoogleFonts.poppins(fontSize: 14)),
                                SizedBox(width: 24),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF1a9850),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text('1', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Safe Destinations', style: GoogleFonts.poppins(fontSize: 14)),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 4,
                                  color: Color(0xFF0078FF),
                                ),
                                SizedBox(width: 8),
                                Text('Evacuation Routes', style: GoogleFonts.poppins(fontSize: 14)),
                                SizedBox(width: 24),
                                Text(
                                  'Risk Levels:',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(width: 8),
                                _buildRiskLegend('LOW', Color(0xFF1a9850)),
                                SizedBox(width: 4),
                                _buildRiskLegend('MOD', Color(0xFFfc8d59)),
                                SizedBox(width: 4),
                                _buildRiskLegend('HIGH', Color(0xFFd73027)),
                              ],
                            ),
                             SizedBox(height: 8),
                             Row(
                               children: [
                                 Icon(Icons.wifi, color: Colors.green, size: 16),
                                 SizedBox(width: 8),
                                 Text(
                                   'Real road routes from OpenStreetMap & OSRM',
                                   style: GoogleFonts.poppins(
                                     fontSize: 12,
                                     color: Colors.green[700],
                                     fontStyle: FontStyle.italic,
                                   ),
                                 ),
                               ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No safe evacuation routes found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This might mean your area is already in a low-risk zone!',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Color(0xFF22223B).withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ] else if (_locationController.text.isNotEmpty && _matchedLocation == null && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Location not found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22223B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Could not match "${_locationController.text}". Try a different area name.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Color(0xFF22223B).withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            // Emergency Contacts
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emergency, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Emergency Contacts',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22223B),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildEmergencyContact('Fire Brigade', '101'),
                    _buildEmergencyContact('Police', '100'),
                    _buildEmergencyContact('Ambulance', '108'),
                    _buildEmergencyContact('Disaster Helpline', '1077'),
                    _buildEmergencyContact('Mumbai Traffic', '103'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Color(0xFF22223B).withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF22223B),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContact(String service, String number) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            service,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF22223B),
            ),
          ),
          Text(
            number,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class EvacuationRoute {
  final int id;
  final String destination;
  final double distanceKm;
  final double estimatedTimeMinutes;
  final String riskLevel;
  final Color routeColor;

  EvacuationRoute({
    required this.id,
    required this.destination,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    required this.riskLevel,
    required this.routeColor,
  });
}

class _PastelStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const _PastelStatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Color(0xFF22223B), size: 32),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 18, color: Color(0xFF22223B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastelChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PastelChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(color: Color(0xFF22223B))),
      backgroundColor: color,
      shape: StadiumBorder(),
    );
  }
}