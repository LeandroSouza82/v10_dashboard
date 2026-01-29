# V10 Dashboard — Sistema Logístico Modular

Projeto Flutter modular com arquitetura limpa, Supabase realtime e Google Maps.

Instruções rápidas

1. Coloque suas chaves em `lib/core/constants/api_keys.dart` (já incluídas para exemplo).
2. Instale dependências:

```bash
flutter pub get
```

3. Rodar em debug:

```bash
flutter run -d chrome
```

Estrutura importante:
- `lib/core` — constantes e tema
- `lib/models` — modelos de dados
- `lib/services` — `SupabaseService`
- `lib/widgets` — componentes principais
- `lib/screens` — telas

Observações
- Use Supabase para criar as tabelas: `motoristas`, `pedidos`, `mensagens`. Veja `sql/init.sql`.
- Realtime usa `.stream(primaryKey: ['id'])`.
# v10_dashboard

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
