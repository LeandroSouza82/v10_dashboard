import 'package:flutter/material.dart';
import '../models/entrega.dart';
import '../services/supabase_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants/api_keys.dart';
import '../core/app_state.dart';
import 'painel_mapa.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SidebarPedido extends StatefulWidget {
  const SidebarPedido({super.key});

  @override
  State<SidebarPedido> createState() => _SidebarPedidoState();
}

class _SidebarPedidoState extends State<SidebarPedido> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _obsController = TextEditingController();
  String _tipoServico = 'entrega';
  // motorista selecionado atualmente não utilizado (removido para limpeza)
  double? _lat;
  double? _lng;
  bool _enviando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _enderecoController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      // tentar geocoding se endereço preenchido
      if ((_enderecoController.text).trim().isNotEmpty) {
        try {
          final coords = await _geocodeAddress(_enderecoController.text.trim());
          if (coords != null) {
            _lat = coords['lat'];
            _lng = coords['lng'];
          }
        } catch (_) {
          // falha no geocoding não bloqueia o salvamento
        }
      }
      final entrega = Entrega(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cliente: _nomeController.text.trim(),
        endereco: _enderecoController.text.trim(),
        cidade: '',
        status: 'pendente',
        motoristaId: null,
        obs: _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
        tipo: _tipoServico,
        assinaturaUrl: null,
        motivoNaoEntrega: null,
        criadoEm: DateTime.now(),
        lat: _lat,
        lng: _lng,
      );

      final saved = await SupabaseService.instance.enviarEntrega(entrega);
      // se lat/lng disponíveis, adicionar marcador no mapa via GlobalKey
      // Use DB-generated id and saved lat/lng when available
      final markerId = 'pedido_${saved.id}';
      final markerLat = saved.lat ?? _lat;
      final markerLng = saved.lng ?? _lng;
      if (markerLat != null && markerLng != null) {
        try {
          final marker = Marker(
            markerId: MarkerId(markerId),
            position: LatLng(markerLat, markerLng),
            infoWindow: InfoWindow(title: saved.cliente.isNotEmpty ? saved.cliente : 'Pedido'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          );
          PainelMapa.globalKey.currentState?.addDeliveryMarker(marker);
        } catch (_) {
          // ignore if map not ready
        }
      }
      if (!mounted) return;
      _formKey.currentState!.reset();
      setState(() {
        _tipoServico = 'entrega';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrega salva como pendente')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      setState(() => _enviando = false);
    }
  }

  Future<Map<String, double>?> _geocodeAddress(String address) async {
    final key = ApiKeys.googleMapsKey;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': address,
      'key': key,
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;
    try {
      final body = resp.body;
      final json = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : null;
      if (json == null) return null;
      if ((json['status'] as String?) != 'OK') return null;
      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final location = (results.first['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Padding(
                padding: const EdgeInsets.only(top: 60.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25.0),

                    // Logo da empresa (dinâmico)
                    Center(
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.transparent,
                        child: AppState.instance.urlLogoEmpresa != null
                            ? ClipOval(
                                child: Image.network(
                                  AppState.instance.urlLogoEmpresa!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 36),
                                ),
                              )
                            : const Icon(Icons.business, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('Novo Pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                        initialValue: _tipoServico,
                        items: const [
                          DropdownMenuItem(value: 'entrega', child: Text('Entrega')),
                          DropdownMenuItem(value: 'retirada', child: Text('Retirada')),
                          DropdownMenuItem(value: 'outros', child: Text('Outros')),
                        ],
                        onChanged: (v) => setState(() => _tipoServico = v ?? 'entrega'),
                        decoration: InputDecoration(
                          labelText: 'Tipo de Serviço',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nome do cliente
                      TextFormField(
                        controller: _nomeController,
                        decoration: InputDecoration(
                          labelText: 'Nome do cliente',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome obrigatório' : null,
                      ),
                      const SizedBox(height: 20),

                      // Endereço
                      TextFormField(
                        controller: _enderecoController,
                        decoration: InputDecoration(
                          labelText: 'Endereço',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Endereço obrigatório' : null,
                      ),
                      const SizedBox(height: 20),

                      // Ordem de campos: Tipo, Nome, Endereço, Observações

                      // Observações
                      TextFormField(
                        controller: _obsController,
                        decoration: InputDecoration(
                          labelText: 'Observações',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _enviando ? null : _enviar,
                        child: _enviando
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator())
                            : const Text('Salvar (Fila)'),
                      ),
                    ],
                  ),
                ),
              ),
          ),
        ),
      ),
    );
  }
}

