// ignore_for_file: unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/entrega.dart';
import '../services/supabase_service.dart';
import '../services/rota_service.dart';
import 'dart:async';
import '../core/constants/api_keys.dart';
import '../services/google_places.dart';
import '../services/google_directions.dart';
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
  List<Entrega> pedidosPendentes = [];
  // Places autocomplete
  List<Map<String, String>> _placeSuggestions = [];
  Timer? _placeDebounce;
  bool _showPlaceSuggestions = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _enderecoController.dispose();
    _obsController.dispose();
    _placeDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Diagnostic: confirmar leitura da API key do config
    try {
      print('DEBUG: ApiKeys.googleMapsKey=${ApiKeys.googleMapsKey}');
    } catch (e) {
      print('DEBUG: falha ao ler ApiKeys.googleMapsKey: $e');
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      // tentar geocoding se endereço preenchido - obrigatório antes do envio
      if ((_enderecoController.text).trim().isNotEmpty) {
        // limpar endereço: colapsar traços múltiplos e espaços extras
        var addr = _enderecoController.text.trim();
        addr = addr
            .replaceAll(RegExp(r'-{2,}'), '-')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();

        // primeira tentativa
        var coords = await _geocodeAddress(addr);
        // segunda tentativa: adicionar ", Brasil" se primeira falhar
        coords ??= await _geocodeAddress('$addr, Brasil');

        if (coords == null) {
          // Não bloquear o salvamento caso o geocode falhe: o endereço
          // normalmente virá do Autocomplete do Google (ou o usuário pode
          // salvar sem coordenadas). Continuamos sem lat/lng.
        } else {
          // garantir doubles e usar coordenadas encontradas
          _lat = (coords['lat'] as double);
          _lng = (coords['lng'] as double);
        }
      }
      final entrega = Entrega(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cliente: _nomeController.text.trim(),
        endereco: _enderecoController.text.trim(),
        cidade: '',
        status: 'pendente',
        motoristaId: null,
        obs: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
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
            infoWindow: InfoWindow(
              title: saved.cliente.isNotEmpty ? saved.cliente : 'Pedido',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          );
          // debug coordenadas do marker
          // coordenadas do marker disponíveis
          PainelMapa.globalKey.currentState?.addDeliveryMarker(marker);
        } catch (_) {
          // ignore if map not ready
        }
      }
      if (!mounted) return;
      _formKey.currentState!.reset();
      _nomeController.clear();
      _enderecoController.clear();
      _obsController.clear();
      _lat = null;
      _lng = null;
      setState(() {
        _tipoServico = 'entrega';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega salva como pendente')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      setState(() => _enviando = false);
    }
  }

  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      final key = ApiKeys.googleMapsKey;
      return await geocodeAddress(address, key);
    } catch (e) {
      print('DEBUG: geocodeAddress error: $e');
      return null;
    }
  }

  void _onAddressChanged(String value) {
    _placeDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _placeSuggestions = [];
        _showPlaceSuggestions = false;
      });
      return;
    }
    _placeDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _fetchPlaceSuggestions(value.trim());
    });
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    try {
      final key = ApiKeys.googleMapsKey;
      final list = await fetchPlaceSuggestions(input, key);
      setState(() {
        _placeSuggestions = list;
        _showPlaceSuggestions = list.isNotEmpty;
      });
    } catch (e) {
      print('DEBUG: Places autocomplete exception: $e');
    }
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    try {
      final key = ApiKeys.googleMapsKey;
      final details = await fetchPlaceDetails(placeId, key);
      if (details == null) return;
      final formatted = details['formatted'] as String?;
      final lat = details['lat'] as double?;
      final lng = details['lng'] as double?;
      if (formatted != null) _enderecoController.text = formatted;
      if (lat != null && lng != null) {
        _lat = lat;
        _lng = lng;
      }
      setState(() {
        _placeSuggestions = [];
        _showPlaceSuggestions = false;
      });
    } catch (e) {
      print('DEBUG: Places details exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Form scrollable area
              Flexible(
                flex: 0,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Novo Pedido',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Debug controls
                        if (kDebugMode)
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    print(
                                      'DEBUG: iniciando diagnostico de insercao no Supabase',
                                    );
                                    await SupabaseService.instance
                                        .diagnosticoInserirEntrega();
                                    print(
                                      'DEBUG: diagnostico de insercao finalizado',
                                    );
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Diagnóstico: tentativa de insert executada (veja console)',
                                          ),
                                        ),
                                      );
                                  } catch (e) {
                                    print(
                                      'DEBUG: diagnostico insercao erro: $e',
                                    );
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Diagnóstico falhou: $e',
                                          ),
                                        ),
                                      );
                                  }
                                },
                                child: const Text('Diagnóstico Supabase'),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),

                        DropdownButtonFormField<String>(
                          initialValue: _tipoServico,
                          items: const [
                            DropdownMenuItem(
                              value: 'entrega',
                              child: Text('Entrega'),
                            ),
                            DropdownMenuItem(
                              value: 'retirada',
                              child: Text('Retirada'),
                            ),
                            DropdownMenuItem(
                              value: 'outros',
                              child: Text('Outros'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _tipoServico = v ?? 'entrega'),
                          decoration: InputDecoration(
                            labelText: 'Tipo de Serviço',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 12.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nome do cliente
                        TextFormField(
                          controller: _nomeController,
                          decoration: InputDecoration(
                            labelText: 'Nome do cliente',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 12.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nome obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Endereço com Autocomplete (Google Places)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _enderecoController,
                              decoration: InputDecoration(
                                labelText: 'Endereço',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 12.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLines: 2,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Endereço obrigatório'
                                  : null,
                              onChanged: _onAddressChanged,
                            ),
                            if (_showPlaceSuggestions &&
                                _placeSuggestions.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 6.0),
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromRGBO(
                                        0,
                                        0,
                                        0,
                                        0.08,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _placeSuggestions.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final item = _placeSuggestions[i];
                                    return ListTile(
                                      title: Text(item['description'] ?? ''),
                                      onTap: () async {
                                        final pid = item['place_id'];
                                        if (pid == null) return;
                                        await _fetchPlaceDetails(pid);
                                      },
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Observações
                        TextFormField(
                          controller: _obsController,
                          decoration: InputDecoration(
                            labelText: 'Observações',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 12.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: _enviando ? null : _enviar,
                          child: _enviando
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(),
                                )
                              : const Text('Salvar (Fila)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Lista de pedidos (expand)
              Expanded(
                child: StreamBuilder<List<Entrega>>(
                  stream: SupabaseService.instance.streamEntregas(),
                  builder: (context, snapshot) {
                    final todas = snapshot.data ?? [];
                    final entregas = todas
                        .where((e) => e.status == 'pendente')
                        .toList();
                    pedidosPendentes = entregas;
                    if (entregas.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma entrega pendente'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                      itemCount: entregas.length,
                      itemBuilder: (context, index) {
                        final e = entregas[index];
                        final t = e.tipo.toLowerCase();
                        final borderColor = t.contains('entrega')
                            ? Colors.blue.shade300
                            : (t.contains('retira') ||
                                  t.contains('coleta') ||
                                  t.contains('retirada'))
                            ? Colors.orange.shade300
                            : Colors.purple.shade200;

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 6, color: borderColor),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: borderColor,
                                    child: const Icon(
                                      Icons.local_shipping,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.cliente,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          e.endereco,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Confirmação'),
                                          content: const Text(
                                            'Deseja excluir este pedido?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Não'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: const Text('Sim'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm != true) return;
                                      try {
                                        await SupabaseService.instance
                                            .excluirEntrega(e.id);
                                        if (!mounted) return;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Pedido excluído',
                                                  ),
                                                ),
                                              );
                                            });
                                      } catch (err) {
                                        if (!mounted) return;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Erro ao excluir: $err',
                                                  ),
                                                ),
                                              );
                                            });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Botões finais: único botão que organiza e envia
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (c) =>
                            const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final entregas = await SupabaseService.instance
                            .buscarEntregasPendentes();
                        if (!mounted) return;

                        final base =
                            PainelMapa
                                .globalKey
                                .currentState
                                ?.empresaLocation ??
                            const LatLng(-27.4946, -48.6577);

                        // Prepare waypoints for Directions API (lat,lng strings)
                        final waypoints = <String>[];
                        final entregasWithCoords = <Entrega>[];
                        for (final e in entregas) {
                          if (e.lat == null || e.lng == null) continue;
                          waypoints.add('${e.lat},${e.lng}');
                          entregasWithCoords.add(e);
                        }

                        // Try to get optimized order from Google Directions
                        List<int>? wpOrder;
                        try {
                          final key = ApiKeys.googleMapsKey;
                          // choose web or non-web implementation via conditional export
                          wpOrder = await getOptimizedWaypointOrder(
                            apiKey: key,
                            origin: '${base.latitude},${base.longitude}',
                            destination: '${base.latitude},${base.longitude}',
                            waypoints: waypoints,
                          );
                        } catch (_) {
                          // ignore and fallback to local optimization
                        }

                        List<Entrega> rota = [];
                        if (wpOrder != null && wpOrder.isNotEmpty) {
                          for (final idx in wpOrder) {
                            if (idx < entregasWithCoords.length) {
                              rota.add(entregasWithCoords[idx]);
                            }
                          }
                        } else {
                          // fallback to local calculation if Directions API failed
                          rota = RotaService().calcularRotaOtimizada(
                            base,
                            entregas,
                          );
                        }

                        for (var i = 0; i < rota.length; i++) {
                          final e = rota[i];
                          final lat = e.lat;
                          final lng = e.lng;
                          if (lat == null || lng == null) continue;
                          final marker = Marker(
                            markerId: MarkerId('pedido_${e.id}'),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(
                              title: '${i + 1}. ${e.endereco}',
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          );
                          PainelMapa.globalKey.currentState?.addDeliveryMarker(
                            marker,
                          );
                        }

                        final motoristas = await SupabaseService.instance
                            .buscarMotoristas();
                        if (!mounted) return;

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          Navigator.of(context).pop();

                          showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) {
                              return ListView.builder(
                                itemCount: motoristas.length,
                                itemBuilder: (c, i) {
                                  final m = motoristas[i];
                                  final online = m.estaOnline;
                                  final avatar =
                                      (m.avatarPath?.isNotEmpty ?? false)
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            m.avatarPath!,
                                          ),
                                        )
                                      : CircleAvatar(
                                          child: Text(
                                            m.nome.isNotEmpty ? m.nome[0] : '?',
                                          ),
                                        );
                                  return ListTile(
                                    leading: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        avatar,
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: online
                                                ? Colors.green
                                                : Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      '${m.nome}${m.sobrenome != null ? ' ${m.sobrenome}' : ''}',
                                    ),
                                    subtitle: Text(m.placaVeiculo),
                                    onTap: () async {
                                      Navigator.of(ctx).pop();
                                      showDialog<void>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (c) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                      try {
                                        await SupabaseService.instance
                                            .criarRota(m.id, rota);
                                        // Após salvar a rota, persista a ordem de entrega
                                        for (var j = 0; j < rota.length; j++) {
                                          final ent = rota[j];
                                          try {
                                            await SupabaseService.instance
                                                .atualizarOrdemEntrega(
                                                  ent.id,
                                                  j + 1,
                                                );
                                          } catch (_) {}
                                        }
                                        // Obrigatório: limpar lista local de pendentes e notificar UI
                                        if (!mounted) return;
                                        pedidosPendentes.clear();
                                        setState(() {});
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Rota enviada com sucesso!',
                                                  ),
                                                ),
                                              );
                                            });
                                        // Reset completo do mapa (remove marcadores/polylines)
                                        PainelMapa.globalKey.currentState
                                            ?.clearAllMarkers();

                                        // Também limpar formulários e fechar modal
                                        if (!mounted) return;
                                        setState(() {
                                          _nomeController.clear();
                                          _enderecoController.clear();
                                          _obsController.clear();
                                          _tipoServico = 'entrega';
                                        });
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              Navigator.of(context).pop();
                                            });
                                      } catch (err) {
                                        if (!mounted) return;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              Navigator.of(context).pop();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Erro ao enviar rota: $err',
                                                  ),
                                                ),
                                              );
                                            });
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          );
                        });
                      } catch (e) {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Erro ao organizar/enviar rota: $e',
                                ),
                              ),
                            );
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.send_and_archive),
                    label: const Text('Organizar e Enviar Rota'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
