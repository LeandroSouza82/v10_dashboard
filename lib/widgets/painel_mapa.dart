import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import 'package:http/http.dart' as http;
import '../models/motorista.dart';
import '../services/supabase_service.dart';
import '../models/entrega.dart';

class PainelMapa extends StatefulWidget {
  static final GlobalKey<PainelMapaState> globalKey = GlobalKey<PainelMapaState>();

  PainelMapa({Key? key}) : super(key: key ?? globalKey);

  @override
  State<PainelMapa> createState() => PainelMapaState();
}

class PainelMapaState extends State<PainelMapa> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  LatLng? _posicaoEmpresa;
  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-27.4946, -48.6577),
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  bool _initialPositionAcquired = false;

  Future<void> _initialize() async {
    await _preloadCompanyIcon();
    final got = await _trySetEmpresaFromGps();
    if (!got) {
      await _loadEmpresaFromPrefs();
    }
    _listenMotoristas();
    setState(() {
      _initialPositionAcquired = true;
    });
    // Ensure base marker is present once after initial position
    if (_posicaoEmpresa != null && !_markers.any((m) => m.markerId.value == 'base_empresa')) {
      setState(() {
        _markers.add(_companyMarker());
      });
    }
  }

  StreamSubscription<List<Motorista>>? _motoristaSub;

  void _listenMotoristas() {
    _motoristaSub = SupabaseService.instance.streamMotoristasOnline().listen(
      (list) {
        final newMarkers = <Marker>{};
        for (final m in list) {
          final lat = m.latitude;
          final lng = m.longitude;
          if (lat == null || lng == null) continue;
          newMarkers.add(
            Marker(
              markerId: MarkerId(m.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: m.nome),
            ),
          );
        }
        // Preserve company marker if defined
        if (_posicaoEmpresa != null) {
          newMarkers.add(_companyMarker());
        }
        // update markers set (motorista updates should NOT auto-adjust camera)
        setState(() {
          _markers
            ..clear()
            ..addAll(newMarkers);
        });
      },
      onError: (e) {
        // ignore errors for now; reconnection is handled by the service
      },
    );
  }

  // demo markers removed

  Marker _companyMarker() {
    final id = 'base_empresa';
    final pos = _posicaoEmpresa!;
    return Marker(
      markerId: MarkerId(id),
      position: pos,
      infoWindow: const InfoWindow(title: 'Minha Empresa / Base'),
      icon: _companyIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  Future<void> _loadEmpresaFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('empresa_lat');
    final lng = prefs.getDouble('empresa_lng');
    if (lat != null && lng != null) {
      _posicaoEmpresa = LatLng(lat, lng);
    }
    // tentar pré-carregar ícone do logo da empresa
    await _preloadCompanyIcon();
  }

  Future<void> _saveEmpresaToPrefs(LatLng pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('empresa_lat', pos.latitude);
    await prefs.setDouble('empresa_lng', pos.longitude);
  }

  Future<void> _setEmpresaToCurrentPosition() async {
    final got = await _trySetEmpresaFromGps();
    if (got) {
      await _preloadCompanyIcon();
      setState(() {
        _markers.add(_companyMarker());
      });
    }
  }

  BitmapDescriptor? _companyIcon;
  DateTime? _lastCameraAdjust;

  Future<bool> _trySetEmpresaFromGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      _posicaoEmpresa = latlng;
      // Debug: confirmar captura de GPS no console
      try {
        debugPrint('GPS Capturado: $_posicaoEmpresa');
      } catch (_) {}
      await _saveEmpresaToPrefs(latlng);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _preloadCompanyIcon() async {
    final url = AppState.instance.urlLogoEmpresa;
    if (url == null) return;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;
        if (bytes.isNotEmpty) {
          // Optionally resize bytes for marker if needed
          // Use new API BitmapDescriptor.bytes instead of deprecated fromBytes
          _companyIcon = BitmapDescriptor.bytes(Uint8List.fromList(bytes));
        }
      }
    } catch (_) {
      // ignore
    }
  }

  /// Exposes company/base position publicly for other widgets.
  LatLng? get empresaLocation => _posicaoEmpresa;

  /// Atualiza os marcadores de entrega para exibir uma numeração sequencial
  /// conforme a ordem fornecida em [ordenadas].
  void numerarEntregas(List<Entrega> ordenadas) {
    if (ordenadas.isEmpty) return;
    final updated = <Marker>{};

    // keep non-pedido markers as-is (e.g., motoristas, base)
    for (final m in _markers) {
      if (!m.markerId.value.toLowerCase().startsWith('pedido')) {
        updated.add(m);
      }
    }

    for (var i = 0; i < ordenadas.length; i++) {
      final e = ordenadas[i];
      final id = 'pedido_${e.id}';
      // find existing marker by id
      final existing = _markers.firstWhere(
        (m) => m.markerId.value == id,
        orElse: () => Marker(
          markerId: MarkerId(id),
          position: LatLng(e.lat ?? 0.0, e.lng ?? 0.0),
          infoWindow: InfoWindow(title: '${i + 1}. ${e.endereco}'),
        ),
      );

      // rebuild marker with numbered title
      final numbered = existing.copyWith(
        infoWindowParam: InfoWindow(title: '${i + 1}. ${existing.infoWindow.title ?? e.endereco}'),
      );
      updated.add(numbered);
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(updated);
    });
  }

  Future<void> _goToCenter() async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_posicaoInicial),
    );
  }

  /// Adiciona um marcador de entrega e ajusta a visão do mapa.
  void addDeliveryMarker(Marker marcador) {
    // adiciona o marcador se não existir
    if (_markers.any((m) => m.markerId == marcador.markerId)) return;
    setState(() {
      _markers.add(marcador);
    });
    // throttle para evitar ajustes repetidos
    final now = DateTime.now();
    if (_lastCameraAdjust == null || now.difference(_lastCameraAdjust!).inMilliseconds > 800) {
      _lastCameraAdjust = now;
      _ajustarVisaoGlobal();
    }
  }

  /// Ajusta a visão global do mapa incluindo: base do gestor, motoristas e pedidos
  Future<void> _ajustarVisaoGlobal() async {
    try {
      if (!_controller.isCompleted) return;
      final controller = await _controller.future;

      // Only adjust camera if there is at least one delivery marker
      final deliveryMarkers = _markers.where((m) {
        final id = m.markerId.value.toLowerCase();
        return id.startsWith('pedido') || id.startsWith('entrega') || id.contains('pedido') || id.contains('entrega');
      }).toList();

      if (deliveryMarkers.isEmpty) {
        // No deliveries -> keep camera static on base (do not animate)
        return;
      }

      final points = <LatLng>[];
      if (_posicaoEmpresa != null) points.add(_posicaoEmpresa!);
      for (final m in _markers) {
        points.add(m.position);
      }

      // remover duplicates
      final unique = <String, LatLng>{};
      for (final p in points) {
        unique['${p.latitude}_${p.longitude}'] = p;
      }
      final pts = unique.values.toList();
      if (pts.isEmpty) return;
      if (pts.length == 1) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15.0));
        return;
      }

      // Calculate span in meters to decide whether to use bounds or a fixed neighborhood zoom
      double minLat = pts.first.latitude;
      double maxLat = pts.first.latitude;
      double minLng = pts.first.longitude;
      double maxLng = pts.first.longitude;
      for (final p in pts) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      // approximate meters
      final meanLat = (minLat + maxLat) / 2.0;
      final latMeters = (maxLat - minLat).abs() * 111000.0;
      final lngMeters = (maxLng - minLng).abs() * 111000.0 * math.cos(meanLat * math.pi / 180.0);
      final spanMeters = math.sqrt(latMeters * latMeters + lngMeters * lngMeters);
      // If span is small (e.g., < 1000m), use fixed neighborhood zoom centered on base
      if (spanMeters < 1000) {
        if (_posicaoEmpresa != null) {
          await controller.animateCamera(CameraUpdate.newLatLngZoom(_posicaoEmpresa!, 15.0));
        } else {
          await controller.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15.0));
        }
        return;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70.0));
    } catch (e) {
      // Se falhar, não quebrar a UI — opcionalmente logar o erro
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          // Renderizar o mapa apenas depois de termos a posição inicial do gestor
          if (_initialPositionAcquired && _posicaoEmpresa != null)
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(target: _posicaoEmpresa!, zoom: 15.0),
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              onMapCreated: (controller) async {
                if (!_controller.isCompleted) _controller.complete(controller);
              },
            )
          else
            // Placeholder até obtermos a posição do gestor
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'set_base',
              onPressed: _setEmpresaToCurrentPosition,
              tooltip: 'Definir base nesta posição',
              child: const Icon(Icons.home, color: Colors.white),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Mapa de motoristas'),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              onPressed: _goToCenter,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _motoristaSub?.cancel();
    super.dispose();
  }
}
