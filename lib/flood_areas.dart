import 'package:google_maps_flutter/google_maps_flutter.dart';

class FloodArea {
  final String name;
  final LatLng position;
  final String risk;
  final double waterLevel;
  final String source;
  const FloodArea({
    required this.name,
    required this.position,
    required this.risk,
    required this.waterLevel,
    required this.source,
  });
}

final List<FloodArea> floodAreas = [
  FloodArea(
    name: "Bandra, Kurla, Saki Naka, Airport area",
    position: LatLng(19.088, 72.8689),
    risk: "High",
    waterLevel: 4.3,
    source: "Mithi River",
  ),
  FloodArea(
    name: "Bandra, Kurla, Saki Naka, Airport area",
    position: LatLng(19.088, 72.8689),
    risk: "High",
    waterLevel: 2.89,
    source: "Mithi River",
  ),
  FloodArea(
    name: "Bandra, Kurla, Saki Naka, Airport area",
    position: LatLng(19.088, 72.8689),
    risk: "High",
    waterLevel: 1.12,
    source: "Mithi River",
  ),
  // ... (add the rest of the generated FloodArea entries here)
];
