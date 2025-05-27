import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class RatingsPieChartScreen extends StatefulWidget {
  const RatingsPieChartScreen({Key? key}) : super(key: key);

  @override
  State<RatingsPieChartScreen> createState() => _RatingsPieChartScreenState();
}

class _RatingsPieChartScreenState extends State<RatingsPieChartScreen> {
  int safe = 0;
  int medium = 0;
  int dangerous = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRatingsData();
  }

  Future<void> _fetchRatingsData() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('street_ratings').get();

    int s = 0, m = 0, d = 0;

    for (var doc in snapshot.docs) {
      final rating = (doc['rating'] as num).toDouble();

      if (rating >= 7) {
        s++;
      } else if (rating >= 4) {
        m++;
      } else {
        d++;
      }
    }

    setState(() {
      safe = s;
      medium = m;
      dangerous = d;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = safe + medium + dangerous;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D46),
        title: const Text('Graf ocen', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF9FEFB),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : total == 0
              ? const Center(child: Text('Ni ocenjenih lokacij.'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Razmerje varnostnih ocen',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E7D46),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 320,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              color: Colors.green,
                              value: safe.toDouble(),
                              title:
                                  '${((safe / total) * 100).toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              color: Colors.yellow[700],
                              value: medium.toDouble(),
                              title:
                                  '${((medium / total) * 100).toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              color: Colors.red,
                              value: dangerous.toDouble(),
                              title:
                                  '${((dangerous / total) * 100).toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _legendBox(Colors.green, 'Varne'),
                        _legendBox(Colors.yellow[700]!, 'Srednje'),
                        _legendBox(Colors.red, 'Nevarne'),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _legendBox(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(label),
      ],
    );
  }
}
