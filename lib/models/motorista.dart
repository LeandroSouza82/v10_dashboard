class Motorista {
  final String id;
  final String nome;
  final String? sobrenome;
  final String? telefone;
  final String cpf;
  final String placaVeiculo;
  final bool estaOnline;
  final String status; // 'ativo', 'pendente', 'inativo'
  final String? fcmToken;
  final String? lat;
  final String? lng;
  final String? email;
  final String? avatarPath;
  final DateTime? ultimoSinal;
  final String? acesso;
  final String? userId;

  double? get latitude => lat != null ? double.tryParse(lat!) : null;
  double? get longitude => lng != null ? double.tryParse(lng!) : null;

  Motorista({
    required this.id,
    required this.nome,
    this.sobrenome,
    this.telefone,
    required this.cpf,
    required this.placaVeiculo,
    required this.estaOnline,
    required this.status,
    this.fcmToken,
    this.lat,
    this.lng,
    this.email,
    this.avatarPath,
    this.ultimoSinal,
    this.acesso,
    this.userId,
  });

  factory Motorista.fromJson(Map<String, dynamic> json) {
    return Motorista(
      id: json['id'].toString(),
      nome: json['nome'] as String? ?? 'Motorista',
      sobrenome: json['sobrenome'] as String?,
      telefone: json['telefone'] as String?,
      cpf: json['cpf'] as String? ?? '',
      placaVeiculo: json['placa_veiculo'] as String? ?? '',
      estaOnline: json['esta_online'] as bool? ?? false,
      status: json['status'] as String? ?? 'pendente',
      fcmToken: json['fcm_token'] as String?,
      lat: json['lat'] as String?,
      lng: json['lng'] as String?,
      email: json['email'] as String?,
      avatarPath: json['avatar_path'] as String?,
      ultimoSinal: json['ultimo_sinal'] != null
          ? DateTime.tryParse(json['ultimo_sinal'].toString())
          : null,
      acesso: json['acesso'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': int.parse(id),
      'nome': nome,
      'sobrenome': sobrenome,
      'telefone': telefone,
      'cpf': cpf,
      'placa_veiculo': placaVeiculo,
      'esta_online': estaOnline,
      'status': status,
      'fcm_token': fcmToken,
      'lat': lat,
      'lng': lng,
      'email': email,
      'avatar_path': avatarPath,
      'ultimo_sinal': ultimoSinal?.toIso8601String(),
      'acesso': acesso,
      'user_id': userId,
    };
  }
}
