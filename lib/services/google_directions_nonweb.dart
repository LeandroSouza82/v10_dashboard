import 'dart:convert';
import 'package:http/http.dart' as http;

/* Calls Google Directions REST API and returns waypoint_order as List<int> */
Future<List<int>?> getOptimizedWaypointOrder({
  required String apiKey,
  required String origin,
  required String destination,
  required List<String> waypoints, // list of 'lat,lng' strings
}) async {
  try {
    final wp = ['optimize:true', ...waypoints].join('|');
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': origin,
      'destination': destination,
      'waypoints': wp,
      'key': apiKey,
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final wpOrder = (route['waypoint_order'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    return wpOrder;
  } catch (e) {
    return null;
  }
}
