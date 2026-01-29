import 'package:flutter/material.dart';
import '../models/motorista.dart';
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
              ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  // mostrar loading
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    final entregas = await SupabaseService.instance.buscarEntregasPendentes();
                    if (!mounted) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context).pop();
                    if (entregas.isEmpty) {
                      messenger.showSnackBar(const SnackBar(content: Text('Nenhuma entrega pendente')));
                      return;
                    }

                    final base = PainelMapa.globalKey.currentState?.empresaLocation ??
                        const LatLng(-27.4946, -48.6577);
                    final rota = RotaService().calcularRotaOtimizada(base, entregas);

                    if (!mounted) return;

                    // adicionar marcadores numerados via addDeliveryMarker
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
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                      );
                      PainelMapa.globalKey.currentState?.addDeliveryMarker(marker);
                    }

                    // mostrar ordem sugerida em um bottom sheet
                    if (!mounted) return;
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
                  } catch (e) {
                    if (mounted) Navigator.of(context).pop();
                    messenger.showSnackBar(SnackBar(content: Text('Erro ao gerar rota: $e')));
                  }
                },
                icon: const Icon(Icons.route),
                label: const Text('Gerar Rota Sugerida'),
              ),
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
          child: StreamBuilder<List<Motorista>>(
            stream: SupabaseService.instance.streamNovosCandidatos(),
            builder: (context, snapshot) {
              final candidatos = snapshot.data ?? [];
              if (candidatos.isEmpty) {
                return const Center(child: Text('Nenhum candidato pendente'));
              }
              return ListView.builder(
                itemCount: candidatos.length,
                itemBuilder: (context, index) {
                  final m = candidatos[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(m.nome),
                      subtitle: Text('${m.cpf} • ${m.placaVeiculo}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await SupabaseService.instance.aprovarMotorista(
                              m.id,
                            );
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Motorista aprovado'),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Erro: $e')),
                            );
                          }
                        },
                        child: const Text('Aprovar'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
