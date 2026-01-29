// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<List<int>?> getOptimizedWaypointOrder({
  required String apiKey,
  required String origin,
  required String destination,
  required List<String> waypoints,
}) async {
  final google = js_util.getProperty(js_util.globalThis, 'google');
  if (google == null) return null;
  final maps = js_util.getProperty(google, 'maps');
  if (maps == null) return null;
  final directionsServiceCtor = js_util.getProperty(maps, 'DirectionsService');
  if (directionsServiceCtor == null) return null;
  final service = js_util.callConstructor(directionsServiceCtor, []);

  final completer = Completer<List<int>?>();

  final jsWaypoints = waypoints
      .map((w) => js_util.jsify({'location': w}))
      .toList();

  void callback(result, status) {
    if (result == null) {
      completer.complete(null);
      return;
    }
    final routes = js_util.getProperty(result, 'routes');
    if (routes == null) {
      completer.complete(null);
      return;
    }
    final first = js_util.getProperty(routes, 0);
    final wpOrder = js_util.getProperty(first, 'waypoint_order');
    final len = js_util.getProperty(wpOrder, 'length') as int?;
    if (len == null) {
      completer.complete(null);
      return;
    }
    final list = <int>[];
    for (var i = 0; i < len; i++) {
      final v = js_util.getProperty(wpOrder, i);
      list.add((v as num).toInt());
    }
    completer.complete(list);
  }

  final request = js_util.jsify({
    'origin': origin,
    'destination': destination,
    'waypoints': jsWaypoints,
    'optimizeWaypoints': true,
    'travelMode': js_util.getProperty(
      js_util.getProperty(maps, 'TravelMode'),
      'DRIVING',
    ),
  });

  try {
    js_util.callMethod(service, 'route', [
      request,
      js_util.allowInterop(callback),
    ]);
  } catch (e) {
    completer.complete(null);
  }

  return completer.future;
}
