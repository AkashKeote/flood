// OSM Road Layer for Real-time OpenStreetMap Integration
// Replaces static GeoJSON with live OSM API data

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'osm_service.dart';

class OSMRoadLayer extends StatefulWidget {
  final bool showRoadRisk;
  final Map<String, Color> riskColors;
  final LatLng? centerLocation;
  final String? areaName;

  const OSMRoadLayer({
    super.key,
    required this.showRoadRisk,
    required this.riskColors,
    this.centerLocation,
    this.areaName,
  });

  @override
  State<OSMRoadLayer> createState() => _OSMRoadLayerState();
}

class _OSMRoadLayerState extends State<OSMRoadLayer> {
  List<Polyline> roadPolylines = [];
  bool isLoading = true;
  int lowRiskCount = 0, moderateRiskCount = 0, highRiskCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showRoadRisk) {
      _loadOSMRoads();
    }
  }

  @override
  void didUpdateWidget(OSMRoadLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload roads if location or settings changed
    if (widget.showRoadRisk != oldWidget.showRoadRisk ||
        widget.centerLocation != oldWidget.centerLocation ||
        widget.areaName != oldWidget.areaName) {
      if (widget.showRoadRisk && roadPolylines.isEmpty) {
        _loadOSMRoads();
      }
    }
  }

  Future<void> _loadOSMRoads() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      print('🔄 Loading roads from OpenStreetMap API...');
      
      List<OSMRoad> osmRoads;
      
      if (widget.centerLocation != null && widget.areaName != null) {
        // Fetch roads for specific area
        osmRoads = await OSMService.fetchAreaRoads(
          widget.areaName!,
          widget.centerLocation!,
          radiusKm: 10.0, // 10km radius around location
        );
      } else {
        // Fetch all Mumbai roads
        osmRoads = await OSMService.fetchMumbaiRoads();
      }

      if (!mounted) return;

      List<Polyline> polylines = [];
      lowRiskCount = 0;
      moderateRiskCount = 0;
      highRiskCount = 0;

      for (OSMRoad road in osmRoads) {
        if (road.coordinates.length < 2) continue;

        // Skip high risk roads to match HTML behavior
        if (road.riskLevel > 1) {
          highRiskCount++;
          continue;
        }

        Color roadColor = _getRiskColorFromLevel(road.riskLevel);

        // Count risk levels for debugging
        switch (road.riskLevel) {
          case 0:
            lowRiskCount++;
            break;
          case 1:
            moderateRiskCount++;
            break;
          case 2:
            highRiskCount++;
            break;
        }

        // Create polyline for this road (matching llload.py exactly)
        polylines.add(
          Polyline(
            points: road.coordinates,
            strokeWidth: _getStrokeWidth(road.roadType, road.riskLevel),
            color: roadColor.withOpacity(0.8), // Exact llload.py opacity
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        roadPolylines = polylines;
        isLoading = false;
      });

      print('✅ Loaded ${polylines.length} road segments from OpenStreetMap API');
      print('🟢 Low risk roads: $lowRiskCount');
      print('🟠 Moderate risk roads: $moderateRiskCount');
      print('🔴 High risk roads: $highRiskCount (filtered out)');

    } catch (e) {
      print('❌ Error loading OSM roads: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  double _getStrokeWidth(String roadType, int riskLevel) {
    // Road thickness based on OSM highway type and risk
    double baseWidth = 1.2; // Default llload.py weight

    // Adjust for road type (OSM highway tags)
    switch (roadType.toLowerCase()) {
      case 'motorway':
        baseWidth = 2.5;
        break;
      case 'trunk':
        baseWidth = 2.2;
        break;
      case 'primary':
        baseWidth = 1.8;
        break;
      case 'secondary':
        baseWidth = 1.5;
        break;
      case 'tertiary':
        baseWidth = 1.2;
        break;
      default:
        baseWidth = 1.0;
    }

    // Make moderate risk roads slightly more visible
    if (riskLevel >= 1) baseWidth += 0.2;

    return baseWidth;
  }

  Color _getRiskColorFromLevel(int riskLevel) {
    // Map risk levels to colors (exact llload.py RISK_COLOR mapping)
    switch (riskLevel) {
      case 0:
        return Color(0xFF1a9850); // Green for low risk
      case 1:
        return Color(0xFFfc8d59); // Orange for moderate risk
      case 2:
        return Color(0xFFd73027); // Red for high risk (filtered out)
      default:
        return Color(0xFF9e9e9e); // Grey for unknown
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showRoadRisk) {
      return const SizedBox.shrink();
    }

    if (isLoading) {
      return const SizedBox.shrink(); // Don't show loading indicator on map
    }

    if (roadPolylines.isEmpty) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: roadPolylines,
    );
  }
}

