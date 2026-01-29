class Entrega {
  final String id;
  final String cliente;
  final String endereco;
  final String cidade;
  final String status;
  final String? motoristaId;
  final String? obs;
  final String tipo;
  final String? assinaturaUrl;
  final String? motivoNaoEntrega;
  final String? recebedor;
  final String? tipoRecebedor;
  final double? lat;
  final double? lng;
  final double? latConclusao;
  final double? lngConclusao;
  final DateTime? dataEntrega;
  final DateTime? dataConclusao;
  final DateTime? horarioConclusao;
  final DateTime? criadoEm;
  final Map<String, dynamic>? rota;

  Entrega({
    required this.id,
    required this.cliente,
    required this.endereco,
    required this.cidade,
    required this.status,
    this.motoristaId,
    this.obs,
    required this.tipo,
    this.assinaturaUrl,
    this.motivoNaoEntrega,
    this.recebedor,
    this.tipoRecebedor,
    this.lat,
    this.lng,
    this.latConclusao,
    this.lngConclusao,
    this.dataEntrega,
    this.dataConclusao,
    this.horarioConclusao,
    this.criadoEm,
    this.rota,
  });

  factory Entrega.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Entrega(
      id: json['id']?.toString() ?? '',
      cliente: json['cliente'] as String? ?? '',
      endereco: json['endereco'] as String? ?? '',
      cidade: json['cidade'] as String? ?? '',
      status: json['status'] as String? ?? 'pendente',
      motoristaId: json['motorista_id'] as String?,
      obs: json['obs'] as String? ?? json['observacoes'] as String?,
      tipo: json['tipo'] as String? ?? 'normal',
      assinaturaUrl: json['assinatura_url'] as String?,
      motivoNaoEntrega: json['motivo_nao_entrega'] as String?,
      recebedor: json['recebedor'] as String?,
      tipoRecebedor: json['tipo_recebedor'] as String?,
      lat: parseDouble(json['lat']),
      lng: parseDouble(json['lng']),
      latConclusao: parseDouble(json['lat_conclusao']),
      lngConclusao: parseDouble(json['lng_conclusao']),
      dataEntrega: parseDate(json['data_entrega']),
      dataConclusao: parseDate(json['data_conclusao']),
      horarioConclusao: parseDate(json['horario_conclusao']),
      criadoEm: parseDate(json['criado_em'] ?? json['created_at']),
      rota: (json['rota'] is Map)
          ? Map<String, dynamic>.from(json['rota'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': int.parse(id),
      'cliente': cliente,
      'endereco': endereco,
      'cidade': cidade,
      'status': status,
      'motorista_id': motoristaId,
      'observacoes': obs,
      'tipo': tipo,
      'assinatura_url': assinaturaUrl,
      'motivo_nao_entrega': motivoNaoEntrega,
      'recebedor': recebedor,
      'tipo_recebedor': tipoRecebedor,
      'lat': lat,
      'lng': lng,
      'lat_conclusao': latConclusao,
      'lng_conclusao': lngConclusao,
      'data_entrega': dataEntrega?.toIso8601String(),
      'data_conclusao': dataConclusao?.toIso8601String(),
      'horario_conclusao': horarioConclusao?.toIso8601String(),
      'criado_em': criadoEm?.toIso8601String(),
      'rota': rota,
    };
  }
}
