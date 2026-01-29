import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/entrega.dart';

class RotaService {
  /// Calcula a rota otimizada usando o algoritmo Vizinho Mais Próximo (Nearest Neighbor).
  /// Retorna uma nova lista ordenada de entregas sem alterar a lista original.
  List<Entrega> calcularRotaOtimizada(LatLng pontoInicial, List<Entrega> entregas) {
    // Trabalhar sobre uma cópia filtrada (remover entregas sem coordenadas)
    final candidates = entregas.where((e) => e.lat != null && e.lng != null).toList();
    final remaining = List<Entrega>.from(candidates);
    final result = <Entrega>[];

    var currentLat = pontoInicial.latitude;
    var currentLng = pontoInicial.longitude;

    while (remaining.isNotEmpty) {
      // encontra o índice do mais próximo do ponto atual
      var bestIndex = 0;
      var bestDist = _haversineKm(currentLat, currentLng, remaining[0].lat!, remaining[0].lng!);

      for (var i = 1; i < remaining.length; i++) {
        final d = _haversineKm(currentLat, currentLng, remaining[i].lat!, remaining[i].lng!);
        if (d < bestDist) {
          bestDist = d;
          bestIndex = i;
        }
      }

      final next = remaining.removeAt(bestIndex);
      result.add(next);

      currentLat = next.lat!;
      currentLng = next.lng!;
    }

    return result;
  }

  // Haversine formula: returns distance in kilometers between two lat/lng points
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180.0;
}
