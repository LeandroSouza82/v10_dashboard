class Mensagem {
  final String id;
  final String remetenteId;
  final String destinatarioId;
  final String texto;
  final bool lida;
  final DateTime criadoEm;

  Mensagem({
    required this.id,
    required this.remetenteId,
    required this.destinatarioId,
    required this.texto,
    required this.lida,
    required this.criadoEm,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    final raw = json['criado_em'] ?? json['created_at'];
    DateTime created;
    if (raw is String) {
      created = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is DateTime) {
      created = raw;
    } else {
      created = DateTime.now();
    }

    return Mensagem(
      id: json['id'].toString(),
      remetenteId: (json['remetente_id'] ?? json['remetenteId'] ?? 'gestor')
          .toString(),
      destinatarioId:
          (json['destinatario_id'] ??
                  json['destinatarioId'] ??
                  json['motorista_id'] ??
                  '')
              .toString(),
      texto: (json['texto'] ?? json['mensagem'] ?? '').toString(),
      lida: json['lida'] as bool? ?? false,
      criadoEm: created,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'remetente_id': remetenteId,
    'destinatario_id': destinatarioId,
    'texto': texto,
    'lida': lida,
    'criado_em': criadoEm.toIso8601String(),
  };
}
