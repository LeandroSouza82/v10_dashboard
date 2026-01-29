// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use, unused_local_variable
import 'dart:async';
// DOM manipulation done via `dart:js_util` to avoid deprecated `dart:html`.
import 'dart:js_util' as js_util;

Future<List<Map<String, String>>> fetchPlaceSuggestions(
  String input,
  String apiKey,
) async {
  final google = js_util.getProperty(js_util.globalThis, 'google');
  if (google == null) return [];
  final maps = js_util.getProperty(google, 'maps');
  if (maps == null) return [];
  final places = js_util.getProperty(maps, 'places');
  if (places == null) return [];
  // Prefer new AutocompleteSuggestion API if available, otherwise fall back
  // to the legacy AutocompleteService to remain compatible.
  final suggestionCtor =
      js_util.getProperty(places, 'AutocompleteSuggestion') ??
      js_util.getProperty(places, 'AutocompleteSuggestionService');

  final completer = Completer<List<Map<String, String>>>();

  void callback(predictions, status) {
    if (predictions == null) {
      completer.complete([]);
      return;
    }
    final list = <Map<String, String>>[];
    final len = js_util.getProperty(predictions, 'length') as int?;
    if (len != null) {
      for (var i = 0; i < len; i++) {
        final p = js_util.getProperty(predictions, i);
        final pid = js_util.getProperty(p, 'place_id') as String?;
        final desc = js_util.getProperty(p, 'description') as String?;
        if (pid != null && desc != null) {
          list.add({'place_id': pid, 'description': desc});
        }
      }
    }
    completer.complete(list);
  }

  if (suggestionCtor != null) {
    try {
      final suggestion = js_util.callConstructor(suggestionCtor, []);
      // Try common method names used by different versions of the new API.
      try {
        js_util.callMethod(suggestion, 'getSuggestions', [
          js_util.jsify({
            'input': input,
            'componentRestrictions': {'country': 'br'},
          }),
          js_util.allowInterop(callback),
        ]);
        return completer.future;
      } catch (_) {}
      try {
        js_util.callMethod(suggestion, 'getPlacePredictions', [
          js_util.jsify({
            'input': input,
            'componentRestrictions': {'country': 'br'},
          }),
          js_util.allowInterop(callback),
        ]);
        return completer.future;
      } catch (_) {}
    } catch (_) {
      // fall through to legacy path
    }
  }

  // Legacy fallback: AutocompleteService
  final autocompleteCtor = js_util.getProperty(places, 'AutocompleteService');
  if (autocompleteCtor == null) return [];
  final autocomplete = js_util.callConstructor(autocompleteCtor, []);

  js_util.callMethod(autocomplete, 'getPlacePredictions', [
    js_util.jsify({
      'input': input,
      'componentRestrictions': {'country': 'br'},
    }),
    js_util.allowInterop(callback),
  ]);

  return completer.future;
}

Future<Map<String, dynamic>?> fetchPlaceDetails(
  String placeId,
  String apiKey,
) async {
  final google = js_util.getProperty(js_util.globalThis, 'google');
  if (google == null) return null;
  final maps = js_util.getProperty(google, 'maps');
  if (maps == null) return null;
  final places = js_util.getProperty(maps, 'places');
  if (places == null) return null;

  // PlacesService requires a DOM node. Create/remove it via JS interop
  final document = js_util.getProperty(js_util.globalThis, 'document');
  final body = document != null ? js_util.getProperty(document, 'body') : null;
  final div = js_util.callMethod(document, 'createElement', ['div']);
  js_util.setProperty(js_util.getProperty(div, 'style'), 'display', 'none');
  if (body != null) js_util.callMethod(body, 'appendChild', [div]);
  try {
    final serviceCtor = js_util.getProperty(places, 'PlacesService');
    if (serviceCtor == null) return null;
    final service = js_util.callConstructor(serviceCtor, [div]);
    final completer = Completer<Map<String, dynamic>?>();

    void callback(result, status) {
      if (result == null) {
        completer.complete(null);
        return;
      }
      final formatted =
          js_util.getProperty(result, 'formatted_address') as String?;
      final geometry = js_util.getProperty(result, 'geometry');
      final location = geometry != null
          ? js_util.getProperty(geometry, 'location')
          : null;
      double? lat;
      double? lng;
      if (location != null) {
        final latFn = js_util.getProperty(location, 'lat');
        final lngFn = js_util.getProperty(location, 'lng');
        try {
          final latVal = js_util.callMethod(location, 'lat', []);
          final lngVal = js_util.callMethod(location, 'lng', []);
          lat = (latVal as num).toDouble();
          lng = (lngVal as num).toDouble();
        } catch (_) {}
      }
      completer.complete({'formatted': formatted, 'lat': lat, 'lng': lng});
    }

    js_util.callMethod(service, 'getDetails', [
      js_util.jsify({
        'placeId': placeId,
        'fields': ['formatted_address', 'geometry'],
      }),
      js_util.allowInterop(callback),
    ]);
    return completer.future;
  } finally {
    // remove the temporary div via JS interop
    if (body != null) {
      try {
        js_util.callMethod(body, 'removeChild', [div]);
      } catch (_) {}
    }
  }
}

Future<Map<String, double>?> geocodeAddress(
  String address,
  String apiKey,
) async {
  final google = js_util.getProperty(js_util.globalThis, 'google');
  if (google == null) return null;
  final maps = js_util.getProperty(google, 'maps');
  if (maps == null) return null;
  final geocoderCtor = js_util.getProperty(maps, 'Geocoder');
  if (geocoderCtor == null) return null;
  final geocoder = js_util.callConstructor(geocoderCtor, []);

  final completer = Completer<Map<String, double>?>();

  void callback(results, status) {
    if (results == null) {
      completer.complete(null);
      return;
    }
    final len = js_util.getProperty(results, 'length') as int?;
    if (len == null || len == 0) {
      completer.complete(null);
      return;
    }
    final first = js_util.getProperty(results, 0);
    final geometry = js_util.getProperty(first, 'geometry');
    final location = geometry != null
        ? js_util.getProperty(geometry, 'location')
        : null;
    if (location == null) {
      completer.complete(null);
      return;
    }
    try {
      final latVal = js_util.callMethod(location, 'lat', []);
      final lngVal = js_util.callMethod(location, 'lng', []);
      final lat = (latVal as num).toDouble();
      final lng = (lngVal as num).toDouble();
      completer.complete({'lat': lat, 'lng': lng});
    } catch (_) {
      completer.complete(null);
    }
  }

  js_util.callMethod(geocoder, 'geocode', [
    js_util.jsify({'address': address}),
    js_util.allowInterop(callback),
  ]);
  return completer.future;
}
