import 'dart:convert';
import 'package:flutter/foundation.dart';

void main() {
  final entregas = [
    {'id': '1001'},
    {'id': '1002'},
  ];

  final motoristaId = '42';

  final entregaIds = entregas
      .map((e) => int.tryParse(e['id'] as String) ?? e['id'])
      .toList();
  final payload = {
    'motorista_id': int.tryParse(motoristaId) ?? motoristaId,
    'entregas': jsonEncode(entregaIds),
    'status': 'pendente',
    'created_at': DateTime.now().toIso8601String(),
  };

  debugPrint('DEBUG: payload simulado para criar rota:');
  debugPrint(const JsonEncoder.withIndent('  ').convert(payload));
}
