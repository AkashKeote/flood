// GeoJSON Layer for Risk-Colored Roads
// Loads and displays actual Mumbai road network with flood risk coloring

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeoJsonRoadLayer extends StatefulWidget {
  final bool showRoadRisk;
  final Map<String, Color> riskColors;

  const GeoJsonRoadLayer({
    super.key,
    required this.showRoadRisk,
    required this.riskColors,
  });

  @override
  State<GeoJsonRoadLayer> createState() => _GeoJsonRoadLayerState();
}

class _GeoJsonRoadLayerState extends State<GeoJsonRoadLayer> {
  List<Polyline> roadPolylines = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.showRoadRisk) {
      _loadRoadNetwork();
    }
  }

  @override
  void didUpdateWidget(GeoJsonRoadLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showRoadRisk != oldWidget.showRoadRisk) {
      if (widget.showRoadRisk && roadPolylines.isEmpty) {
        _loadRoadNetwork();
      }
    }
  }

  Future<void> _loadRoadNetwork() async {
    try {
      print('🔄 Loading real road network from GeoJSON...');
      
      // Load the actual sampled roads GeoJSON data (like HTML version)
      final String geoJsonString = await rootBundle.loadString('assets/roads_sampled.geojson');
      print('📄 GeoJSON loaded, parsing...');
      
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);
      print('📊 GeoJSON parsed, features: ${geoJson['features']?.length ?? 0}');
      
      List<Polyline> polylines = [];
      int lowRiskCount = 0, moderateRiskCount = 0, highRiskCount = 0;
      
      // Process each feature (actual road segment from Mumbai)
      for (var feature in geoJson['features']) {
        if (feature['geometry'] != null && feature['geometry']['type'] == 'LineString') {
          List<dynamic> coordinates = feature['geometry']['coordinates'];
          
          // Convert coordinates to LatLng points
          List<LatLng> points = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble()); // [lng, lat] to LatLng(lat, lng)
          }).toList();
          
          // Get risk level from feature properties
          int riskLevel = feature['properties']['risk'] ?? 0;
          String area = feature['properties']['areas'] ?? '';
          String highway = feature['properties']['highway_str'] ?? '';
          
          // Skip high risk roads (level 2) to match HTML exactly
          // HTML only shows risk 0 (green) and risk 1 (orange)
          if (riskLevel > 1) {
            continue;
          }
          
          Color roadColor = _getRiskColorFromLevel(riskLevel);
          
          // Count risk levels for debugging
          switch (riskLevel) {
            case 0: lowRiskCount++; break;
            case 1: moderateRiskCount++; break;
            case 2: highRiskCount++; break;
          }
          
          // Create polyline for this actual road segment (matching alit.py exactly)
          polylines.add(
            Polyline(
              points: points,
              strokeWidth: 1.2, // Exact alit.py weight
              color: roadColor.withOpacity(0.8), // Exact llload.py opacity
            ),
          );
        }
      }
      
      setState(() {
        roadPolylines = polylines;
        isLoading = false;
      });
      
      print('✅ Loaded ${polylines.length} real road segments from Mumbai');
      print('🟢 Low risk roads: $lowRiskCount');
      print('🟠 Moderate risk roads: $moderateRiskCount');
      print('🔴 High risk roads: $highRiskCount');
      
    } catch (e) {
      print('❌ Error loading road network: $e');
      print('❌ Error details: ${e.toString()}');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  double _getStrokeWidth(String highway, int riskLevel) {
    // Vary road thickness based on importance and risk - make more visible
    double baseWidth = 2.5; // Increased base width
    
    // Adjust for road type - thicker roads
    if (highway.contains('primary')) baseWidth = 4.0;
    else if (highway.contains('secondary')) baseWidth = 3.5;
    else if (highway.contains('trunk')) baseWidth = 4.5;
    else if (highway.contains('tertiary')) baseWidth = 3.0;
    
    // Make high-risk roads even more visible
    if (riskLevel >= 2) baseWidth += 1.0;
    else if (riskLevel >= 1) baseWidth += 0.5;
    
    return baseWidth;
  }
  


  Color _getRiskColorFromLevel(int riskLevel) {
    // Map risk levels to colors (based on alit.py RISK_COLOR mapping)
    // Make colors more vibrant and visible
    switch (riskLevel) {
      case 0:
        return Color(0xFF1a9850); // Bright green for low risk
      case 1:
        return Color(0xFFfc8d59); // Bright orange for moderate risk
      case 2:
        return Color(0xFFd73027); // Bright red for high risk
      default:
        return Color(0xFF9e9e9e); // Grey for unknown
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showRoadRisk || roadPolylines.isEmpty) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: roadPolylines,
    );
  }
}
