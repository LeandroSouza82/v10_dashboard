// import 'package:flutter/foundation.dart'; // not needed

enum PedidoStatus { pendente, aceito, emTransito, entregue, cancelado }

class Pedido {
  final String id;
  final String nomeCliente;
  final String? telefoneCliente;
  final String endereco;
  final double? enderecoLatitude;
  final double? enderecoLongitude;
  final String? motoristaId;
  final String? observacoes;
  final PedidoStatus status;
  final double? valor;
  final DateTime criadoEm;

  Pedido({
    required this.id,
    required this.nomeCliente,
    this.telefoneCliente,
    required this.endereco,
    this.enderecoLatitude,
    this.enderecoLongitude,
    this.motoristaId,
    this.observacoes,
    required this.status,
    this.valor,
    required this.criadoEm,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    final raw = json['criado_em'] ?? json['created_at'];
    DateTime created;
    if (raw is String) {
      created = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is DateTime) {
      created = raw;
    } else {
      created = DateTime.now();
    }

    PedidoStatus status = PedidoStatus.pendente;
    final s = json['status'] as String?;
    if (s != null) {
      switch (s) {
        case 'aceito':
          status = PedidoStatus.aceito;
          break;
        case 'emTransito':
        case 'em_transito':
          status = PedidoStatus.emTransito;
          break;
        case 'entregue':
          status = PedidoStatus.entregue;
          break;
        case 'cancelado':
          status = PedidoStatus.cancelado;
          break;
        default:
          status = PedidoStatus.pendente;
      }
    }

    return Pedido(
      id: json['id'] as String,
      nomeCliente:
          json['nome_cliente'] as String? ??
          json['nomeCliente'] as String? ??
          '',
      telefoneCliente:
          json['telefone_cliente'] as String? ??
          json['telefoneCliente'] as String?,
      endereco: json['endereco'] as String? ?? '',
      enderecoLatitude: (json['endereco_latitude'] is num)
          ? (json['endereco_latitude'] as num).toDouble()
          : (json['enderecoLatitude'] is num
                ? (json['enderecoLatitude'] as num).toDouble()
                : null),
      enderecoLongitude: (json['endereco_longitude'] is num)
          ? (json['endereco_longitude'] as num).toDouble()
          : (json['enderecoLongitude'] is num
                ? (json['enderecoLongitude'] as num).toDouble()
                : null),
      motoristaId:
          json['motorista_id'] as String? ?? json['motoristaId'] as String?,
      observacoes: json['observacoes'] as String?,
      status: status,
      valor: (json['valor'] is num) ? (json['valor'] as num).toDouble() : null,
      criadoEm: created,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome_cliente': nomeCliente,
    'telefone_cliente': telefoneCliente,
    'endereco': endereco,
    'endereco_latitude': enderecoLatitude,
    'endereco_longitude': enderecoLongitude,
    'motorista_id': motoristaId,
    'observacoes': observacoes,
    'status': status.name,
    'valor': valor,
    'criado_em': criadoEm.toIso8601String(),
  };

  Pedido copyWith({
    String? id,
    String? nomeCliente,
    String? telefoneCliente,
    String? endereco,
    double? enderecoLatitude,
    double? enderecoLongitude,
    String? motoristaId,
    String? observacoes,
    PedidoStatus? status,
    double? valor,
    DateTime? criadoEm,
  }) {
    return Pedido(
      id: id ?? this.id,
      nomeCliente: nomeCliente ?? this.nomeCliente,
      telefoneCliente: telefoneCliente ?? this.telefoneCliente,
      endereco: endereco ?? this.endereco,
      enderecoLatitude: enderecoLatitude ?? this.enderecoLatitude,
      enderecoLongitude: enderecoLongitude ?? this.enderecoLongitude,
      motoristaId: motoristaId ?? this.motoristaId,
      observacoes: observacoes ?? this.observacoes,
      status: status ?? this.status,
      valor: valor ?? this.valor,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}
