import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'flood_areas.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

const String googleApiKey =
    'AIzaSyB-IxMjJ5vUueST8I-kCN1xp0Cr5PedhME'; // <-- Put your API key here

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static final CameraPosition _mumbai = CameraPosition(
    target: LatLng(19.0760, 72.8777),
    zoom: 10,
  );

  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _loadingRoute = false;
  LatLng? _selectedFloodLocation;
  String? _selectedFloodAreaName;
  String? _mapStyle;
  BitmapDescriptor? _pulsingRedIcon;
  Timer? _pulseTimer;
  bool _pulseToggle = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();

    // Add error handling for missing map style
    rootBundle.loadString('assets/map_style.json').then((string) {
      setState(() {
        _mapStyle = string;
      });
    }).catchError((error) {
      print('Error loading map style: $error');
      // Continue without map style
    });

    _loadPulsingIcon();
    _startPulseTimer();
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    // Location permission handling removed for web compatibility
    print('Location permission requested (web mode)');
  }

  Future<LatLng?> _getUserLocation() async {
    // Return Mumbai center as default location for web
    return const LatLng(19.0760, 72.8777);
  }

  Future<void> _showEvacuationRoute() async {
    if (_selectedFloodLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a flood-prone area.')),
      );
      return;
    }
    setState(() => _loadingRoute = true);
    try {
      final origin =
          '${_selectedFloodLocation!.latitude},${_selectedFloodLocation!.longitude}';
      final destination = '19.23324,72.85469'; // Community Hall
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$googleApiKey';
      final response = await http.get(Uri.parse(url));
      print('Directions API response: \n${response.body}');
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        final polylineCoords = _decodePolyline(points);
        print('Polyline points: $polylineCoords');
        setState(() {
          _polylines = {
            Polyline(
              polylineId: PolylineId('evacuation_route'),
              color: Colors.blue,
              width: 6,
              points: polylineCoords,
            ),
          };
          _loadingRoute = false;
        });
        if (_mapController != null && polylineCoords.isNotEmpty) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFromLatLngList(polylineCoords),
              60,
            ),
          );
        }
      } else {
        setState(() => _loadingRoute = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No route found.')));
      }
    } catch (e) {
      setState(() => _loadingRoute = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading route: $e')),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;
    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
  }

  Future<void> _loadPulsingIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/pulse_red.png',
      );
      setState(() {
        _pulsingRedIcon = icon;
      });
    } catch (e) {
      print('Error loading pulsing icon: $e');
      // Continue without custom icon
    }
  }

  void _startPulseTimer() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      setState(() {
        _pulseToggle = !_pulseToggle;
      });
    });
  }

  Set<Marker> getFloodMarkers() {
    try {
      return floodAreas
          .take(200)
          .map(
            (area) => Marker(
              markerId: MarkerId(
                '${area.name}_${area.position.latitude}_${area.position.longitude}',
              ),
              position: area.position,
              icon: area.risk == 'High' && _pulsingRedIcon != null
                  ? (_pulseToggle
                      ? _pulsingRedIcon!
                      : BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ))
                  : BitmapDescriptor.defaultMarkerWithHue(
                      area.risk == 'High'
                          ? BitmapDescriptor.hueRed
                          : area.risk == 'Medium'
                              ? BitmapDescriptor.hueOrange
                              : BitmapDescriptor.hueGreen,
                    ),
              infoWindow: InfoWindow(
                title: area.name,
                snippet:
                    'Risk: ${area.risk}, Water: ${area.waterLevel}m, Source: ${area.source}',
                onTap: () {
                  setState(() {
                    _selectedFloodLocation = area.position;
                    _selectedFloodAreaName = area.name;
                  });
                  _showEvacuationRoute();
                },
              ),
            ),
          )
          .toSet();
    } catch (e) {
      print('Error creating flood markers: $e');
      return {};
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    try {
      if (_mapStyle != null) {
        controller.setMapStyle(_mapStyle);
      }
    } catch (e) {
      print('Error setting map style: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 24.0,
              ),
              child: Text(
                'Flood Map\nCheck risk areas & routes.',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22223B),
                ),
              ),
            ),

            // Map Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                height: 280,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: _mumbai,
                        markers: getFloodMarkers(),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        mapType: MapType.normal,
                        polylines: _polylines,
                        onMapCreated: _onMapCreated,
                      ),
                      if (_loadingRoute)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Color(0xFFB5C7F7),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Finding route...',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: (_loadingRoute || _selectedFloodLocation == null)
                    ? null
                    : _showEvacuationRoute,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Color(0xFFB5C7F7),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.alt_route,
                        color: Color(0xFF22223B),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Show Evacuation Route',
                        style: GoogleFonts.poppins(
                          color: Color(0xFF22223B),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 28),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Text(
                'Flood-Prone Areas',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22223B),
                ),
              ),
            ),

            SizedBox(height: 14),

            // Flood Areas List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
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
                  children: [
                    for (final area in floodAreas.take(5))
                      _DashboardFloodAreaTile(
                        area: area.name,
                        risk: area.risk,
                        color: area.risk == 'High'
                            ? Color(0xFFF9E79F)
                            : area.risk == 'Moderate'
                                ? Color(0xFFD6EAF8)
                                : Color(0xFFB5C7F7),
                        selected: _selectedFloodAreaName == area.name,
                        onTap: () {
                          setState(() {
                            _selectedFloodLocation = area.position;
                            _selectedFloodAreaName = area.name;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 28),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Text(
                'Safety Shelters',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22223B),
                ),
              ),
            ),

            SizedBox(height: 14),

            // Safety Shelters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _DashboardShelterCard(
                      name: 'Community Hall',
                      address: '45 Main St, Mumbai',
                      color: Color(0xFFD6EAF8),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _DashboardShelterCard(
                      name: 'School Gym',
                      address: '12 Park Ave, Mumbai',
                      color: Color(0xFFF9E79F),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _DashboardFloodAreaTile extends StatelessWidget {
  final String area;
  final String risk;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _DashboardFloodAreaTile({
    required this.area,
    required this.risk,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Color(0xFF22223B) : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFF22223B),
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                area,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF22223B),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                risk,
                style: GoogleFonts.poppins(
                  color: Color(0xFF22223B),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardShelterCard extends StatelessWidget {
  final String name;
  final String address;
  final Color color;

  const _DashboardShelterCard({
    required this.name,
    required this.address,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(
            Icons.home_work_rounded,
            color: Color(0xFF22223B),
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Color(0xFF22223B),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 6),
          Text(
            address,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Color(0xFF22223B),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for flood area
class _FloodArea {
  final String name;
  final LatLng position;
  final String risk;
  final Color color;
  const _FloodArea({
    required this.name,
    required this.position,
    required this.risk,
    required this.color,
  });
}
