import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OSMRepository {
  final Dio _dio = Dio();

  Future<double> getLightingScoreForLocation(LatLng position) async {
    const radius = 100;
    final query = '''
      [out:json];
      (
        way(around:$radius,${position.latitude},${position.longitude})["highway"];
        node(around:$radius,${position.latitude},${position.longitude})[amenity=street_lamp];
        node(around:$radius,${position.latitude},${position.longitude})[highway=street_lamp];
        way(around:$radius,${position.latitude},${position.longitude})["lit"];
      );
      out body;
      >;
      out skel qt;
    ''';

    try {
      final response = await _dio.get(
        'https://overpass-api.de/api/interpreter',
        queryParameters: {'data': query},
      );

      final elements = response.data['elements'] as List;

      // 1. Check explicit lighting tags
      final explicitLighting =
          elements.where((element) {
            final tags = element['tags'] ?? {};
            return tags['lit'] == 'yes' ||
                tags['lighting'] == 'yes' ||
                tags['light'] == 'yes';
          }).length;

      // 2. Check street lamps
      final streetLamps =
          elements.where((element) {
            final tags = element['tags'] ?? {};
            return tags['amenity'] == 'street_lamp' ||
                tags['highway'] == 'street_lamp';
          }).length;

      // 3. Check road type
      final isMainRoad = elements.any((element) {
        final highway = element['tags']?['highway']?.toString();
        return highway == 'primary' ||
            highway == 'secondary' ||
            highway == 'tertiary';
      });

      // 4. Check number of lanes
      final lanes = elements.fold<int>(0, (sum, element) {
        final lanes =
            int.tryParse(element['tags']?['lanes']?.toString() ?? '0') ?? 0;
        return sum + lanes;
      });

      // Calculate base score
      double score = 5.0;

      if (explicitLighting > 0) {
        score += 2.0;
      }

      if (streetLamps > 0) {
        score += streetLamps * 0.5;
      }

      if (isMainRoad) {
        score += 1.5;
      }

      if (lanes >= 2) {
        score += 1.0;
      }

      return score.clamp(1.0, 10.0);
    } catch (e) {
      print('Error fetching OSM data: $e');
      return 5.0;
    }
  }
}
