// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter
// Use dart:js_util to access global JS functions without importing dart:html
import 'dart:js_util' as js_util;

dynamic callCreateAdvancedMarker(String id, String content, double lat, double lng) {
  try {
    final win = js_util.globalThis;
    final fn = js_util.getProperty(win, 'createAdvancedMarker');
    if (fn != null) {
      return js_util.callMethod(win, 'createAdvancedMarker', [id, content, lat, lng]);
    }
  } catch (e) {
    // Log the error so analyzer doesn't complain about empty catches
    try {
      // use print to avoid importing flutter packages in this web-only file
      print('callCreateAdvancedMarker error: $e');
    } catch (_) {}
  }
  return null;
}

dynamic callUpdateAdvancedMarkerPosition(String id, double lat, double lng) {
  try {
    final win = js_util.globalThis;
    final fn = js_util.getProperty(win, 'updateAdvancedMarkerPosition');
    if (fn != null) {
      return js_util.callMethod(win, 'updateAdvancedMarkerPosition', [id, lat, lng]);
    }
  } catch (e) {
    try {
      print('callUpdateAdvancedMarkerPosition error: $e');
    } catch (_) {}
  }
  return null;
}

dynamic callRemoveAdvancedMarker(String id) {
  try {
    final win = js_util.globalThis;
    final fn = js_util.getProperty(win, 'removeAdvancedMarker');
    if (fn != null) {
      return js_util.callMethod(win, 'removeAdvancedMarker', [id]);
    }
  } catch (e) {
    try {
      print('callRemoveAdvancedMarker error: $e');
    } catch (_) {}
  }
  return null;
}
