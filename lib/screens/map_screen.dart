import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final Location _location = Location();
  LatLng? _currentPosition;
  MapType _mapType = MapType.normal;
  final LatLng _mariborLatLng = const LatLng(46.5547, 15.6459);
  final Set<Marker> _markers = {};
  String _filter = 'all';
  bool _showLegend = false;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    final hasPermission = await _location.hasPermission();
    if (hasPermission == PermissionStatus.denied ||
        hasPermission == PermissionStatus.deniedForever) {
      await _location.requestPermission();
    }

    try {
      final locationData = await _location.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;

      if (lat != null && lng != null) {
        setState(() {
          _currentPosition = LatLng(lat, lng);
        });
      } else {
        setState(() {
          _currentPosition = _mariborLatLng;
        });
      }
    } catch (e) {
      setState(() {
        _currentPosition = _mariborLatLng;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FEFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D46),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              'SafeSteps Mapa',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body:
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) {
                      mapController = controller;
                      mapController.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: _currentPosition!, zoom: 15),
                        ),
                      );
                    },
                    initialCameraPosition: CameraPosition(
                      target: _mariborLatLng,
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    mapType: _mapType,
                    markers: _markers,
                  ),

                  if (_showLegend)
                    Positioned(
                      top: 90,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(blurRadius: 4, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 30,
                    left: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFF1E7D46),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 100,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF1E7D46),
                      child: const Icon(Icons.map, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _mapType =
                              _mapType == MapType.normal
                                  ? MapType.satellite
                                  : MapType.normal;
                        });
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 160,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF1E7D46),
                      child: const Icon(Icons.my_location, color: Colors.white),
                      onPressed: () {
                        if (_currentPosition != null) {
                          mapController.animateCamera(
                            CameraUpdate.newLatLng(_currentPosition!),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
