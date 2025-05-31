import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
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
  int _selectedRouteIndex = 0;

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  bool _isLoading = false;

  SafetyPreference _safetyPreference = SafetyPreference();
  String _currentSearchTerm = '';

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

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (_origin != null) markers.add(_origin!);
    if (_destination != null) markers.add(_destination!);
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    if (_directionsList == null) return polylines;

    for (int i = 0; i < _directionsList!.routes.length; i++) {
      final route = _directionsList!.routes[i];
      final isSelected = i == _selectedRouteIndex;

      Color polylineColor;
      if (_safetyPreference.considerLighting) {
        polylineColor = _getColorForScore(route.lightingScore);
      } else if (_safetyPreference.considerTraffic) {
        polylineColor = _getColorForScore(route.trafficScore);
      } else {
        polylineColor = _getColorForScore(route.userRatingScore);
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$i'),
          color: isSelected ? polylineColor : polylineColor.withOpacity(0.5),
          width: isSelected ? 6 : 3,
          points:
              route.polylinePoints
                  .map((e) => LatLng(e.latitude, e.longitude))
                  .toList(),
        ),
      );
    }
    return polylines;
  }

  Color _getColorForScore(double score) {
    if (_safetyPreference.considerTraffic) {
      // Posebna logika za promet
      if (score >= 7.5) return Colors.green;
      if (score >= 5.0) return Colors.yellow;
      return Colors.red;
    } else {
      // Originalna logika za druge faktorje
      if (score >= 7.5) return Colors.green;
      if (score >= 5.0) return Colors.orange;
      return Colors.red;
    }
  }

  Future<void> _addMarker(LatLng pos, bool isOrigin) async {
    setState(() {
      if (isOrigin || _origin == null) {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Začetna lokacija'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          position: pos,
        );
        if (!isOrigin) _destination = null;
      } else {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Končna lokacija'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          position: pos,
        );
      }

      _directionsList = null;
      _selectedRouteIndex = 0;
    });

    // Get address from coordinates
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final place = placemarks.first;
      final address = "${place.street ?? ''}, ${place.locality ?? ''}".trim();

      setState(() {
        if (isOrigin) {
          _originController.text =
              address.isNotEmpty
                  ? address
                  : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        } else {
          _destinationController.text =
              address.isNotEmpty
                  ? address
                  : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
      });
    } catch (e) {
      print('Reverse geocoding failed: $e');
      setState(() {
        if (isOrigin) {
          _originController.text =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        } else {
          _destinationController.text =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
      });
    }

    if (!isOrigin && _origin != null) {
      await _getRouteDirections();
    }
  }

  Future<void> _getRouteDirections() async {
    if (_origin == null || _destination == null) return;

    setState(() => _isLoading = true);

    final directionsList = await DirectionsRepository().getDirections(
      origin: _origin!.position,
      destination: _destination!.position,
      preference: _safetyPreference,
    );

    if (directionsList != null && directionsList.routes.isNotEmpty) {
      setState(() {
        _directionsList = directionsList;
        _googleMapController.animateCamera(
          CameraUpdate.newLatLngBounds(_directionsList!.routes[0].bounds, 100),
        );
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _searchLocation(bool isOrigin) async {
    final address =
        isOrigin ? _originController.text : _destinationController.text;
    if (address.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentSearchTerm = address;
    });

    final location = await DirectionsRepository().getLocationFromAddress(
      address,
    );
    if (location != null) {
      await _addMarker(location, isOrigin);

      if (isOrigin) {
        _originController.text = _currentSearchTerm;
      } else {
        _destinationController.text = _currentSearchTerm;
      }

      if (!isOrigin && _origin != null) {
        await _getRouteDirections();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not found: $_currentSearchTerm')),
      );
    }

    setState(() => _isLoading = false);
  }

  Widget _buildRouteDropdown() {
    if (_directionsList == null) return const SizedBox.shrink();

    return Container(
      color: Colors.white.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButton<int>(
        value: _selectedRouteIndex,
        isExpanded: true,
        items: List.generate(_directionsList!.routes.length, (index) {
          final route = _directionsList!.routes[index];
          String safetyInfo = '';

          if (_safetyPreference.considerLighting) {
            safetyInfo +=
                'Osvetlitev: ${route.lightingScore.toStringAsFixed(1)} ';
          }
          if (_safetyPreference.considerTraffic) {
            safetyInfo += 'Promet: ${route.trafficScore.toStringAsFixed(1)} ';
          }
          if (_safetyPreference.considerUserRatings) {
            safetyInfo += 'Ocena: ${route.userRatingScore.toStringAsFixed(1)}';
          }

          return DropdownMenuItem<int>(
            value: index,
            child: Text(
              'Pot ${index + 1}: ${route.totalDistance}, ${route.totalDuration}\n$safetyInfo',
            ),
          );
        }),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedRouteIndex = value);
        },
      ),
    );
  }

  Widget _buildSafetyPreferenceDialog() {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Varnostne nastavitve'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Upoštevajte osvetlitev'),
                  value: _safetyPreference.considerLighting,
                  onChanged: (value) {
                    setState(() {
                      _safetyPreference = SafetyPreference(
                        considerLighting: value,
                        considerTraffic: _safetyPreference.considerTraffic,
                        considerUserRatings:
                            _safetyPreference.considerUserRatings,
                      );
                    });
                  },
                ),
                SwitchListTile(
                  title: Text('Upoštevajte promet'),
                  value: _safetyPreference.considerTraffic,
                  onChanged: (value) {
                    setState(() {
                      _safetyPreference = SafetyPreference(
                        considerLighting: _safetyPreference.considerLighting,
                        considerTraffic: value,
                        considerUserRatings:
                            _safetyPreference.considerUserRatings,
                      );
                    });
                  },
                ),
                SwitchListTile(
                  title: Text('Upoštevajte ocene uporabnikov'),
                  value: _safetyPreference.considerUserRatings,
                  onChanged: (value) {
                    setState(() {
                      _safetyPreference = SafetyPreference(
                        considerLighting: _safetyPreference.considerLighting,
                        considerTraffic: _safetyPreference.considerTraffic,
                        considerUserRatings: value,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Prekliči'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (_origin != null && _destination != null) {
                  _getRouteDirections();
                }
              },
              child: Text('Shrani'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddressInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white.withOpacity(0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _originController,
                  decoration: InputDecoration(
                    hintText: 'Vnesi začetno lokacijo (e.g., Ljubljana)',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 1),
          Row(
            children: [
              Icon(Icons.flag, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    hintText: 'Vnesi končno lokacijo (e.g., Maribor)',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _startNavigation,
            icon: Icon(Icons.directions),
            label: Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNavigation() async {
    final originAddress = _originController.text.trim();
    final destinationAddress = _destinationController.text.trim();

    if (originAddress.isEmpty || destinationAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both origin and destination')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final originLocation = await DirectionsRepository().getLocationFromAddress(
      originAddress,
    );
    final destinationLocation = await DirectionsRepository()
        .getLocationFromAddress(destinationAddress);

    if (originLocation == null || destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('One or both locations could not be found')),
      );
      setState(() => _isLoading = false);
      return;
    }

    await _addMarker(originLocation, true);
    await _addMarker(destinationLocation, false);

    await _getRouteDirections();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps - Izbira poti'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed:
                () => showDialog(
                  context: context,
                  builder: (context) => _buildSafetyPreferenceDialog(),
                ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_initialCameraPosition == null)
            Center(child: CircularProgressIndicator())
          else
            GoogleMap(
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              initialCameraPosition: _initialCameraPosition!,
              onMapCreated: (controller) => _googleMapController = controller,
              markers: _markers,
              polylines: _buildPolylines(),
              onLongPress: (pos) => _addMarker(pos, _origin == null),
            ),

          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                _buildAddressInput(),
                SizedBox(height: 10),
                _buildRouteDropdown(),
              ],
            ),
          ),

          if (_isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'btn1',
            child: Icon(Icons.my_location),
            onPressed: () async {
              final position = await Geolocator.getCurrentPosition();
              _googleMapController.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(position.latitude, position.longitude),
                ),
              );
            },
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'btn2',
            child: Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _origin = null;
                _destination = null;
                _directionsList = null;
                _originController.clear();
                _destinationController.clear();
              });
            },
          ),
        ],
      ),
    );
  }
}
