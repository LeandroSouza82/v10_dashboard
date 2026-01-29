// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

/// Creates a JS marker for web using AdvancedMarkerElement when available.
/// Returns the JS marker object (not a Flutter Marker).
dynamic createJsMarker({
  required double lat,
  required double lng,
  String? title,
}) {
  final google = js_util.getProperty(js_util.globalThis, 'google');
  if (google == null) return null;
  final maps = js_util.getProperty(google, 'maps');
  if (maps == null) return null;

  // Prefer the AdvancedMarkerElement from the marker module
  final advCtor = js_util.getProperty(
    js_util.getProperty(maps, 'marker') ?? maps,
    'AdvancedMarkerElement',
  );
  if (advCtor != null) {
    final position = js_util.jsify({'lat': lat, 'lng': lng});
    final options = js_util.jsify({'position': position, 'title': title ?? ''});
    try {
      final adv = js_util.callConstructor(advCtor, [options]);
      return adv;
    } catch (_) {
      // ignore and fallback
    }
  }

  // Fallback to legacy Marker
  final markerCtor = js_util.getProperty(maps, 'Marker');
  if (markerCtor == null) return null;
  final opts = js_util.jsify({
    'position': js_util.jsify({'lat': lat, 'lng': lng}),
    'title': title ?? '',
  });
  try {
    final marker = js_util.callConstructor(markerCtor, [opts]);
    return marker;
  } catch (_) {
    return null;
  }
}
