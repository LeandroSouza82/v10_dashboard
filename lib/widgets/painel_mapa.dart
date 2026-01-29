import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
// 'foundation' imported elsewhere via material; remove redundant import
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/app_state.dart';
import '../models/motorista.dart';
import '../models/entrega.dart';
import '../services/supabase_service.dart';

class PainelMapa extends StatefulWidget {
  static final GlobalKey<PainelMapaState> globalKey =
      GlobalKey<PainelMapaState>();

  PainelMapa({Key? key}) : super(key: key ?? globalKey);

  @override
  State<PainelMapa> createState() => PainelMapaState();
}

class PainelMapaState extends State<PainelMapa> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();

  final Set<Marker> _markers = <Marker>{};
  final Set<Marker> _motoristaMarkers = <Marker>{};
  final Set<Marker> _entregaMarkers = <Marker>{};
  // Keep a map of motorista_id -> Marker to update positions without flicker
  final Map<String, Marker> _motoristasMarkersMap = <String, Marker>{};
  // Active animation controllers for markers (to interpolate movement)
  final Map<String, AnimationController> _motoristaAnimControllers = <String, AnimationController>{};

  StreamSubscription<List<Motorista>>? _motoristaSub;
  StreamSubscription<List<Entrega>>? _entregasSub;

  LatLng? _posicaoEmpresa;
  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-27.4946, -48.6577),
    zoom: 15.0,
  );

  BitmapDescriptor? _companyIcon;
  DateTime? _lastCameraAdjust;
  bool _initialPositionAcquired = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _preloadCompanyIcon();
    final got = await _trySetEmpresaFromGps();
    if (!got) await _loadEmpresaFromPrefs();
    _listenMotoristas();
    _listenEntregas();
    setState(() => _initialPositionAcquired = true);

    if (_posicaoEmpresa != null &&
        !_markers.any((m) => m.markerId.value == 'base_empresa')) {
      _markers.add(_companyMarker());
    }
  }

  void _listenMotoristas() {
    _motoristaSub = SupabaseService.instance.streamMotoristasOnline().listen(
      (list) {
        try {
          for (final m in list) {
            final lat = m.latitude;
            final lng = m.longitude;
            if (lat == null || lng == null) continue;
            final id = m.id.toString();

            final newPos = LatLng(lat, lng);

            // If we already have a marker for this motorista, animate to new position
            final existing = _motoristasMarkersMap[id];
            if (existing != null) {
              _animateMarkerTo(id, existing.position, newPos, title: m.nome);
            } else {
              final marker = Marker(
                markerId: MarkerId('motorista_$id'),
                position: newPos,
                infoWindow: InfoWindow(title: m.nome),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              );
              _motoristasMarkersMap[id] = marker;
              _motoristaMarkers.add(marker);
            }
          }
          if (!mounted) return;
          setState(() {
            _rebuildMarkers();
          });
        } catch (e) {
          debugPrint('Erro no listener de motoristas: $e');
        }
      },
      onError: (err) {
        debugPrint('Realtime error (motoristas): $err');
      },
    );
  }

  void _listenEntregas() {
    _entregasSub = SupabaseService.instance.streamEntregas().listen((list) {
      final newMarkers = <Marker>{};
      for (final e in list) {
        if (e.lat == null || e.lng == null) continue;
        final hue = (e.status == 'pendente')
            ? BitmapDescriptor.hueOrange
            : (e.status == 'em_rota')
            ? BitmapDescriptor.hueViolet
            : BitmapDescriptor.hueBlue;
        newMarkers.add(
          Marker(
            markerId: MarkerId('pedido_${e.id}'),
            position: LatLng(e.lat!, e.lng!),
            infoWindow: InfoWindow(
              title: e.cliente.isNotEmpty ? e.cliente : e.endereco,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          ),
        );
      }
      setState(() {
        _entregaMarkers
          ..clear()
          ..addAll(newMarkers);
        _rebuildMarkers();
      });
    }, onError: (_) {});
  }

  void _rebuildMarkers() {
    _markers
      ..clear()
      ..addAll(_motoristaMarkers)
      ..addAll(_entregaMarkers);
    if (_posicaoEmpresa != null) _markers.add(_companyMarker());
  }

  void _animateMarkerTo(String id, LatLng from, LatLng to, {String? title}) {
    final duration = Duration(milliseconds: 700);

    // Keep a reference to the starting marker
    final startMarker = _motoristasMarkersMap[id];
    if (startMarker == null) {
      // create a new marker if missing
      final marker = Marker(
        markerId: MarkerId('motorista_$id'),
        position: to,
        infoWindow: InfoWindow(title: title ?? ''),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
      _motoristasMarkersMap[id] = marker;
      _motoristaMarkers.add(marker);
      if (!mounted) return;
      setState(() => _rebuildMarkers());
      return;
    }

    // Dispose previous controller if exists
    _motoristaAnimControllers[id]?.dispose();

    final controller = AnimationController(vsync: this, duration: duration);
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    // Tween lat/lng separately and update marker on each tick
    final latTween = Tween<double>(begin: from.latitude, end: to.latitude);
    final lngTween = Tween<double>(begin: from.longitude, end: to.longitude);

    void listener() {
      final lat = latTween.evaluate(curved);
      final lng = lngTween.evaluate(curved);
      final updated = startMarker.copyWith(
        positionParam: LatLng(lat, lng),
        infoWindowParam: InfoWindow(title: title ?? startMarker.infoWindow.title ?? ''),
      );
      _motoristasMarkersMap[id] = updated;
      _motoristaMarkers
        ..removeWhere((m) => m.markerId == updated.markerId)
        ..add(updated);
      if (mounted) setState(() => _rebuildMarkers());
    }

    controller.addListener(listener);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.removeListener(listener);
        _motoristaAnimControllers.remove(id)?.dispose();
      }
    });

    _motoristaAnimControllers[id] = controller;
    controller.forward();
  }

  /// Interpolates a motorista marker position from `from` to `to` using an
  /// [AnimationController] with an easeInOut curve. This avoids timer-based
  /// updates and provides smoother motion. The function updates the internal
  /// `_motoristasMarkersMap` and triggers a minimal `setState` to repaint the
  /// map markers. For web-specific AdvancedMarkerElement integration, a
  /// separate code path should replace Marker instances with JS-backed
  /// AdvancedMarkerElement objects (requires access to underlying JS map).

  Marker _companyMarker() {
    final id = 'base_empresa';
    final pos = _posicaoEmpresa ?? _posicaoInicial.target;
    return Marker(
      markerId: MarkerId(id),
      position: pos,
      infoWindow: const InfoWindow(title: 'Minha Empresa / Base'),
      icon:
          _companyIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  Future<void> _loadEmpresaFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('empresa_lat');
    final lng = prefs.getDouble('empresa_lng');
    if (lat != null && lng != null) _posicaoEmpresa = LatLng(lat, lng);
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
        if (_posicaoEmpresa != null &&
            !_markers.any((m) => m.markerId.value == 'base_empresa')) {
          _markers.add(_companyMarker());
        }
      });
      _ajustarVisaoGlobal();
    }
  }

  Future<bool> _trySetEmpresaFromGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      _posicaoEmpresa = latlng;
      await _saveEmpresaToPrefs(latlng);
      return true;
    } catch (_) {
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
            _companyIcon = BitmapDescriptor.bytes(bytes);
          }
        }
    } catch (_) {}
  }

  LatLng? get empresaLocation => _posicaoEmpresa;

  void numerarEntregas(List<Entrega> ordenadas) {
    if (ordenadas.isEmpty) return;
    final updated = <Marker>{};
    for (final m in _markers) {
      if (!m.markerId.value.toLowerCase().startsWith('pedido')) updated.add(m);
    }
    for (var i = 0; i < ordenadas.length; i++) {
      final e = ordenadas[i];
      final id = 'pedido_${e.id}';
      final existing = _markers.firstWhere(
        (m) => m.markerId.value == id,
        orElse: () => Marker(
          markerId: MarkerId(id),
          position: LatLng(e.lat ?? 0.0, e.lng ?? 0.0),
          infoWindow: InfoWindow(title: '${i + 1}. ${e.endereco}'),
        ),
      );
      final numbered = existing.copyWith(
        infoWindowParam: InfoWindow(
          title: '${i + 1}. ${existing.infoWindow.title ?? e.endereco}',
        ),
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
    if (_lastCameraAdjust == null ||
        now.difference(_lastCameraAdjust!).inMilliseconds > 800) {
      _lastCameraAdjust = now;
      _ajustarVisaoGlobal();
    }
  }

  /// Força uma recarga pontual dos pinos de entrega (chamável a partir de Sidebar)
  Future<void> reloadDeliveryPins() async {
    try {
      final entregas = await SupabaseService.instance.buscarEntregasPendentes();
      final newMarkers = <Marker>{};
      for (final e in entregas) {
        if (e.lat == null || e.lng == null) continue;
        newMarkers.add(
          Marker(
            markerId: MarkerId('pedido_${e.id}'),
            position: LatLng(e.lat!, e.lng!),
            infoWindow: InfoWindow(
              title: e.cliente.isNotEmpty ? e.cliente : e.endereco,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }
      setState(() {
        _entregaMarkers
          ..clear()
          ..addAll(newMarkers);
        _rebuildMarkers();
      });
    } catch (_) {}
  }

  /// Limpa todos os marcadores de motoristas/entregas e polylines do mapa,
  /// deixando apenas o marcador da empresa (se houver).
  void clearAllMarkers() {
    setState(() {
      _motoristaMarkers.clear();
      _entregaMarkers.clear();
      _markers.clear();
      if (_posicaoEmpresa != null) _markers.add(_companyMarker());
    });
  }

  Future<void> _ajustarVisaoGlobal() async {
    try {
      if (!_controller.isCompleted) return;
      final controller = await _controller.future;

      final deliveryMarkers = _markers.where((m) {
        final id = m.markerId.value.toLowerCase();
        return id.startsWith('pedido') || id.contains('entrega');
      }).toList();

      if (deliveryMarkers.isEmpty) return;

      final points = <LatLng>[];
      if (_posicaoEmpresa != null) points.add(_posicaoEmpresa!);
      for (final m in _markers) {
        points.add(m.position);
      }

      final unique = <String, LatLng>{};
      for (final p in points) {
        unique['${p.latitude}_${p.longitude}'] = p;
      }
      final pts = unique.values.toList();
      if (pts.isEmpty) return;
      if (pts.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(pts.first, 15.0),
        );
        return;
      }

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
      final meanLat = (minLat + maxLat) / 2.0;
      final latMeters = (maxLat - minLat).abs() * 111000.0;
      final lngMeters =
          (maxLng - minLng).abs() *
          111000.0 *
          math.cos(meanLat * math.pi / 180.0);
      final spanMeters = math.sqrt(
        latMeters * latMeters + lngMeters * lngMeters,
      );
      if (spanMeters < 1000) {
        if (_posicaoEmpresa != null) {
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(_posicaoEmpresa!, 15.0),
          );
        } else {
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(pts.first, 15.0),
          );
        }
        return;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 70.0),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          if (_initialPositionAcquired && _posicaoEmpresa != null)
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _posicaoEmpresa!,
                zoom: 15.0,
              ),
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              onMapCreated: (controller) async {
                if (!_controller.isCompleted) _controller.complete(controller);
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'set_base',
              onPressed: () async {
                await _setEmpresaToCurrentPosition();
              },
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
    _entregasSub?.cancel();
    super.dispose();
  }
}
