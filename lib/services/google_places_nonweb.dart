import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

Future<List<Map<String, String>>> fetchPlaceSuggestions(
  String input,
  String apiKey,
) async {
  final query = {'input': input, 'key': apiKey, 'components': 'country:br'};
  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/autocomplete/json',
    query,
  );
  final resp = await http.get(uri);
  if (resp.statusCode != 200) return [];
  final jsonBody = resp.body.isNotEmpty
      ? jsonDecode(resp.body) as Map<String, dynamic>
      : null;
  if (jsonBody == null) return [];
  final preds = (jsonBody['predictions'] as List<dynamic>?) ?? [];
  final list = <Map<String, String>>[];
  for (final p in preds) {
    final pid = (p as Map<String, dynamic>)['place_id'] as String?;
    final desc = p['description'] as String?;
    if (pid != null && desc != null)
      list.add({'place_id': pid, 'description': desc});
  }
  return list;
}

Future<Map<String, dynamic>?> fetchPlaceDetails(
  String placeId,
  String apiKey,
) async {
  final query = {
    'place_id': placeId,
    'key': apiKey,
    'fields': 'formatted_address,geometry',
  };
  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/details/json',
    query,
  );
  final resp = await http.get(uri);
  if (resp.statusCode != 200) return null;
  final jsonBody = resp.body.isNotEmpty
      ? jsonDecode(resp.body) as Map<String, dynamic>
      : null;
  if (jsonBody == null) return null;
  final result = jsonBody['result'] as Map<String, dynamic>?;
  if (result == null) return null;
  final formatted = result['formatted_address'] as String?;
  final location =
      (result['geometry'] as Map<String, dynamic>?)?['location']
          as Map<String, dynamic>?;
  final lat = location != null ? (location['lat'] as num).toDouble() : null;
  final lng = location != null ? (location['lng'] as num).toDouble() : null;
  return {'formatted': formatted, 'lat': lat, 'lng': lng};
}

Future<Map<String, double>?> geocodeAddress(
  String address,
  String apiKey,
) async {
  final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'address': address,
    'key': apiKey,
  });
  final resp = await http.get(uri);
  if (resp.statusCode != 200) return null;
  try {
    final json = resp.body.isNotEmpty
        ? jsonDecode(resp.body) as Map<String, dynamic>
        : null;
    if (json == null) return null;
    if ((json['status'] as String?) != 'OK') return null;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final location =
        (results.first['geometry'] as Map<String, dynamic>)['location']
            as Map<String, dynamic>;
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();
    return {'lat': lat, 'lng': lng};
  } catch (_) {
    return null;
  }
}
