import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/calculator_screen.dart';
import 'screens/financeiro_screen.dart';
import 'screens/pedidos_screen.dart';
import 'services/backup_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const Impressao3DApp());
}

class Impressao3DApp extends StatelessWidget {
  const Impressao3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C3CE1), brightness: Brightness.light),
        fontFamily: 'Roboto',
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _financeiroKey = GlobalKey<FinanceiroScreenState>();
  final _pedidosKey = GlobalKey<PedidosScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      CalculatorScreen(),
      PedidosScreen(key: _pedidosKey),
      FinanceiroScreen(key: _financeiroKey)
    ];
    WidgetsBinding.instance.addObserver(this);
    // Tenta login silencioso ao abrir
    BackupService.signInSilently();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Faz backup automático quando o app vai para segundo plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pequeno delay para garantir credenciais prontas
      Future.delayed(const Duration(milliseconds: 500), () {
        BackupService.fazerBackup();
      });
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _recarregarFinanceiroSeAtivo();
      _recarregarPedidosSeAtivo();
    }
  }

  void _recarregarFinanceiroSeAtivo() {
    if (_index == 2) {
      _financeiroKey.currentState?.recarregarDados();
    }
  }

  void _recarregarPedidosSeAtivo() {
    if (_index == 1) {
      _pedidosKey.currentState?.recarregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 2) {
            _recarregarFinanceiroSeAtivo();
          }
          if (i == 1) {
            _recarregarPedidosSeAtivo();
          }
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF6C3CE1).withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_in_ar_outlined),
            selectedIcon:
                Icon(Icons.view_in_ar_rounded, color: Color(0xFF6C3CE1)),
            label: 'Calculadora',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon:
                Icon(Icons.assignment_rounded, color: Color(0xFF6C3CE1)),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: Color(0xFF059669)),
            label: 'Financeiro',
          ),
        ],
      ),
    );
  }
}
