// datoteka: all_ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllRatingsScreen extends StatelessWidget {
  const AllRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      ),
      body: FutureBuilder(
        future:
            FirebaseFirestore.instance
                .collection('street_ratings')
                .orderBy('timestamp', descending: true)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Ni ocenjenih lokacij.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
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
          );
        },
      ),
    );
  }
}
