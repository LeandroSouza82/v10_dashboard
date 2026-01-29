import 'package:flutter/material.dart';
import '../models/motorista.dart';
import '../models/entrega.dart';
import '../services/supabase_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/rota_service.dart';
import 'painel_mapa.dart';

class GestaoMotoristas extends StatefulWidget {
  const GestaoMotoristas({super.key});

  @override
  State<GestaoMotoristas> createState() => _GestaoMotoristasState();
}

class _GestaoMotoristasState extends State<GestaoMotoristas> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.people),
              const SizedBox(width: 8),
              Text(
                'Gestão de Motoristas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              const SizedBox(width: 8),
              StreamBuilder<List<Motorista>>(
                stream: SupabaseService.instance.streamNovosCandidatos(),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count pendentes',
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Entrega>>(
            stream: SupabaseService.instance.streamEntregas(),
            builder: (context, snapshot) {
              final todas = snapshot.data ?? [];
              final entregas = todas
                  .where((e) => e.status == 'pendente')
                  .toList();
              if (entregas.isEmpty) {
                return const Center(child: Text('Nenhuma entrega pendente'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: entregas.length,
                itemBuilder: (context, index) {
                  final e = entregas[index];
                  Color borderColor;
                  final t = e.tipo.toLowerCase();
                  if (t.contains('entrega')) {
                    borderColor = Colors.blue.shade300;
                  } else if (t.contains('retira') ||
                      t.contains('coleta') ||
                      t.contains('retirada')) {
                    borderColor = Colors.orange.shade300;
                  } else {
                    borderColor = Colors.purple.shade200;
                  }

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  await SupabaseService.instance.excluirEntrega(
                                    e.id,
                                  );
                                  if (!mounted) return;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Pedido excluído'),
                                      ),
                                    );
                                  });
                                } catch (err) {
                                  if (!mounted) return;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erro ao excluir: $err'),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      PainelMapa.globalKey.currentState?.empresaLocation ??
                      const LatLng(-27.4946, -48.6577);
                  final rota = RotaService().calcularRotaOtimizada(
                    base,
                    entregas,
                  );

                  if (!mounted) return;
                  for (var i = 0; i < rota.length; i++) {
                    final e = rota[i];
                    final markerId = 'pedido_${e.id}';
                    final lat = e.lat;
                    final lng = e.lng;
                    if (lat == null || lng == null) continue;
                    final marker = Marker(
                      markerId: MarkerId(markerId),
                      position: LatLng(lat, lng),
                      infoWindow: InfoWindow(title: '${i + 1}. ${e.endereco}'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                    );
                    PainelMapa.globalKey.currentState?.addDeliveryMarker(
                      marker,
                    );
                  }

                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    if (rota.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nenhuma entrega pendente'),
                        ),
                      );
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) {
                        return ListView.builder(
                          itemCount: rota.length,
                          itemBuilder: (c, i) {
                            final e = rota[i];
                            return ListTile(
                              leading: CircleAvatar(child: Text('${i + 1}')),
                              title: Text(e.cliente),
                              subtitle: Text(e.endereco),
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
                        SnackBar(content: Text('Erro ao gerar rota: $e')),
                      );
                    });
                  }
                }
              },
              icon: const Icon(Icons.route),
              label: const Text('Gerar Rota Sugerida'),
            ),
          ),
        ),
      ],
    );
  }
}
