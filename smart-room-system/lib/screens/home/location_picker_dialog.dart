import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  @override
  _LocationPickerDialogState createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  // Fixed starting location (KU Gate)
  static const LatLng _fixedStartLocation = LatLng(27.620569, 85.538304);

  LatLng? _selectedLatLng; // Current user location or selected location
  bool _isLoading = true;
  String? _locationAddress;
  String _errorMessage = '';

  // Navigation Info
  String _walkTime = "0 min";
  String _distance = "0.00 km";

  // Map type control
  MapType _currentMapType = MapType.normal;

  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied permanently';
          _isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLatLng = LatLng(position.latitude, position.longitude);
        _isLoading = false;
        _locationAddress = _formatCoordinates(position.latitude, position.longitude);
        _updateMarkers();
      });

      // Draw initial polyline from fixed location to current location
      _fetchWalkingPath(_selectedLatLng!);

      // Automatically center on the fixed starting location initially
      if (_mapController != null) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_fixedStartLocation, 15),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  // --- OSRM Walking Logic ---
  Future<void> _fetchWalkingPath(LatLng destination) async {
    setState(() {
      _polylines.clear(); // Clear previous polylines
    });

    final url = 'https://router.project-osrm.org/route/v1/foot/'
        '${_fixedStartLocation.longitude},${_fixedStartLocation.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];

        double distMeters = route['distance'].toDouble();
        double mins = (distMeters / 80) * 1.1;

        final coords = route['geometry']['coordinates'] as List;
        List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();

        // Ensure polyline starts exactly from fixed location and ends exactly at destination
        points.insert(0, _fixedStartLocation);
        points.add(destination);

        setState(() {
          _distance = "${(distMeters / 1000).toStringAsFixed(2)} km";
          _walkTime = "${mins.round()} min";

          _polylines.add(Polyline(
            polylineId: const PolylineId("walk_path"),
            points: points,
            color: const Color(0xFF667EEA),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(10), PatternItem.gap(5)],
          ));
        });
      }
    } catch (e) {
      debugPrint("OSRM Error: $e");
      setState(() {
        _distance = "0.00 km";
        _walkTime = "0 min";
      });
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLatLng = location;
      _locationAddress = _formatCoordinates(location.latitude, location.longitude);
      _updateMarkers();
    });

    // Draw new polyline from fixed location to tapped location
    _fetchWalkingPath(location);
  }

  void _updateMarkers() {
    // Clear all markers
    _markers.clear();

    // Add fixed start location marker (KU Gate)
    _markers.add(Marker(
      markerId: const MarkerId('fixed_start'),
      position: _fixedStartLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'KU Gate (Fixed Starting Point)',
        snippet: 'Kathmandu University Main Gate',
        onTap: () {
          _showMarkerInfo('KU Gate', 'Fixed Starting Location\n27.620569° N, 85.538304° E');
        },
      ),
    ));

    if (_selectedLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('selected'),
        position: _selectedLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Selected Location',
          snippet: _formatCoordinates(_selectedLatLng!.latitude, _selectedLatLng!.longitude),
          onTap: () {
            _showMarkerInfo('Your Location', _formatCoordinates(_selectedLatLng!.latitude, _selectedLatLng!.longitude));
          },
        ),
      ));
    }
  }

  void _showMarkerInfo(String title, String details) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                details,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Close",
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCoordinates(double lat, double lng) =>
      '${lat.abs().toStringAsFixed(6)}° ${lat >= 0 ? 'N' : 'S'}, ${lng.abs().toStringAsFixed(6)}° ${lng >= 0 ? 'E' : 'W'}';

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  Future<void> _goToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLatLng = currentLocation;
        _locationAddress = _formatCoordinates(position.latitude, position.longitude);
        _updateMarkers();
      });

      // Recalculate polyline to new current location
      _fetchWalkingPath(currentLocation);

      // Center map on the midpoint between fixed location and current location
      double midLat = (_fixedStartLocation.latitude + currentLocation.latitude) / 2;
      double midLng = (_fixedStartLocation.longitude + currentLocation.longitude) / 2;

      await _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(midLat, midLng), 14),
      );
    } catch (e) {
      debugPrint("Error getting current location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        height: screenHeight * 0.95,
        width: screenWidth,
        margin: EdgeInsets.only(top: screenHeight * 0.05),
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildMapView(),
                    const SizedBox(height: 12),
                    _buildLocationInfo(isSmallScreen),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              radius: 18,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                "Pick Destination",
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ).createShader(
                      const Rect.fromLTWH(0, 0, 200, 70),
                    ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        Container(
          height: 400,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _fixedStartLocation,
                zoom: 15,
              ),
              onMapCreated: (c) {
                if (!_controller.isCompleted) _controller.complete(c);
                _mapController = c;

                // Draw initial polyline once map is ready
                if (_selectedLatLng != null) {
                  _fetchWalkingPath(_selectedLatLng!);
                }
              },
              onTap: _onMapTap,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: _currentMapType,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 36,
          child: Column(
            children: [
              // Map Type Toggle Button
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _toggleMapType,
                  icon: Icon(
                    _currentMapType == MapType.satellite
                        ? Icons.public
                        : Icons.satellite_alt_rounded,
                    color: _currentMapType == MapType.satellite
                        ? const Color(0xFF667EEA)
                        : Colors.grey.shade700,
                    size: 20,
                  ),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
              // Current Location Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _goToCurrentLocation,
                  icon: const Icon(
                    Icons.my_location,
                    color: Color(0xFF667EEA),
                    size: 20,
                  ),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_locationAddress != null)
                        Text(
                          _locationAddress!,
                          style: GoogleFonts.quicksand(
                            fontSize: isSmallScreen ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.shade200,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _compactInfoTile(
                  Icons.directions_walk_rounded,
                  "Distance",
                  _distance,
                  const Color(0xFF667EEA),
                  isSmallScreen,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _compactInfoTile(
                  Icons.timer_outlined,
                  "Time",
                  _walkTime,
                  const Color(0xFFFF5722),
                  isSmallScreen,
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.shade200,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _compactOutlinedButton(
                    "Cancel",
                    Colors.grey.shade700,
                    Icons.cancel_outlined,
                        () => Navigator.pop(context),
                    isSmallScreen,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Expanded(
                  child: _compactGradientButton(
                    "Confirm",
                    [const Color(0xFF2C3E50), const Color(0xFF3498DB)],
                    Icons.verified_rounded,
                        () {
                      if (_selectedLatLng != null) {
                        Navigator.pop(context, {
                          'address': _locationAddress,
                          'latitude': _selectedLatLng!.latitude,
                          'longitude': _selectedLatLng!.longitude,
                          'distance': _distance,
                          'walkTime': _walkTime,
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    isSmallScreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfoTile(IconData icon, String label, String value, Color color, bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: isSmallScreen ? 10 : 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  Widget _compactGradientButton(String text, List<Color> colors, IconData icon, VoidCallback onTap, bool isSmallScreen) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isSmallScreen ? 36 : 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: isSmallScreen ? 14 : 16),
            SizedBox(width: isSmallScreen ? 4 : 6),
            Text(
              text,
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactOutlinedButton(String text, Color color, IconData icon, VoidCallback onTap, bool isSmallScreen) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isSmallScreen ? 36 : 38,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 14 : 16),
            SizedBox(width: isSmallScreen ? 4 : 6),
            Text(
              text,
              style: GoogleFonts.quicksand(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}