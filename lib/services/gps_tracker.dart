import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class GPSTracker {
  GPSTracker._private();
  static final GPSTracker instance = GPSTracker._private();

  Timer? _timer;
  String? _motoristaId;

  /// Inicia envio periódico da posição do motorista (interval em segundos).
  Future<void> start(String motoristaId, {int intervalSeconds = 10}) async {
    _motoristaId = motoristaId;
    // Verificar permissões
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint('GPSTracker: permissão de localização não concedida');
      return;
    }

    // Evitar múltiplos timers
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      if (_motoristaId == null) return;
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        await SupabaseService.instance.updateMotoristaLocation(
          _motoristaId!,
          pos.latitude,
          pos.longitude,
          heading: pos.heading,
        );
      } catch (e) {
        debugPrint('GPSTracker: falha ao enviar localização: $e');
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _motoristaId = null;
  }

  bool get isRunning => _timer != null;
}
