import 'package:flutter/material.dart';
import '../widgets/sidebar_pedido.dart';
import '../widgets/painel_mapa.dart';
import '../widgets/chat_motorista.dart';
import '../widgets/gestao_motoristas.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _paginaSelecionada = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth > 800;
          if (desktop) {
            return Row(
              children: [
                SizedBox(width: 350, child: const SidebarPedido()),
                Expanded(
                  child: Column(
                    children: [
                      NavigationBar(
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.map),
                            label: 'Mapa',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.chat),
                            label: 'Chat',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.people),
                            label: 'Gestão',
                          ),
                        ],
                        selectedIndex: _paginaSelecionada,
                        onDestinationSelected: (i) =>
                            setState(() => _paginaSelecionada = i),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _paginaSelecionada,
                          children: [
                            PainelMapa(),
                            ChatMotorista(),
                            GestaoMotoristas(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              IndexedStack(
                index: _paginaSelecionada,
                children: [
                  PainelMapa(),
                  ChatMotorista(),
                  GestaoMotoristas(),
                ],
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Card(
                  elevation: 8,
                  child: BottomNavigationBar(
                    currentIndex: _paginaSelecionada,
                    onTap: (i) => setState(() => _paginaSelecionada = i),
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.map),
                        label: 'Mapa',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.chat),
                        label: 'Chat',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.people),
                        label: 'Gestão',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
