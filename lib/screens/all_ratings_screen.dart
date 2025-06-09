import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        title: const Text('Vse ocenjene lokacije'),
        actions: [
          Row(
            children: [
              const Text(""),
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
              ? const Center(child: Text('Ni ocenjenih lokacij.'))
              : ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('Ocena: ${data['rating']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Koordinate: (${data['latitude']}, ${data['longitude']})',
                        ),
                        Text('Komentar: ${data['comment'] ?? ""}'),
                        if (data['timestamp'] != null)
                          Text(
                            'Datum: ${(data['timestamp'] as Timestamp).toDate()}',
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
