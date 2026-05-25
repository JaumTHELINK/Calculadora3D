import 'package:flutter/material.dart';
import '../models/calculator_model.dart';
import '../services/historico_service.dart';
import 'pedidos_screen.dart';

/// Tela que lista cálculos salvos (histórico).
///
/// Permite buscar, filtrar por material/categoria, gerenciar categorias e
/// carregar um cálculo de volta para a calculadora. Também expõe uma ação
/// para criar um pedido a partir de um projeto salvo.
class HistoricoScreen extends StatefulWidget {
  final Function(CalculatorModel)? onCarregarCalculo;
  const HistoricoScreen({super.key, this.onCarregarCalculo});
  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<HistoricoItem> _itens = [];
  List<String> _categorias = [];
  bool _loading = true;
  final TextEditingController _buscaCtrl = TextEditingController();
  String _filtroMaterial = 'Todos';
  String _filtroCategoria = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final lista = await HistoricoService.carregar();
    final categorias = await HistoricoService.carregarCategorias();
    setState(() {
      _itens = lista;
      _categorias = categorias;
      _loading = false;
    });
  }

  /// Recarrega lista de projetos e categorias do serviço de histórico.
  /// Chamado em initState e após operações que alteram o armazenamento.

  Future<String?> _inputTexto({
    required String titulo,
    String valorInicial = '',
  }) async {
    final ctrl = TextEditingController(text: valorInicial);
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Digite um nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final texto = ctrl.text.trim();
              Navigator.pop(ctx, texto.isEmpty ? null : texto);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return resultado;
  }

  Future<void> _gerenciarCategorias() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> atualizar() async {
            final categorias = await HistoricoService.carregarCategorias();
            setDialogState(() {
              _categorias = categorias;
            });
            await _carregar();
          }

          return AlertDialog(
            title: const Text('Categorias dos projetos'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final nova =
                            await _inputTexto(titulo: 'Nova categoria');
                        if (nova == null) return;
                        await HistoricoService.salvarCategoria(nova);
                        await atualizar();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categorias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final categoria = _categorias[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(categoria),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Renomear',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final novo = await _inputTexto(
                                    titulo: 'Renomear categoria',
                                    valorInicial: categoria,
                                  );
                                  if (novo == null) return;
                                  await HistoricoService.renomearCategoria(
                                      categoria, novo);
                                  await atualizar();
                                },
                              ),
                              IconButton(
                                tooltip: 'Remover',
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red),
                                onPressed: categoria ==
                                        HistoricoService.categoriaPadrao
                                    ? null
                                    : () async {
                                        await HistoricoService.removerCategoria(
                                            categoria);
                                        await atualizar();
                                      },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Abre um diálogo para gerenciar (adicionar/renomear/remover) categorias
  /// usadas para agrupar os projetos salvos.

  Future<void> _abrirPedido(HistoricoItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PedidosScreen(historicoInicialId: item.id),
      ),
    );
    await _carregar();
  }

  /// Navega para a tela de pedidos inicializando com o projeto selecionado.

  Future<void> _remover(HistoricoItem item) async {
    await HistoricoService.remover(item.id);
    await _carregar();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cálculo removido'), duration: Duration(seconds: 2)));
  }

  /// Remove um cálculo do histórico e mostra uma confirmação via Snackbar.

  Future<void> _limparTudo() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Limpar histórico'),
              content: const Text('Deseja apagar todos os cálculos salvos?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Apagar tudo')),
              ],
            ));
    if (ok == true) {
      await HistoricoService.limparTudo();
      await _carregar();
    }
  }

  /// Limpa todo o histórico (usuário confirmando a ação).

  @override
  Widget build(BuildContext context) {
    final itensFiltrados = _itens.where((item) {
      final nome = item.model.nomePeca.toLowerCase();
      final busca = _buscaCtrl.text.trim().toLowerCase();
      final passouBusca = busca.isEmpty || nome.contains(busca);
      final passouMaterial = _filtroMaterial == 'Todos' ||
          item.model.materialSelecionado == _filtroMaterial;
      final categoria = item.categoria.trim().isEmpty
          ? HistoricoService.categoriaPadrao
          : item.categoria.trim();
      final passouCategoria =
          _filtroCategoria == 'Todas' || categoria == _filtroCategoria;
      return passouBusca && passouMaterial && passouCategoria;
    }).toList();

    final materiais = <String>{
      ..._itens
          .map((e) => e.model.materialSelecionado)
          .where((m) => m.isNotEmpty)
    }.toList()
      ..sort();

    final categoriasAtivas = <String>{
      HistoricoService.categoriaPadrao,
      ..._itens.map((e) => e.categoria.trim().isEmpty
          ? HistoricoService.categoriaPadrao
          : e.categoria.trim())
    }.toList()
      ..sort();

    final itensPorCategoria = <String, List<HistoricoItem>>{};
    for (final item in itensFiltrados) {
      final categoria = item.categoria.trim().isEmpty
          ? HistoricoService.categoriaPadrao
          : item.categoria.trim();
      itensPorCategoria.putIfAbsent(categoria, () => []).add(item);
    }

    final categoriasExibidas = _filtroCategoria == 'Todas'
        ? categoriasAtivas
            .where((c) => itensPorCategoria.containsKey(c))
            .toList()
        : [_filtroCategoria];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.history_rounded, size: 20),
          SizedBox(width: 8),
          Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700))
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Categorias',
            onPressed: _gerenciarCategorias,
          ),
          if (_itens.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: _limparTudo)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _itens.isEmpty
              ? _buildVazio()
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(children: [
                      _buildResumo(itensFiltrados),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _buscaCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar projeto salvo...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _buscaCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _buscaCtrl.clear();
                                    setState(() {});
                                  }),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF6C3CE1), width: 1.8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Text('Material:',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filtroMaterial,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: 'Todos', child: Text('Todos')),
                              ...materiais.map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m))),
                            ],
                            onChanged: (v) =>
                                setState(() => _filtroMaterial = v ?? 'Todos'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Text('Categoria:',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filtroCategoria,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: 'Todas', child: Text('Todas')),
                              ...categoriasAtivas.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) =>
                                setState(() => _filtroCategoria = v ?? 'Todas'),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  Expanded(
                    child: itensFiltrados.isEmpty
                        ? const Center(
                            child: Text(
                                'Nenhum projeto encontrado com esse filtro',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              for (final categoria in categoriasExibidas) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    categoria,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6C3CE1),
                                    ),
                                  ),
                                ),
                                ...?itensPorCategoria[categoria]
                                    ?.map(_buildCard)
                                    .toList(),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                  ),
                ]),
    );
  }

  Widget _buildResumo(List<HistoricoItem> itens) {
    final total = itens.length;
    final media = total == 0
        ? 0.0
        : itens.fold(0.0, (s, e) => s + e.model.custoTotalSemMargem) / total;
    final ultimo = itens.isEmpty ? null : itens.first.data;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6C3CE1), Color(0xFF9B6DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('Projetos', '$total'),
          _stat('Custo médio', _fmt(media)),
          _stat('Último', ultimo == null ? '-' : _fmtDataCurta(ultimo)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      );

  Widget _buildVazio() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('Nenhum cálculo salvo ainda',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
      ]));

  Widget _buildCard(HistoricoItem item) {
    final m = item.model;
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(16)),
          child:
              const Icon(Icons.delete_rounded, color: Colors.white, size: 28)),
      onDismissed: (_) => _remover(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ]),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (widget.onCarregarCalculo != null)
              showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        title: const Text('Carregar cálculo'),
                        content: Text(
                            'Carregar "${m.nomePeca.isNotEmpty ? m.nomePeca : 'Sem nome'}"?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar')),
                          FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onCarregarCalculo!(m);
                                Navigator.pop(context);
                              },
                              child: const Text('Carregar')),
                        ],
                      ));
          },
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              m.nomePeca.isNotEmpty ? m.nomePeca : 'Sem nome',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E)))),
                      IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 20),
                          onPressed: () => _remover(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints()),
                    ]),
                    Text(_fmtData(item.data),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _chip(m.materialSelecionado, const Color(0xFF6C3CE1)),
                      const SizedBox(width: 8),
                      _chip('${m.pesoTotal.toStringAsFixed(0)}g', Colors.grey),
                      const SizedBox(width: 8),
                      if (m.tempoImpressaoHoras > 0)
                        _chip('${m.tempoImpressaoHoras.toStringAsFixed(1)}h',
                            const Color(0xFF3B82F6)),
                      if (m.multiCor) ...[
                        const SizedBox(width: 8),
                        _chip('Multi-cor', const Color(0xFF8B5CF6)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    _chip(
                        item.categoria.trim().isEmpty
                            ? HistoricoService.categoriaPadrao
                            : item.categoria.trim(),
                        const Color(0xFF059669)),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _val('Custo total', m.custoTotalSemMargem,
                              Colors.grey.shade700),
                          _val('Padrão (40%)', m.precoPadrao,
                              const Color(0xFF3B82F6)),
                          _val('Premium (60%)', m.precoPremium,
                              const Color(0xFFF59E0B)),
                        ]),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _abrirPedido(item),
                            icon:
                                const Icon(Icons.assignment_outlined, size: 16),
                            label: const Text('Pedido'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF059669),
                                side:
                                    const BorderSide(color: Color(0xFF059669)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              if (widget.onCarregarCalculo != null) {
                                widget.onCarregarCalculo!(m);
                                Navigator.pop(context);
                              }
                            },
                            icon:
                                const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Carregar cálculo'),
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6C3CE1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                        ],
                      ),
                    ),
                  ])),
        ),
      ),
    );
  }

  Widget _chip(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(l,
          style:
              TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)));

  Widget _val(String l, double v, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(_fmt(v),
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
      ]);

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtDataCurta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  String _fmtData(DateTime d) {
    final m = [
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
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
