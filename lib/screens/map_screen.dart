import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'all_ratings_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'maps.dart';
import 'ratings_pie_chart_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';
import 'dart:ui';
import 'package:google_login_app/main.dart';

class MapScreen extends StatefulWidget {
  final Set<Marker>? testMarkers;
  final loc.Location? location;
  final LatLng? initialPosition;
  final bool skipInitialLocation;

  const MapScreen({
    Key? key,
    this.testMarkers,
    this.location,
    this.initialPosition,
    this.skipInitialLocation = false,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  late loc.Location _location;
  LatLng? _currentPosition;
  MapType _mapType = MapType.normal;
  final LatLng _mariborLatLng = const LatLng(46.5547, 15.6459);
  final Set<Marker> _markers = {};
  String _filter = 'all';
  double _avgAllRatings = 0;
  bool _showLegend = false;
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  MapScreenState() : _location = loc.Location();

  @override
  void initState() {
    super.initState();
    _location = widget.location ?? loc.Location();
    _currentPosition = widget.initialPosition;
    if (_currentPosition == null && !widget.skipInitialLocation) {
      _setInitialLocation();
    }
    _loadStreetRatings();
  }

  Future<void> _setInitialLocation() async {
    final hasPermission = await _location.hasPermission();
    if (hasPermission == loc.PermissionStatus.denied ||
        hasPermission == loc.PermissionStatus.deniedForever) {
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

  Future<void> _sendEmergencyMessage() async {
    try {
      final locData = await _location.getLocation();
      final lat = locData.latitude;
      final lng = locData.longitude;

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'teodorakrunic2004@gmail.com',
        query: Uri.encodeFull(
          'subject=🚨 SOS Pomoč&body=Hitno! Moja trenutna lokacija je: https://maps.google.com/?q=$lat,$lng',
        ),
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        _showToast("❌ Ne može se otvoriti email klijent.");
      }
    } catch (e) {
      _showToast("❌ Došlo je do greške pri slanju SOS poruke.");
    }
  }

  Future<void> _searchAndNavigate() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<geo.Location> locations = await geo.locationFromAddress(query);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);

        mapController.animateCamera(CameraUpdate.newLatLngZoom(target, 16));

        setState(() {
          _markers.add(
            Marker(
              markerId: const MarkerId('search_location'),
              position: target,
              infoWindow: InfoWindow(title: 'Iskano mesto', snippet: query),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          );
        });
      } else {
        _showToast('Naslov ni bil najden.');
      }
    } catch (e) {
      _showToast('Napaka pri iskanju naslova.');
    }
  }

  Future<void> _loadStreetRatings() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('street_ratings').get();

      final Map<String, List<DocumentSnapshot>> grouped = {};
      double totalSum = 0;
      int totalCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['latitude'] == null || data['longitude'] == null) continue;

        final lat = data['latitude'] as double;
        final lng = data['longitude'] as double;
        final key = '$lat-$lng';
        grouped.putIfAbsent(key, () => []).add(doc);
      }

      final Set<Marker> newMarkers = {};

      grouped.forEach((key, docs) {
        final data = docs.first.data() as Map<String, dynamic>;
        final lat = data['latitude'] as double;
        final lng = data['longitude'] as double;
        final averageRating =
            docs
                .map((d) => (d['rating'] as num).toDouble())
                .reduce((a, b) => a + b) /
            docs.length;
        final comment = docs.last['comment'] ?? '';

        totalSum += averageRating;
        totalCount++;

        if (_filter == 'safe' && averageRating < 7) return;
        if (_filter == 'dangerous' && averageRating >= 7) return;

        final color =
            averageRating >= 7
                ? BitmapDescriptor.hueGreen
                : averageRating >= 4
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueRed;

        newMarkers.add(
          Marker(
            markerId: MarkerId(key),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: 'Povp. ocena: ${averageRating.toStringAsFixed(1)}',
              snippet: comment.isNotEmpty ? comment : 'Brez komentarja',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(color),
          ),
        );
      });

      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _avgAllRatings = totalCount > 0 ? totalSum / totalCount : 0;
      });
    } catch (e) {
      print('Error loading street ratings: $e');
      _showToast('Napaka pri nalaganju ocen');
    }
  }

  void _changeFilter(String filter) {
    setState(() {
      _filter = filter;
    });
    _loadStreetRatings();
  }

  void _openRatingDialog(LatLng latlng) {
    TextEditingController _controller = TextEditingController();
    int rating = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Wrap(
                children: [
                  Text(
                    AppLocalizations.of(context)!.rateLocation,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context)!.ratingLabelSlider,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  Slider(
                    value: rating.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: rating.toString(),
                    onChanged:
                        (value) => setModalState(() => rating = value.toInt()),
                  ),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.commentOptional,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await FirebaseFirestore.instance
                            .collection('street_ratings')
                            .add({
                              'latitude': latlng.latitude,
                              'longitude': latlng.longitude,
                              'rating': rating,
                              'comment': _controller.text,
                              'timestamp': Timestamp.now(),
                              'uid': currentUser?.uid ?? '',
                            });
                        await _loadStreetRatings();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.thankYou,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E7D46),
                      ),
                      child: Text(AppLocalizations.of(context)!.save),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveRating(LatLng latlng, int rating, String comment) async {
    try {
      await FirebaseFirestore.instance.collection('street_ratings').add({
        'latitude': latlng.latitude,
        'longitude': latlng.longitude,
        'rating': rating,
        'comment': comment,
        'timestamp': Timestamp.now(),
        'uid': currentUser?.uid ?? '',
      });

      await _loadStreetRatings();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hvala za vašo oceno!')));
    } catch (e) {
      _showToast('Napaka pri shranjevanju ocene.');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FEFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D46),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
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
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 22,
                  ),
                  onSelected: _changeFilter,
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'all',
                          child: Text(AppLocalizations.of(context)!.filterAll),
                        ),
                        PopupMenuItem(
                          value: 'safe',
                          child: Text(AppLocalizations.of(context)!.filterSafe),
                        ),
                        PopupMenuItem(
                          value: 'dangerous',
                          child: Text(
                            AppLocalizations.of(context)!.filterDangerous,
                          ),
                        ),
                      ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.list_alt,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Vse ocene',
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AllRatingsScreen(
                                firestore: FirebaseFirestore.instance,
                                auth: FirebaseAuth.instance,
                              ),
                        ),
                      ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _showLegend = !_showLegend),
                ),
                SizedBox(
                  width: 42,
                  child: IconButton(
                    icon: const Icon(
                      Icons.pie_chart,
                      color: Colors.white,
                      size: 22,
                    ),
                    tooltip: 'Graf ocen',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => RatingsPieChartScreen(
                                firestore: FirebaseFirestore.instance,
                              ),
                        ),
                      );
                    },
                  ),

                  // IconButton(
                  //   icon: const Icon(Icons.info_outline, color: Colors.white),
                  //   onPressed: () => setState(() => _showLegend = !_showLegend),
                  // ),
                ),
              ],
            ),
          ),
        ],
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
                    onLongPress: _openRatingDialog,
                    markers: _markers,
                  ),

                  Positioned(
                    top: 20,
                    left: 15,
                    right: 15,
                    child: Container(
                      key: const Key('search_bar_container'),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(blurRadius: 4, color: Colors.black26),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    AppLocalizations.of(context)!.searchHint,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchAndNavigate,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showLegend)
                    Positioned(
                      top: 60,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.legend,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text("🟢 ${AppLocalizations.of(context)!.safe}"),
                            Text("🟡 ${AppLocalizations.of(context)!.medium}"),
                            Text("🔴 ${AppLocalizations.of(context)!.danger}"),
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
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        onPressed: _sendEmergencyMessage,

                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.sos, color: Colors.white),
                        label: const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  Positioned(
                    bottom: 220,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF1E7D46),
                      child: const Icon(Icons.directions, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MapScreenTask()),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
