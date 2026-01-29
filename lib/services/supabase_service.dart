// ignore_for_file: unnecessary_cast, unused_element, no_leading_underscores_for_local_identifiers, curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/motorista.dart';
import '../models/entrega.dart';
import '../models/mensagem.dart';

class SupabaseService {
  SupabaseService._private();

  static final SupabaseService instance = SupabaseService._private();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Helpers to normalize responses from Supabase (stream/select may return
  // Map or List depending on query)
  List<Map<String, dynamic>> _toMapList(dynamic event) {
    if (event == null) return <Map<String, dynamic>>[];
    try {
      if (event is List) {
        return event
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      }
      if (event is Map) {
        return <Map<String, dynamic>>[Map<String, dynamic>.from(event as Map)];
      }
    } catch (e) {
      // fallthrough -> return empty
      debugPrint('Erro ao normalizar evento Supabase para lista: $e');
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data == null) return null;
    try {
      if (data is Map) return Map<String, dynamic>.from(data as Map);
      if (data is List && data.isNotEmpty)
        return Map<String, dynamic>.from(data.first as Map);
    } catch (e) {
      debugPrint('Erro ao normalizar dado Supabase para Map: $e');
    }
    return null;
  }

  dynamic _parseId(String? id) {
    if (id == null) return null;
    final parsed = int.tryParse(id);
    return parsed ?? id;
  }

  // MOTORISTAS
  Stream<List<Motorista>> streamMotoristasOnline() {
    final controller = StreamController<List<Motorista>>.broadcast();
    bool isCanceled = false;
    StreamSubscription? sub;
    int retrySeconds = 1;

    late void Function() _subscribe;

    void scheduleReconnect() {
      if (isCanceled) return;
      final delay = Duration(seconds: retrySeconds);
      Timer(delay, () {
        if (isCanceled) return;
        retrySeconds = min(retrySeconds * 2, 30);
        _subscribe();
      });
    }

    _subscribe = () {
      try {
        sub = _supabase
            .from('motoristas')
            .stream(primaryKey: ['id'])
            .eq('esta_online', true)
            .listen(
              (event) {
                try {
                  final list = _toMapList(event);
                  final models = list
                      .map((e) => Motorista.fromJson(e))
                      .toList();
                  controller.add(models);
                  retrySeconds = 1; // reset backoff on success
                } catch (e, st) {
                  debugPrint(
                    'Erro no SupabaseService (streamMotoristasOnline): $e',
                  );
                  controller.addError(e, st);
                }
              },
              onError: (err) {
                debugPrint('Realtime error (motoristas): $err');
                controller.addError(err);
                scheduleReconnect();
              },
              onDone: () {
                if (!isCanceled) scheduleReconnect();
              },
            );
      } catch (e) {
        debugPrint('Erro ao subscrever motoristas realtime: $e');
        controller.addError(e);
        scheduleReconnect();
      }
    };

    _subscribe();

    controller.onCancel = () {
      isCanceled = true;
      sub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Motorista>> streamNovosCandidatos() {
    final controller = StreamController<List<Motorista>>.broadcast();
    try {
      final sub = _supabase
          .from('motoristas')
          .stream(primaryKey: ['id'])
          .eq('status', 'pendente')
          .listen((event) {
            try {
              final list = _toMapList(event);
              final models = list.map((e) => Motorista.fromJson(e)).toList();
              controller.add(models);
            } catch (e, st) {
              debugPrint('Erro no SupabaseService (streamNovosCandidatos): $e');
              controller.addError(e, st);
            }
          });

      controller.onCancel = () => sub.cancel();
    } catch (e) {
      debugPrint('Erro no SupabaseService (streamNovosCandidatos outer): $e');
      controller.addError(e);
    }

    return controller.stream;
  }

  Future<void> aprovarMotorista(String motoristaId) async {
    try {
      await _supabase
          .from('motoristas')
          .update({'status': 'ativo'})
          .eq('id', int.parse(motoristaId));
    } catch (e) {
      debugPrint('Erro no SupabaseService (aprovarMotorista): $e');
      rethrow;
    }
  }

  Future<Motorista?> buscarMotorista(String id) async {
    try {
      final data = await _supabase
          .from('motoristas')
          .select()
          .eq('id', int.parse(id))
          .maybeSingle();
      final map = _toMap(data);
      if (map == null) return null;
      return Motorista.fromJson(map);
    } catch (e) {
      debugPrint('Erro no SupabaseService (buscarMotorista): $e');
      rethrow;
    }
  }

  // ENTREGAS (renomeado de pedidos)
  Future<Entrega> enviarEntrega(Entrega entrega) async {
    try {
      final payload = Map<String, dynamic>.from(entrega.toJson());
      payload.remove('id');
      final inserted = await _supabase
          .from('entregas')
          .insert(payload)
          .select()
          .maybeSingle();
      final map = _toMap(inserted);
      if (map == null) throw Exception('Erro ao criar entrega');
      return Entrega.fromJson(map);
    } catch (e) {
      // Try to provide more detailed info for 400/column errors
      try {
        debugPrint('Erro no SupabaseService (enviarEntrega): ${e.toString()}');
        final payload = Map<String, dynamic>.from(entrega.toJson())
          ..remove('id');
        debugPrint('Payload enviado: ${payload.keys.toList()}');
      } catch (_) {}
      rethrow;
    }
  }

  /// Diagnóstico: tenta inserir uma entrega de teste e imprime erros detalhados.
  /// Use para verificar permissões/RLS do Supabase durante debug.
  Future<void> diagnosticoInserirEntrega() async {
    final now = DateTime.now().toIso8601String();
    final testPayload = {
      'cliente': 'TEST_DIAGNOSTICO',
      'endereco': 'Rua Teste, 123',
      'status': 'pendente',
      'created_at': now,
    };
    try {
      final resp = await _supabase
          .from('entregas')
          .insert(testPayload)
          .select();
      debugPrint('Diagnóstico Supabase: insert OK -> ${resp.toString()}');
    } catch (e) {
      // Printar erro completo para diagnóstico de RLS/permissões
      debugPrint('Diagnóstico Supabase: falha ao inserir entrega de teste: $e');
      // Tentar recuperar info do auth (se disponível) para diagnóstico
      try {
        debugPrint(
          'Diagnóstico Supabase: currentUser=${_supabase.auth.currentUser}',
        );
        debugPrint(
          'Diagnóstico Supabase: currentSession=${_supabase.auth.currentSession}',
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> atualizarStatusEntrega(String entregaId, String status) async {
    try {
      await _supabase
          .from('entregas')
          .update({'status': status})
          .eq('id', int.parse(entregaId));
    } catch (e) {
      debugPrint('Erro no SupabaseService (atualizarStatusEntrega): $e');
      rethrow;
    }
  }

  /// Atualiza localização do motorista (usado pelo app móvel a cada X segundos).
  /// Campos: `lat`, `lng`, `heading` (opcional) e `ultimo_sinal`.
  Future<void> updateMotoristaLocation(String motoristaId, double lat, double lng, {double? heading}) async {
    try {
      final parsed = int.tryParse(motoristaId) ?? motoristaId;
      final payload = <String, dynamic>{
        'lat': lat.toString(),
        'lng': lng.toString(),
        'ultimo_sinal': DateTime.now().toIso8601String(),
      };
      if (heading != null) payload['heading'] = heading.toString();
      await _supabase.from('motoristas').update(payload).eq('id', parsed);
    } catch (e) {
      debugPrint('Erro no SupabaseService (updateMotoristaLocation): $e');
      rethrow;
    }
  }

  /// Marca uma entrega como concluída e, se for a última entrega associada
  /// à rota do motorista, marca a rota como finalizada.
  Future<void> finalizarEntrega(String entregaId) async {
    try {
      // Atualiza status da entrega
      await atualizarStatusEntrega(entregaId, 'entregue');

      // Procurar rotas que contenham esta entrega e ainda não estejam finalizadas
      final rotasData = await _supabase
          .from('rotas')
          .select()
          .neq('status', 'finalizada');
      final rotas = _toMapList(rotasData);
      for (final rota in rotas) {
        try {
          final entregasField = rota['entregas'];
          if (entregasField == null) continue;
          List<dynamic> entregaIds;
          try {
            entregaIds = jsonDecode(entregasField.toString()) as List<dynamic>;
          } catch (_) {
            // não é JSON — tentar interpretar como lista separada por vírgula
            entregaIds = entregasField
                .toString()
                .replaceAll(RegExp(r'[\[\]"]'), '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          final idsStr = entregaIds.map((e) => e.toString()).toList();
          if (!idsStr.contains(entregaId)) continue;

          // Verificar se ainda existem entregas pendentes/não concluídas nessa rota
          final idsToQuery = idsStr.map((s) => int.tryParse(s) ?? s).toList();
          final idsParam = '(${idsToQuery.map((e) => e.toString()).join(',')})';
          final entregasData = await _supabase
              .from('entregas')
              .select()
              .filter('id', 'in', idsParam);
          final todasEntregas = _toMapList(entregasData);
          // Considerar 'entregue' ou 'falha' como finalizadas para a rota.
          final restantes = todasEntregas.where((m) {
            final s = (m['status'] ?? '').toString().toLowerCase();
            return s != 'entregue' && s != 'falha';
          }).toList();
          if (restantes.isEmpty) {
            try {
              await _supabase
                  .from('rotas')
                  .update({'status': 'finalizada', 'finished_at': DateTime.now().toIso8601String()})
                  .eq('id', rota['id']);
            } catch (e) {
              debugPrint('Aviso: falha ao finalizar rota ${rota['id']}: $e');
            }
          }
        } catch (e) {
          debugPrint('Erro ao processar rota para entrega $entregaId: $e');
        }
      }
    } catch (e) {
      debugPrint('Erro no SupabaseService (finalizarEntrega): $e');
      rethrow;
    }
  }

  Stream<List<Entrega>> streamEntregas() {
    // Stream apenas entregas que não foram concluídas
    final controller = StreamController<List<Entrega>>.broadcast();
    bool isCanceled = false;
    StreamSubscription? sub;
    int retrySeconds = 1;

    late void Function() _subscribe;

    void scheduleReconnect() {
      if (isCanceled) return;
      final delay = Duration(seconds: retrySeconds);
      Timer(delay, () {
        if (isCanceled) return;
        retrySeconds = min(retrySeconds * 2, 30);
        _subscribe();
      });
    }

    _subscribe = () {
      try {
        sub = _supabase
          .from('entregas')
          .stream(primaryKey: ['id'])
          .neq('status', 'entregue')
          .listen(
              (event) {
                try {
                  final list = _toMapList(event);
                  var models = list.map((e) => Entrega.fromJson(e)).toList();
                  // Filtrar apenas entregas criadas hoje (same local date)
                  final now = DateTime.now();
                  models = models.where((m) {
                    final d = m.criadoEm;
                    if (d == null) return false;
                    return d.year == now.year && d.month == now.month && d.day == now.day;
                  }).toList();
                  controller.add(models);
                  retrySeconds = 1; // reset on success
                } catch (e, st) {
                  debugPrint('Erro no SupabaseService (streamEntregas): $e');
                  controller.addError(e, st);
                }
              },
              onError: (err) {
                debugPrint('Realtime error (entregas): $err');
                controller.addError(err);
                scheduleReconnect();
              },
              onDone: () {
                if (!isCanceled) scheduleReconnect();
              },
            );
      } catch (e) {
        debugPrint('Erro ao subscrever entregas realtime: $e');
        controller.addError(e);
        scheduleReconnect();
      }
    };

    _subscribe();

    controller.onCancel = () {
      isCanceled = true;
      sub?.cancel();
    };

    return controller.stream;
  }

  Future<List<Entrega>> buscarEntregasPorMotorista(String motoristaId) async {
    try {
      final parsedMotoristaId = int.tryParse(motoristaId) ?? motoristaId;
      final data = await _supabase
          .from('entregas')
          .select()
          .eq('motorista_id', parsedMotoristaId);
      final list = _toMapList(data);
      return list.map((e) => Entrega.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Erro no SupabaseService (buscarEntregasPorMotorista): $e');
      rethrow;
    }
  }

  Future<Entrega?> buscarUltimaEntregaDoMotorista(String motoristaId) async {
    try {
      final parsedMotoristaId = int.tryParse(motoristaId) ?? motoristaId;
      final data = await _supabase
          .from('entregas')
          .select()
          .eq('motorista_id', parsedMotoristaId)
          .order('ordem_entrega', ascending: false)
          .limit(1)
          .maybeSingle();
      final map = _toMap(data);
      if (map == null) return null;
      return Entrega.fromJson(map);
    } catch (e) {
      debugPrint('Erro no SupabaseService (buscarUltimaEntregaDoMotorista): $e');
      rethrow;
    }
  }

  Future<List<Entrega>> buscarEntregasPendentes() async {
    try {
      final data = await _supabase
          .from('entregas')
          .select()
          .eq('status', 'pendente');
      final list = _toMapList(data);
      return list.map((e) => Entrega.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Erro no SupabaseService (buscarEntregasPendentes): $e');
      rethrow;
    }
  }

  Future<List<Motorista>> buscarMotoristas() async {
    try {
      final data = await _supabase.from('motoristas').select();
      final list = _toMapList(data);
      return list.map((e) => Motorista.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Erro no SupabaseService (buscarMotoristas): $e');
      rethrow;
    }
  }

  /// Stream de rotas (todas). Retorna lista de mapas representando linhas da tabela.
  Stream<List<Map<String, dynamic>>> streamRotas() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    bool isCanceled = false;
    StreamSubscription? sub;
    int retrySeconds = 1;

    late void Function() _subscribe;

    void scheduleReconnect() {
      if (isCanceled) return;
      final delay = Duration(seconds: retrySeconds);
      Timer(delay, () {
        if (isCanceled) return;
        retrySeconds = min(retrySeconds * 2, 30);
        _subscribe();
      });
    }
    _subscribe = () {
      try {
        sub = _supabase
            .from('rotas')
            .stream(primaryKey: ['id'])
            .listen((event) {
          try {
            final list = _toMapList(event);
            controller.add(list);
            retrySeconds = 1;
          } catch (e, st) {
            debugPrint('Erro no SupabaseService (streamRotas): $e');
            controller.addError(e, st);
          }
        }, onError: (err) {
          debugPrint('Realtime error (rotas): $err');
          controller.addError(err);
          scheduleReconnect();
        }, onDone: () {
          if (!isCanceled) scheduleReconnect();
        });
      } catch (e) {
        debugPrint('Erro ao subscrever rotas realtime: $e');
        controller.addError(e);
        scheduleReconnect();
      }
    };

    _subscribe();

    controller.onCancel = () {
      isCanceled = true;
      sub?.cancel();
    };

    return controller.stream;
  }

  /// Verifica rotas do motorista e finaliza rotas sem entregas pendentes/em_rota.
  Future<void> checkAndFinalizeRotasForMotorista(String motoristaId) async {
    try {
      final parsedMotorista = int.tryParse(motoristaId) ?? motoristaId;
      final rotasData = await _supabase
          .from('rotas')
          .select()
          .eq('motorista_id', parsedMotorista)
          .neq('status', 'finalizada');
      final rotas = _toMapList(rotasData);
      for (final rota in rotas) {
        try {
          final entregasField = rota['entregas'];
          if (entregasField == null) continue;
          List<dynamic> entregaIds;
          try {
            entregaIds = jsonDecode(entregasField.toString()) as List<dynamic>;
          } catch (_) {
            entregaIds = entregasField
                .toString()
                .replaceAll(RegExp(r'[\[\]"]'), '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }

          final idsToQuery = entregaIds.map((s) => int.tryParse(s.toString()) ?? s).toList();
          final idsParam = '(${idsToQuery.map((e) => e.toString()).join(',')})';
          final entregasData = await _supabase
              .from('entregas')
              .select()
              .filter('id', 'in', idsParam);
          final todas = _toMapList(entregasData);
          // verificar client-side se existem entregas com status pendente ou em_rota
          final pendentes = todas.where((m) {
            final s = (m['status'] ?? '').toString().toLowerCase();
            return s == 'pendente' || s == 'em_rota';
          }).toList();
          if (pendentes.isEmpty) {
            try {
              await _supabase
                  .from('rotas')
                  .update({'status': 'finalizada', 'finished_at': DateTime.now().toIso8601String()})
                  .eq('id', rota['id']);
            } catch (e) {
              debugPrint('Aviso: falha ao finalizar rota ${rota['id']}: $e');
            }
          }
        } catch (e) {
          debugPrint('Erro ao verificar rota ${rota['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Erro em checkAndFinalizeRotasForMotorista: $e');
      rethrow;
    }
  }

  /// Cria uma rota agrupando entregas para um motorista.
  /// Insere um registro na tabela `rotas` com o motorista e ids das entregas.
  Future<void> criarRota(String motoristaId, List<Entrega> entregas) async {
    try {
      // motoristas agora usam UUID/text no banco: tratar motorista_id estritamente como String
      final parsedMotorista = motoristaId;

      final entregaIds = entregas
          .map((e) => int.tryParse(e.id) ?? e.id)
          .toList();
      // Função de debug: retorna payload que seria enviado para o Supabase
      Map<String, dynamic> gerarPayloadRotaDebug() {
        return {
          'motorista_id': parsedMotorista,
          'entregas': jsonEncode(entregaIds),
          'status': 'pendente',
          'created_at': DateTime.now().toIso8601String(),
        };
      }

      // Expose payload generator for local debugging
      // (não realiza nenhuma operação no Supabase)
      // Uso: SupabaseService.instance.gerarPayloadRotaDebug(motoristaId, entregas)
      final payload = {
        'motorista_id': parsedMotorista,
        // persistimos o array como string JSON para compatibilidade com schemas existentes
        'entregas': jsonEncode(entregaIds),
        // Registrar rota como pendente por padrão
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
      };
      // Confirmar: a coluna/field usada para guardar os ids das entregas é exatamente 'entregas'
      assert(payload.keys.contains('entregas'));
      // Debug: imprimir payload completo que será enviado ao Supabase
      try {
        debugPrint('DEBUG: criando rota payload -> ${jsonEncode(payload)}');
      } catch (_) {}

      // Proteção: garantir que o insert não quebre o fluxo (try/catch gigante)
      try {
        await _supabase.from('rotas').insert(payload);
      } catch (e, st) {
        debugPrint('Erro ao inserir rota no Supabase: $e');
        debugPrint(st.toString());
        // Não fazer navegação ou reload — apenas log e continuar
      }

      // Após criar rota, atualizar status das entregas para 'em_rota' em massa
      try {
        // Use filter with 'in' operator to update multiple ids in one call
        final idsParam = '(${entregaIds.map((e) => e.toString()).join(',')})';
        // Atualizar status e atribuir motorista_id (string UUID) nas entregas em massa
        await _supabase
            .from('entregas')
            .update({'status': 'em_rota', 'motorista_id': parsedMotorista})
            .filter('id', 'in', idsParam);
      } catch (err) {
        debugPrint(
          'Aviso: falha ao atualizar status em massa das entregas: $err',
        );
        // fallback: tentar atualizar individualmente
        for (final e in entregas) {
          try {
            // tentar atualizar status e motorista_id individualmente (motorista_id como String)
            await _supabase
                .from('entregas')
                .update({'status': 'em_rota', 'motorista_id': parsedMotorista})
                .eq('id', e.id);
          } catch (err2) {
            debugPrint(
              'Aviso: não foi possível atualizar status da entrega ${e.id}: $err2',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Erro no SupabaseService (criarRota): $e');
      rethrow;
    }
  }

  Future<void> excluirEntrega(String entregaId) async {
    try {
      await _supabase.from('entregas').delete().eq('id', int.parse(entregaId));
    } catch (e) {
      debugPrint('Erro no SupabaseService (excluirEntrega): $e');
      rethrow;
    }
  }

  Future<void> atualizarOrdemEntrega(String entregaId, int ordem) async {
    try {
      await _supabase
          .from('entregas')
          .update({'ordem_entrega': ordem})
          .eq('id', entregaId);
    } catch (e) {
      debugPrint('Erro no SupabaseService (atualizarOrdemEntrega): $e');
      rethrow;
    }
  }

  // MENSAGENS
  Future<Mensagem> enviarMensagemChat({
    required String remetenteId,
    required String destinatarioId,
    required String texto,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Force motorista_id to integer for DB (bigint columns)
      int parsedMotoristaId = 0;
      try {
        parsedMotoristaId = int.parse(destinatarioId.toString());
      } catch (_) {
        // fallback: try to resolve via motorista record (motorista.id)
        try {
          final motorista = await buscarMotorista(destinatarioId);
          parsedMotoristaId = int.tryParse(motorista?.id ?? '') ?? 0;
        } catch (_) {
          parsedMotoristaId = 0;
        }
      }

      if (parsedMotoristaId == 0) {
        throw Exception(
          'motorista_id não resolvido/inteiro para destinatarioId=$destinatarioId',
        );
      }

      final payload = <String, dynamic>{
        'titulo': 'Aviso Gestor',
        'mensagem': texto,
        'motorista_id': int.parse(parsedMotoristaId.toString()),
        'lida': false,
        'created_at': now,
      };

      final inserted = await _supabase
          .from('avisos_gestor')
          .insert(payload)
          .select()
          .maybeSingle();
      final map = _toMap(inserted);
      if (map == null) throw Exception('Erro ao enviar aviso');
      return Mensagem.fromJson(map);
    } catch (e) {
      debugPrint('Erro no SupabaseService (enviarMensagemChat): $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamMensagens(String motoristaId) {
    // Convertemos para int para o filtro do banco usando int.parse
    int intId;
    try {
      intId = int.parse(motoristaId.toString());
    } catch (_) {
      intId = 0;
    }

    return _supabase
        .from('avisos_gestor')
        .stream(primaryKey: ['id'])
        .eq('motorista_id', intId)
        .order('created_at', ascending: true)
        .map(
          (maps) => (maps as List).map<Map<String, dynamic>>((map) {
            final m = Map<String, dynamic>.from(map as Map);
            m['id'] = (m['id'] ?? '').toString();
            m['motorista_id'] = (m['motorista_id'] ?? '').toString();
            return m;
          }).toList(),
        );
  }

  Future<void> marcarMensagemComoLida(String mensagemId) async {
    try {
      await _supabase
          .from('avisos_gestor')
          .update({
            'lida': true,
            'data_leitura': DateTime.now().toIso8601String(),
          })
          .eq('id', int.parse(mensagemId));
    } catch (e) {
      rethrow;
    }
  }
}
