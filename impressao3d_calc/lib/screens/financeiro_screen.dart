import 'package:flutter/material.dart';
import '../models/financeiro_model.dart';
import '../services/financeiro_service.dart';
import 'nova_transacao_screen.dart';
import 'estoque_screen.dart';
import '../widgets/financeiro/resumo_tab.dart';
import '../widgets/financeiro/transacoes_tab.dart';

/// Tela principal da área financeira.
///
/// Exibe três abas: resumo mensal, lista de transações e gestão de estoque.
/// Atua como orquestrador simples: carrega transações via [FinanceiroService],
/// calcula resumo do mês selecionado e delega a renderização para widgets
/// específicos (`ResumoTab`, `TransacoesTab`, `EstoqueScreen`).
class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});
  @override
  State<FinanceiroScreen> createState() => FinanceiroScreenState();
}

class FinanceiroScreenState extends State<FinanceiroScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Transacao> _transacoes = [];
  bool _loading = true;
  late DateTime _mesSelecionado;
  int _estoqueReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month);

    /// Executa o carregamento inicial de transações e estoque.
    /// Mantemos `_estoqueReloadToken` para forçar rebuild do `EstoqueScreen`
    /// quando os dados do serviço mudarem.
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Carrega as transações do repositório ([FinanceiroService]) e atualiza
  /// o estado local. Incrementa `_estoqueReloadToken` para sinalizar ao
  /// `EstoqueScreen` que deve recriar seu estado embutido quando necessário.
  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final t = await FinanceiroService.carregarTransacoes();
    if (!mounted) return;
    setState(() {
      _transacoes = t;
      _estoqueReloadToken++;
      _loading = false;
    });
  }

  /// API pública para forçar recarga dos dados financeiros.
  Future<void> recarregarDados() => _carregar();

  /// Move o mês selecionado para frente/para trás em `delta` meses.
  void _mudarMes(int delta) => setState(() => _mesSelecionado =
      DateTime(_mesSelecionado.year, _mesSelecionado.month + delta));

  @override
  Widget build(BuildContext context) {
    final resumo = FinanceiroService.resumoMes(
        _transacoes, _mesSelecionado.year, _mesSelecionado.month);
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.account_balance_wallet_rounded, size: 22),
          SizedBox(width: 8),
          Text('Financeiro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
        ]),
        bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Resumo'),
              Tab(text: 'Transações'),
              Tab(text: 'Estoque')
            ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (_tabController.index != 2) _buildMesSeletor(),
              Expanded(
                  child: TabBarView(controller: _tabController, children: [
                ResumoTab(
                    transacoes: _transacoes,
                    mesSelecionado: _mesSelecionado,
                    resumo: resumo),
                TransacoesTab(
                    transacoes: _transacoes
                        .where((t) =>
                            t.data.year == _mesSelecionado.year &&
                            t.data.month == _mesSelecionado.month)
                        .toList(),
                    onRefresh: _carregar),
                EstoqueScreen(
                    key: ValueKey(_estoqueReloadToken), embedded: true),
              ])),
            ]),
      floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (ctx, _) {
            if (_tabController.index == 2)
              return FloatingActionButton.extended(
                  heroTag: 'fab_estoque',
                  onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const EstoqueScreen(embedded: false)))
                      .then((_) => setState(() {})),
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo item'));
            return Column(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton(
                  heroTag: 'fab_despesa',
                  mini: true,
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  tooltip: 'Nova despesa',
                  onPressed: () => _abrirNovaTransacao(TipoTransacao.despesa),
                  child: const Icon(Icons.remove_rounded)),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                  heroTag: 'fab_receita',
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova receita'),
                  onPressed: () => _abrirNovaTransacao(TipoTransacao.receita)),
            ]);
          }),
    );
  }

  /// Constrói o seletor de mês usado pela aba de `Resumo` e `Transações`.
  /// Fornece controles para navegar entre meses e voltar ao mês atual.
  Widget _buildMesSeletor() {
    final meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    final agora = DateTime.now();
    final ehAtual = _mesSelecionado.year == agora.year &&
        _mesSelecionado.month == agora.month;
    return Container(
        color: const Color(0xFF059669),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
              onPressed: () => _mudarMes(-1)),
          GestureDetector(
              onTap: ehAtual
                  ? null
                  : () => setState(() =>
                      _mesSelecionado = DateTime(agora.year, agora.month)),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      '${meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)))),
          IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: ehAtual ? Colors.white30 : Colors.white),
              onPressed: ehAtual ? null : () => _mudarMes(1)),
        ]));
  }

  /// Navega até a tela de criação de nova transação (`NovaTransacaoScreen`).
  /// Após retorno (quando nova transação foi criada), recarrega os dados para
  /// refletir a alteração no resumo e na lista de transações.
  Future<void> _abrirNovaTransacao(TipoTransacao tipo) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NovaTransacaoScreen(tipoInicial: tipo)));
    await _carregar();
  }
}
