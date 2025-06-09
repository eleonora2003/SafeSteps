import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AllRatingsScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const AllRatingsScreen({
    Key? key,
    required this.firestore,
    required this.auth,
  }) : super(key: key);

  @override
  _AllRatingsScreenState createState() => _AllRatingsScreenState();
}

class _AllRatingsScreenState extends State<AllRatingsScreen> {
  bool showOnlyMine = false;
  List<QueryDocumentSnapshot> allDocs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllRatings();
  }

  Future<void> _loadAllRatings() async {
    try {
      final snapshot =
          await widget.firestore
              .collection('street_ratings')
              .orderBy('timestamp', descending: true)
              .get();

      setState(() {
        allDocs = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.auth.currentUser;
    final loc = AppLocalizations.of(context)!;

    final filteredDocs =
        showOnlyMine
            ? allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data.containsKey('uid') && data['uid'] == currentUser?.uid;
            }).toList()
            : allDocs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D46),
        title: Text(
          loc.allRatingsTitle,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Row(
            children: [
              Text(loc.onlyMine, style: const TextStyle(color: Colors.white)),
              Switch(
                value: showOnlyMine,
                onChanged: (val) => setState(() => showOnlyMine = val),
              ),
            ],
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredDocs.isEmpty
              ? Center(child: Text(loc.noRatings))
              : ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('${loc.ratingLabel}: ${data['rating']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.coordinatesLabel}: (${data['latitude']}, ${data['longitude']})',
                        ),
                        Text('${loc.commentLabel}: ${data['comment'] ?? ""}'),
                        if (data['timestamp'] != null)
                          Text(
                            '${loc.dateLabel}: ${(data['timestamp'] as Timestamp).toDate()}',
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
