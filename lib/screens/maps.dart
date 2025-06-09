import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'directions_model.dart';
import 'directions_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  bool _showLegendPopup = false;
  TravelMode _travelMode = TravelMode.driving;

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
      double totalScore = 0;
      int activeCriteria = 0;
      Color polylineColor;

      if (_safetyPreference.considerTraffic &&
          _travelMode == TravelMode.driving) {
        totalScore += route.trafficScore;
        activeCriteria++;
      }

      if (_safetyPreference.considerLighting) {
        totalScore += route.lightingScore;
        activeCriteria++;
      }
      if (_safetyPreference.considerUserRatings) {
        totalScore += route.userRatingScore;
        activeCriteria++;
      }

      final averageScore =
          activeCriteria > 0 ? totalScore / activeCriteria : 5.0;

      final isDashed = _travelMode == TravelMode.walking;

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$i'),
          color:
              isSelected
                  ? _getColorForScore(averageScore)
                  : _getColorForScore(averageScore).withOpacity(0.5),
          width: isSelected ? 7 : 2,
          points:
              route.polylinePoints
                  .map((e) => LatLng(e.latitude, e.longitude))
                  .toList(),
          patterns: isDashed ? [PatternItem.dash(10), PatternItem.gap(10)] : [],
        ),
      );
    }
    return polylines;
  }

  Color _getColorForScore(double score) {
    final normalizedScore = score.clamp(1.0, 10.0);

    if (normalizedScore >= 7.0) return Colors.green;
    if (normalizedScore >= 4.0) return Colors.yellow;
    return Colors.red;
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
      travelMode: _travelMode,
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
    if (_selectedRouteIndex >= _directionsList!.routes.length) {
      _selectedRouteIndex = 0;
    }
    return Container(
      color: Colors.white.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButton<int>(
        value: _selectedRouteIndex.clamp(0, _directionsList!.routes.length - 1),
        isExpanded: true,
        items: List.generate(_directionsList!.routes.length, (index) {
          final route = _directionsList!.routes[index];

          double totalScore = 0;
          int activeCriteria = 0;
          String safetyInfo = '';

          if (_safetyPreference.considerTraffic &&
              _travelMode == TravelMode.driving) {
            totalScore += route.trafficScore;
            activeCriteria++;
            safetyInfo += '🚦 ${route.trafficScore.toStringAsFixed(1)} ';
          }

          if (_safetyPreference.considerLighting) {
            totalScore += route.lightingScore;
            activeCriteria++;
            safetyInfo += '💡 ${route.lightingScore.toStringAsFixed(1)} ';
          }
          if (_safetyPreference.considerUserRatings) {
            safetyInfo += '⭐ ${route.userRatingScore.toStringAsFixed(1)}';
          }

          final averageScore =
              activeCriteria > 0 ? totalScore / activeCriteria : 5.0;
          final color = _getColorForScore(averageScore);

          return DropdownMenuItem<int>(
            value: index,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pot ${index + 1}: ${route.totalDistance}, ${route.totalDuration}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(safetyInfo, style: TextStyle(color: color, fontSize: 14)),
              ],
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

  Future<void> _handleLongPress(LatLng pos) async {
    final loc = AppLocalizations.of(context)!;

    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(loc.chooseAction),
            actions: [
              TextButton(
                child: Text(loc.addMarker),
                onPressed: () => Navigator.pop(context, 'marker'),
              ),
              TextButton(
                child: Text(loc.rateStreet),
                onPressed: () => Navigator.pop(context, 'rate'),
              ),
              TextButton(
                child: Text(loc.cancel),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );

    if (action == 'marker') {
      _addMarker(pos, _origin == null);
    } else if (action == 'rate') {
      await _showSimpleRatingDialog(pos);
    }
  }

  Future<void> _showSimpleRatingDialog(LatLng position) async {
    final loc = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);

    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception(loc.streetNotFound);
      }

      final place = placemarks.first;
      final streetName = DirectionsRepository.extractPureStreetName(
        place.street ?? place.thoroughfare,
      );

      int? selectedRating;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(loc.rateStreetSafety),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      streetName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 20),
                    Slider(
                      value: selectedRating?.toDouble() ?? 5.0,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: selectedRating?.toString() ?? '5',
                      onChanged: (value) {
                        setState(() => selectedRating = value.round());
                      },
                    ),
                    SizedBox(height: 10),
                    Text(
                      selectedRating != null
                          ? '${loc.ratingLabel}: $selectedRating/10'
                          : loc.selectRatingWithSlider,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(loc.cancel),
                  ),
                  ElevatedButton(
                    onPressed:
                        selectedRating != null
                            ? () => Navigator.pop(context, true)
                            : null,
                    child: Text(loc.saveRating),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && selectedRating != null) {
        await DirectionsRepository.saveStreetRating(
          streetName,
          selectedRating!,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Napaka: ${e.toString()}'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSafetyLegend() {
    return Positioned(
      bottom: 20,
      left: 10,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showLegendPopup = !_showLegendPopup;
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child:
              _showLegendPopup
                  ? _buildExpandedLegend()
                  : _buildCollapsedLegend(),
        ),
      ),
    );
  }

  Widget _buildCollapsedLegend() {
    final loc = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, color: Colors.blue),
        SizedBox(width: 8),
        Text(loc.legendTitle, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildExpandedLegend() {
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.legendTitle,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _showLegendPopup = false;
                });
              },
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildLegendItem(Colors.green, loc.legendSafe),
        _buildLegendItem(Colors.yellow, loc.legendMedium),
        _buildLegendItem(Colors.red, loc.legendDanger),
        SizedBox(height: 8),
        Text(loc.activeCriteria, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        if (_safetyPreference.considerTraffic &&
            _travelMode == TravelMode.driving)
          _buildLegendItem(Colors.blue, loc.criterionTraffic),
        if (_safetyPreference.considerLighting)
          _buildLegendItem(Colors.amber, loc.criterionLighting),
        if (_safetyPreference.considerUserRatings)
          _buildLegendItem(Colors.purple, loc.criterionUserRatings),
        SizedBox(height: 8),
        Text(
          '${loc.travelModeLabel}: ${_travelMode == TravelMode.driving ? loc.byCar : loc.byWalk}',
          style: TextStyle(fontSize: 12),
        ),
        Text(
          loc.tapToClose,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildSafetyPreferenceDialog() {
    return StatefulBuilder(
      builder: (context, setStateDialog) {
        final loc = AppLocalizations.of(context)!;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.safetySettings,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E7D46),
                  ),
                ),
                SizedBox(height: 20),

                _buildPreferenceSwitch(
                  title: loc.considerLighting,
                  value: _safetyPreference.considerLighting,
                  icon: Icons.lightbulb_outline,
                  onChanged: (value) {
                    setStateDialog(() {
                      _safetyPreference = SafetyPreference(
                        considerLighting: value,
                        considerTraffic: _safetyPreference.considerTraffic,
                        considerUserRatings:
                            _safetyPreference.considerUserRatings,
                      );
                    });
                  },
                ),

                if (_travelMode == TravelMode.driving)
                  _buildPreferenceSwitch(
                    title: loc.considerTraffic,
                    value: _safetyPreference.considerTraffic,
                    icon: Icons.traffic,
                    onChanged: (value) {
                      setStateDialog(() {
                        _safetyPreference = SafetyPreference(
                          considerLighting: _safetyPreference.considerLighting,
                          considerTraffic: value,
                          considerUserRatings:
                              _safetyPreference.considerUserRatings,
                        );
                      });
                    },
                  ),

                _buildPreferenceSwitch(
                  title: loc.considerUserRatings,
                  value: _safetyPreference.considerUserRatings,
                  icon: Icons.star_outline,
                  onChanged: (value) {
                    setStateDialog(() {
                      _safetyPreference = SafetyPreference(
                        considerLighting: _safetyPreference.considerLighting,
                        considerTraffic: _safetyPreference.considerTraffic,
                        considerUserRatings: value,
                      );
                    });
                  },
                ),

                Divider(height: 30, thickness: 1),

                Text(
                  loc.travelMode,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildTravelModeButton(
                        icon: Icons.directions_car,
                        label: loc.byCar,
                        isActive: _travelMode == TravelMode.driving,
                        onTap: () {
                          setStateDialog(() {
                            _travelMode = TravelMode.driving;
                          });
                          if (_origin != null && _destination != null) {
                            _getRouteDirections();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildTravelModeButton(
                        icon: Icons.directions_walk,
                        label: loc.byWalk,
                        isActive: _travelMode == TravelMode.walking,
                        onTap: () {
                          setStateDialog(() {
                            _travelMode = TravelMode.walking;
                          });
                          if (_origin != null && _destination != null) {
                            _getRouteDirections();
                          }
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E7D46),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          if (_origin != null && _destination != null) {
                            _getRouteDirections();
                          }
                        });
                      },
                      child: Text(loc.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreferenceSwitch({
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700], size: 22),
          SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFF1E7D46),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive ? Color(0xFF1E7D46).withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Color(0xFF1E7D46) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Color(0xFF1E7D46) : Colors.grey[600]),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Color(0xFF1E7D46) : Colors.grey[700],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white.withOpacity(0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _originController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterStartLocation,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Row(
            children: [
              Icon(Icons.flag, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterEndLocation,
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
        backgroundColor: const Color(0xFF1E7D46),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        iconTheme: IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SafeSteps',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white, size: 22),
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
          GestureDetector(
            onTap: () {
              if (_showLegendPopup) {
                setState(() {
                  _showLegendPopup = false;
                });
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          _buildSafetyLegend(),
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
              onLongPress: _handleLongPress,
            ),
          _buildSafetyLegend(),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                _buildAddressInput(context),
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
