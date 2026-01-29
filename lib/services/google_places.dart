// Conditional export: expose the correct implementation depending on platform
export 'google_places_nonweb.dart'
    if (dart.library.html) 'google_places_web.dart';
