import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllRatingsScreen extends StatefulWidget {
  const AllRatingsScreen({super.key});

  @override
  State<AllRatingsScreen> createState() => _AllRatingsScreenState();
}

class _AllRatingsScreenState extends State<AllRatingsScreen> {
  bool showOnlyMine = false;
  List<QueryDocumentSnapshot> allDocs = [];
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAllRatings();
  }

  Future<void> _loadAllRatings() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('street_ratings')
            .orderBy('timestamp', descending: true)
            .get();

    setState(() {
      allDocs = snapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Vse ocenjene lokacije',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Row(
            children: [
              const Text("Moje", style: TextStyle(color: Colors.white)),
              Switch(
                value: showOnlyMine,
                onChanged: (val) {
                  setState(() {
                    showOnlyMine = val;
                  });
                },
                activeColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
      body:
          allDocs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : filteredDocs.isEmpty
              ? const Center(child: Text('Ni ocenjenih lokacij.'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp;
                  final date = timestamp.toDate();
                  return ListTile(
                    leading: const Icon(Icons.location_pin, color: Colors.red),
                    title: Text(
                      'Ocena: ${data['rating']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Koordinate: (${data['latitude']}, ${data['longitude']})\n'
                      'Komentar: ${data['comment'] ?? ""}\n'
                      'Datum: $date',
                    ),
                  );
                },
              ),
    );
  }
}
