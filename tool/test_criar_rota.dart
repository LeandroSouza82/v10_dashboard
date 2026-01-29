import 'dart:convert';

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

  print('DEBUG: payload simulado para criar rota:');
  print(const JsonEncoder.withIndent('  ').convert(payload));
}
