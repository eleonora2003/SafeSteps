import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'all_ratings_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';

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
  double _avgAllRatings = 0;
  bool _showLegend = false;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadStreetRatings();
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

  Future<void> _loadStreetRatings() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('street_ratings').get();

    final Map<String, List<DocumentSnapshot>> grouped = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitude'];
      final lng = data['longitude'];
      final key = '$lat-$lng';
      grouped.putIfAbsent(key, () => []).add(doc);
    }

    double totalSum = 0;
    int totalCount = 0;

    final Set<Marker> newMarkers =
        grouped.entries
            .map((entry) {
              final docs = entry.value;
              final data = docs.first.data() as Map<String, dynamic>;
              final lat = data['latitude'];
              final lng = data['longitude'];
              final averageRating =
                  docs
                      .map((d) => (d['rating'] as num))
                      .reduce((a, b) => a + b) /
                  docs.length;
              final comment = docs.last['comment'] ?? '';

              totalSum += averageRating;
              totalCount++;

              if (_filter == 'safe' && averageRating < 7) return null;
              if (_filter == 'dangerous' && averageRating >= 7) return null;

              final color =
                  averageRating >= 7
                      ? BitmapDescriptor.hueGreen
                      : averageRating >= 4
                      ? BitmapDescriptor.hueYellow
                      : BitmapDescriptor.hueRed;

              return Marker(
                markerId: MarkerId(entry.key),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: 'Povp. ocena: ${averageRating.toStringAsFixed(1)}',
                  snippet: comment,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(color),
              );
            })
            .whereType<Marker>()
            .toSet();

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
      _avgAllRatings = totalCount > 0 ? totalSum / totalCount : 0;
    });
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
                    "Ocenite lokacijo",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Varnostna ocena (1–10):",
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
                    decoration: const InputDecoration(
                      labelText: "Komentar (neobvezno)",
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
                        _loadStreetRatings();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hvala za vašo oceno!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E7D46),
                      ),
                      child: const Text("Shrani"),
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: _changeFilter,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('Vse lokacije'),
                  ),
                  const PopupMenuItem(
                    value: 'safe',
                    child: Text('Varne lokacije'),
                  ),
                  const PopupMenuItem(
                    value: 'dangerous',
                    child: Text('Nevarne lokacije'),
                  ),
                ],
          ),
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            tooltip: 'Vse ocene',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllRatingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => setState(() => _showLegend = !_showLegend),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Legenda:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text('🟢 Varno (7–10)'),
                            Text('🟡 Srednje (4–6)'),
                            Text('🔴 Nevarno (1–3)'),
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
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          'Povprečna ocena vseh lokacij: ${_avgAllRatings.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
