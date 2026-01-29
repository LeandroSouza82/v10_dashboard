// ignore_for_file: unnecessary_type_check, dead_code
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._private();
  static final ChatService instance = ChatService._private();
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> enviarAviso({
    required String titulo,
    required String mensagem,
    String? motoristaId,
  }) async {
    try {
      await _supabase.from('avisos_gestor').insert({
        'titulo': titulo,
        'mensagem': mensagem,
        'motorista_id': motoristaId,
        'lida': false,
      });
    } catch (e) {
      debugPrint('Erro no ChatService (enviarAviso): $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> ouvirAvisos(String motoristaId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    try {
      final sub = _supabase
          .from('avisos_gestor')
          .stream(primaryKey: ['id'])
          .listen((event) {
            try {
              final list = <Map<String, dynamic>>[];
              if (event is List) {
                for (final e in event) {
                  list.add(Map<String, dynamic>.from(e as Map));
                }
              } else if (event is Map) {
                list.add(Map<String, dynamic>.from(event as Map));
              }
              final filtered = list
                  .where((e) => (e['motorista_id'] as String?) == motoristaId)
                  .toList();
              controller.add(filtered);
            } catch (e, st) {
              controller.addError(e, st);
            }
          });

      controller.onCancel = () => sub.cancel();
    } catch (e) {
      controller.addError(e);
    }

    return controller.stream;
  }
}
