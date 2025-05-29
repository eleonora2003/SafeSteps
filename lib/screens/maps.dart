import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'directions_model.dart';
import 'directions_repository.dart';

class MapScreenTask extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreenTask> {
  CameraPosition? _initialCameraPosition;
  late GoogleMapController _googleMapController;
  Marker? _origin;
  Marker? _destination;
  DirectionsList? _directionsList;

  // Indeks trenutno izbrane poti, default 0 (prva pot)
  int _selectedRouteIndex = 0;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _initialCameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 14,
      );
    });
  }

  @override
  void dispose() {
    _googleMapController.dispose();
    super.dispose();
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (_origin != null) markers.add(_origin!);
    if (_destination != null) markers.add(_destination!);
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    if (_directionsList == null) return polylines;

    final baseColors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
    ];

    for (int i = 0; i < _directionsList!.routes.length; i++) {
      final route = _directionsList!.routes[i];
      final baseColor = baseColors[i % baseColors.length];
      final isSelected = i == _selectedRouteIndex;

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$i'),
          color: isSelected ? baseColor.shade900 : baseColor.shade100,
          width: isSelected ? 7 : 3,
          points:
              route.polylinePoints
                  .map((e) => LatLng(e.latitude, e.longitude))
                  .toList(),
        ),
      );
    }
    return polylines;
  }

  Future<void> _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          position: pos,
        );
        _destination = null;
        _directionsList = null;
        _selectedRouteIndex = 0;
      });
    } else {
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          position: pos,
        );
      });

      final directionsList = await DirectionsRepository().getDirections(
        origin: _origin!.position,
        destination: pos,
      );

      if (directionsList != null && directionsList.routes.isNotEmpty) {
        setState(() {
          _directionsList = directionsList;
          _selectedRouteIndex = 0; // privzeto prva pot
        });
      }
    }
  }

  // Dropdown menu za izbiro poti
  Widget _buildRouteDropdown() {
    if (_directionsList == null) return SizedBox.shrink();

    return Container(
      color: Colors.white.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButton<int>(
        value: _selectedRouteIndex,
        isExpanded: true,
        items: List.generate(_directionsList!.routes.length, (index) {
          final route = _directionsList!.routes[index];
          final duration = route.totalDuration ?? 'neznano';
          final distance = route.totalDistance ?? 'neznano';
          return DropdownMenuItem<int>(
            value: index,
            child: Text('Pot ${index + 1}: $distance, $duration'),
          );
        }),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedRouteIndex = value;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps - Izbira poti')),
      body: Stack(
        children: [
          if (_initialCameraPosition == null)
            const Center(child: CircularProgressIndicator())
          else
            GoogleMap(
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              initialCameraPosition: _initialCameraPosition!,
              onMapCreated: (controller) => _googleMapController = controller,
              markers: _markers,
              polylines: _buildPolylines(),
              onLongPress: _addMarker,
            ),

          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _buildRouteDropdown(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: () async {
          final position = await Geolocator.getCurrentPosition();
          _googleMapController.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        },
      ),
    );
  }
}
