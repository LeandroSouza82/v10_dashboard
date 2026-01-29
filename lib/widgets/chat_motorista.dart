import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/motorista.dart';
import '../models/mensagem.dart';
import '../services/supabase_service.dart';

class ChatMotorista extends StatefulWidget {
  const ChatMotorista({super.key});

  @override
  State<ChatMotorista> createState() => _ChatMotoristaState();
}

class _ChatMotoristaState extends State<ChatMotorista> {
  final _mensagemController = TextEditingController();
  String? _motoristaSelecionadoId;
  bool _enviando = false;

  @override
  void dispose() {
    _mensagemController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty) return;
    if (_motoristaSelecionadoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um motorista')));
      return;
    }
    setState(() => _enviando = true);
    try {
      await SupabaseService.instance.enviarMensagemChat(
        remetenteId: 'dispatch',
        destinatarioId: _motoristaSelecionadoId ?? '',
        texto: texto,
      );
      if (!mounted) return;
      _mensagemController.clear();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder<List<Motorista>>(
            stream: SupabaseService.instance.streamMotoristasOnline(),
            builder: (context, snapshot) {
              final drivers = snapshot.data ?? [];
              return DropdownButton<String>(
                value: drivers.any((m) => m.id.toString() == _motoristaSelecionadoId) ? _motoristaSelecionadoId : null,
                hint: const Text('Selecione motorista'),
                items: drivers
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.id.toString(),
                        child: Text(m.nome),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _motoristaSelecionadoId = v),
              );
            },
          ),
        ),
        Expanded(
          child: _motoristaSelecionadoId == null
              ? const Center(
                  child: Text('Selecione um motorista para ver o chat'),
                )
              : StreamBuilder<List<Mensagem>>(
                  stream: SupabaseService.instance
                      .streamMensagens(_motoristaSelecionadoId ?? '')
                      .map(
                        (lista) =>
                            lista.map((map) => Mensagem.fromJson(map)).toList(),
                      ),
                  builder: (context, snapshot) {
                    final mensagens = snapshot.data ?? [];
                    return ListView.builder(
                      reverse: true,
                      itemCount: mensagens.length,
                      itemBuilder: (context, index) {
                        final msg = mensagens[mensagens.length - 1 - index];
                        final meu = msg.remetenteId == 'dispatch';
                        return Align(
                          alignment: meu
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: meu
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.texto,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  DateFormat('HH:mm').format(msg.criadoEm),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mensagemController,
                  decoration: const InputDecoration(hintText: 'Mensagem'),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
