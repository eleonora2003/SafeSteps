import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RatingsPieChartScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  const RatingsPieChartScreen({Key? key, required this.firestore})
    : super(key: key);

  @override
  State<RatingsPieChartScreen> createState() => _RatingsPieChartScreenState();
}

class _RatingsPieChartScreenState extends State<RatingsPieChartScreen> {
  int safeChart = 0;
  int mediumChart = 0;
  int dangerousChart = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRatingsData();
  }

  Future<void> _fetchRatingsData() async {
    final snapshot = await widget.firestore.collection('street_ratings').get();

    int s = 0, m = 0, d = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      if (data.containsKey('rating')) {
        final rating = (data['rating'] as num).toDouble();

        if (rating >= 7) {
          s++;
        } else if (rating >= 4) {
          m++;
        } else {
          d++;
        }
      } else {
        print('⚠️ Dokument ${doc.id} nima polja "rating".');
      }
    }

    setState(() {
      safeChart = s;
      mediumChart = m;
      dangerousChart = d;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context);
    final total = safeChart + mediumChart + dangerousChart;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D46),
        title: Text(
          local?.chartTitle ?? 'Graf ocen',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF9FEFB),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : total == 0
              ? Center(child: Text(local?.noRatings ?? 'Ni ocenjenih lokacij.'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      local?.chartSubtitle ?? 'Porazdelitev ocen',
                      style: const TextStyle(
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
                              value: safeChart.toDouble(),
                              title:
                                  '${((safeChart / total) * 100).toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              color: Colors.yellow[700],
                              value: mediumChart.toDouble(),
                              title:
                                  '${((mediumChart / total) * 100).toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              color: Colors.red,
                              value: dangerousChart.toDouble(),
                              title:
                                  '${((dangerousChart / total) * 100).toStringAsFixed(1)}%',
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
                        _legendBox(Colors.green, local?.safeChart ?? 'Varno'),
                        _legendBox(
                          Colors.yellow[700]!,
                          local?.mediumChart ?? 'Srednje',
                        ),
                        _legendBox(Colors.red, local?.dangerChart ?? 'Nevarno'),
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
