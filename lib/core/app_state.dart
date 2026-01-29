class AppState {
  AppState._private();

  static final AppState instance = AppState._private();

  /// URL pública do logo da empresa (pode ser nula)
  String? urlLogoEmpresa;
}
