import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/financeiro_model.dart';
import '../models/calculator_model.dart';
import '../services/financeiro_service.dart';
import '../services/historico_service.dart';

class EstoqueScreen extends StatefulWidget {
  final bool embedded;
  const EstoqueScreen({super.key, required this.embedded});
  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  List<EstoqueFilamento> _estoque = [];
  List<EstoqueMaterialExtra> _estoqueMateriaisExtras = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final dados = await Future.wait([
      FinanceiroService.carregarEstoque(),
      FinanceiroService.carregarEstoqueMateriaisExtras(),
    ]);
    setState(() {
      _estoque = dados[0] as List<EstoqueFilamento>;
      _estoqueMateriaisExtras = dados[1] as List<EstoqueMaterialExtra>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          title: const Text('Estoque',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _abrirNovoItemEstoque,
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Novo item')),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
        onRefresh: _carregar,
        child: _estoque.isEmpty && _estoqueMateriaisExtras.isEmpty
            ? _buildVazio()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                    _buildResumo(),
                    const SizedBox(height: 14),
                    const Text('Filamentos',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    ..._estoque.map(_buildCard),
                    const SizedBox(height: 12),
                    const Text('Materiais extras (unidades)',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    if (_estoqueMateriaisExtras.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: const Text('Nenhum material extra cadastrado',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      ..._estoqueMateriaisExtras.map(_buildCardMaterialExtra),
                    if (widget.embedded)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(children: [
                            OutlinedButton.icon(
                                onPressed: _abrirNovoCarretel,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Novo carretel'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF059669),
                                    side: const BorderSide(
                                        color: Color(0xFF059669)),
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)))),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                                onPressed: _abrirNovoMaterialExtra,
                                icon: const Icon(Icons.add_box_rounded),
                                label: const Text('Novo material extra'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF059669),
                                    side: const BorderSide(
                                        color: Color(0xFF059669)),
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)))),
                          ])),
                  ]));
  }

  Widget _buildVazio() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('📦', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text('Nenhum item no estoque',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: _abrirNovoCarretel,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar carretel'),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF059669),
                side: const BorderSide(color: Color(0xFF059669)))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: _abrirNovoMaterialExtra,
            icon: const Icon(Icons.add_box_rounded),
            label: const Text('Adicionar material extra'),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF059669),
                side: const BorderSide(color: Color(0xFF059669)))),
      ]));

  Widget _buildResumo() {
    final ativos = _estoque.where((e) => !e.esgotado).toList();
    final extrasAtivos =
        _estoqueMateriaisExtras.where((e) => !e.esgotado).toList();
    final totalGasto = _estoque.fold(0.0, (s, e) => s + e.custoTotal);
    final totalGastoExtras =
        _estoqueMateriaisExtras.fold(0.0, (s, e) => s + e.custoTotal);
    final totalRestanteG = ativos.fold(0.0, (s, e) => s + e.pesoRestanteG);
    final totalRestanteExtras =
        extrasAtivos.fold(0, (s, e) => s + e.quantidadeRestante);
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF34D399)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Expanded(
              child:
                  _stat('Carretéis ativos', '${ativos.length}', Colors.white)),
          Expanded(
              child: _stat(
                  'Filamento restante',
                  '${(totalRestanteG / 1000).toStringAsFixed(2)}kg',
                  Colors.white)),
          Expanded(
              child: _stat(
                  'Extras restantes', '$totalRestanteExtras un', Colors.white)),
          Expanded(
              child: _stat(
                  'Total investido',
                  'R\$ ${(totalGasto + totalGastoExtras).toStringAsFixed(0)}',
                  Colors.white)),
        ]));
  }

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(v,
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
        Text(l,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: c.withOpacity(0.8))),
      ]);

  Widget _buildCard(EstoqueFilamento e) {
    final pct = e.percentualUsado;
    final cor = e.esgotado
        ? Colors.grey
        : pct > 0.8
            ? const Color(0xFFEF4444)
            : pct > 0.5
                ? const Color(0xFFF59E0B)
                : const Color(0xFF059669);
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: cor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(
                      child: Text('🧵', style: TextStyle(fontSize: 22)))),
              title: Text(
                  '${e.material}${e.cor.isNotEmpty ? " — ${e.cor}" : ""}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(
                  '${e.marca.isNotEmpty ? e.marca : "Sem marca"} · ${_fmtData(e.dataCompra)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'usar') await _abrirUsarFilamento(e);
                    if (v == 'deletar') await _confirmarRemover(e);
                    if (v == 'usos') await _verUsos(e);
                  },
                  itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'usar',
                            child: Row(children: [
                              Icon(Icons.remove_circle_outline_rounded,
                                  size: 18),
                              SizedBox(width: 8),
                              Text('Registrar uso')
                            ])),
                        const PopupMenuItem(
                            value: 'usos',
                            child: Row(children: [
                              Icon(Icons.history_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Ver histórico de uso')
                            ])),
                        const PopupMenuItem(
                            value: 'deletar',
                            child: Row(children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Remover',
                                  style: TextStyle(color: Colors.red))
                            ])),
                      ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          e.esgotado
                              ? 'Esgotado'
                              : '${e.pesoRestanteG.toStringAsFixed(0)}g restantes',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cor)),
                      Text(
                          '${(pct * 100).toStringAsFixed(0)}% usado · R\$ ${e.custoTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                const SizedBox(height: 6),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: cor.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(cor),
                        minHeight: 8)),
              ])),
        ]));
  }

  Future<void> _abrirNovoCarretel() async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NovoCarretelSheet(onSalvo: _carregar));
  }

  Future<void> _abrirNovoItemEstoque() async {
    await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.water_drop_rounded,
                    color: Color(0xFF059669)),
                title: const Text('Novo carretel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirNovoCarretel();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.add_box_rounded, color: Color(0xFF059669)),
                title: const Text('Novo material extra'),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirNovoMaterialExtra();
                },
              ),
            ])));
  }

  Future<void> _abrirNovoMaterialExtra() async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NovoMaterialExtraSheet(onSalvo: _carregar));
  }

  Future<void> _abrirUsarFilamento(EstoqueFilamento e) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UsarFilamentoSheet(carretel: e, onSalvo: _carregar));
  }

  Future<void> _confirmarRemover(EstoqueFilamento e) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Remover carretel'),
                content: Text(
                    'Remover "${e.material}${e.cor.isNotEmpty ? " ${e.cor}" : ""}"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remover')),
                ]));
    if (ok == true) {
      await FinanceiroService.removerCarretel(e.id);
      await _carregar();
    }
  }

  Future<void> _verUsos(EstoqueFilamento e) async {
    final usos = await FinanceiroService.carregarUsos();
    final usosFil = usos.where((u) => u.idEstoque == e.id).toList();
    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        builder: (_) => _UsoHistoricoSheet(
            carretel: e, usos: usosFil, onRemovido: _carregar));
  }

  Widget _buildCardMaterialExtra(EstoqueMaterialExtra e) {
    final pct = e.percentualUsado;
    final cor = e.esgotado
        ? Colors.grey
        : pct > 0.8
            ? const Color(0xFFEF4444)
            : pct > 0.5
                ? const Color(0xFFF59E0B)
                : const Color(0xFF059669);

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: cor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(
                      child: Text('📦', style: TextStyle(fontSize: 20)))),
              title: Text(e.nome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(
                  '${e.quantidadeRestante} un restantes · R\$ ${e.valorUnitario.toStringAsFixed(2)}/un',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'usar') await _abrirUsarMaterialExtra(e);
                    if (v == 'deletar') await _confirmarRemoverMaterialExtra(e);
                    if (v == 'usos') await _verUsosMaterialExtra(e);
                  },
                  itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'usar',
                            child: Row(children: [
                              Icon(Icons.remove_circle_outline_rounded,
                                  size: 18),
                              SizedBox(width: 8),
                              Text('Registrar uso')
                            ])),
                        const PopupMenuItem(
                            value: 'usos',
                            child: Row(children: [
                              Icon(Icons.history_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Ver histórico de uso')
                            ])),
                        const PopupMenuItem(
                            value: 'deletar',
                            child: Row(children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Remover',
                                  style: TextStyle(color: Colors.red))
                            ])),
                      ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          e.esgotado
                              ? 'Esgotado'
                              : '${e.quantidadeRestante} un restantes',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cor)),
                      Text(
                          '${(pct * 100).toStringAsFixed(0)}% usado · R\$ ${e.custoTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                const SizedBox(height: 6),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: cor.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(cor),
                        minHeight: 8)),
              ])),
        ]));
  }

  Future<void> _abrirUsarMaterialExtra(EstoqueMaterialExtra e) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UsarMaterialExtraSheet(item: e, onSalvo: _carregar));
  }

  Future<void> _confirmarRemoverMaterialExtra(EstoqueMaterialExtra e) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Remover material extra'),
                content: Text('Remover "${e.nome}"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remover')),
                ]));
    if (ok == true) {
      await FinanceiroService.removerMaterialExtra(e.id);
      await _carregar();
    }
  }

  Future<void> _verUsosMaterialExtra(EstoqueMaterialExtra e) async {
    final usos = await FinanceiroService.carregarUsosMateriaisExtras();
    final usosFil =
        usos.where((u) => u.idEstoqueMaterialExtra == e.id).toList();
    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        builder: (_) => _UsoMaterialExtraHistoricoSheet(
            item: e, usos: usosFil, onRemovido: _carregar));
  }

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
    return '${d.day.toString().padLeft(2, '0')}/${m[d.month - 1]}/${d.year}';
  }
}

// ─── Novo carretel ────────────────────────────────────────────────────────────
class _NovoCarretelSheet extends StatefulWidget {
  final VoidCallback onSalvo;
  const _NovoCarretelSheet({required this.onSalvo});
  @override
  State<_NovoCarretelSheet> createState() => _NovoCarretelSheetState();
}

class _NovoCarretelSheetState extends State<_NovoCarretelSheet> {
  final _marcaCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController(text: '1000');
  final _custoCtrl = TextEditingController();
  String _material = 'PLA';

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _corCtrl.dispose();
    _pesoCtrl.dispose();
    _custoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Novo carretel',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field(_marcaCtrl, 'Marca', TextInputType.text)),
              const SizedBox(width: 10),
              Expanded(child: _field(_corCtrl, 'Cor', TextInputType.text)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Material',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF555577))),
                    const SizedBox(height: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                                value: _material,
                                isExpanded: true,
                                items: materiais
                                    .map((m) => DropdownMenuItem(
                                        value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _material = v!)))),
                  ])),
              const SizedBox(width: 10),
              Expanded(child: _field(_pesoCtrl, 'Peso (g)', null, suffix: 'g')),
            ]),
            const SizedBox(height: 10),
            _field(_custoCtrl, 'Custo total pago (R\$)', null, suffix: 'R\$'),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _salvar,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Adicionar ao estoque',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)))),
          ]),
    );
  }

  Future<void> _salvar() async {
    final peso = double.tryParse(_pesoCtrl.text) ?? 0;
    final custo = double.tryParse(_custoCtrl.text) ?? 0;
    if (peso <= 0 || custo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe peso e custo válidos')));
      return;
    }
    await FinanceiroService.salvarCarretel(EstoqueFilamento(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dataCompra: DateTime.now(),
        marca: _marcaCtrl.text.trim(),
        material: _material,
        cor: _corCtrl.text.trim(),
        pesoCompradoG: peso,
        custoTotal: custo));
    widget.onSalvo();
    if (mounted) Navigator.pop(context);
  }

  Widget _field(
          TextEditingController ctrl, String label, TextInputType? keyboard,
          {String? suffix}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555577))),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            keyboardType: keyboard ??
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: keyboard == TextInputType.text
                ? null
                : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: InputDecoration(
                suffixText: suffix,
                suffixStyle: const TextStyle(
                    color: Color(0xFF059669), fontWeight: FontWeight.w600),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF059669), width: 1.8)))),
      ]);
}

// ─── Usar filamento ───────────────────────────────────────────────────────────
class _UsarFilamentoSheet extends StatefulWidget {
  final EstoqueFilamento carretel;
  final VoidCallback onSalvo;
  const _UsarFilamentoSheet({required this.carretel, required this.onSalvo});
  @override
  State<_UsarFilamentoSheet> createState() => _UsarFilamentoSheetState();
}

class _UsarFilamentoSheetState extends State<_UsarFilamentoSheet> {
  final _pesoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<HistoricoItem> _historico = [];
  HistoricoItem? _vinculado;

  @override
  void initState() {
    super.initState();
    HistoricoService.carregar().then((h) => setState(() => _historico = h));
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
                'Registrar uso — ${widget.carretel.material}${widget.carretel.cor.isNotEmpty ? " ${widget.carretel.cor}" : ""}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
                '${widget.carretel.pesoRestanteG.toStringAsFixed(0)}g restantes',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            _field(_pesoCtrl, 'Peso usado (g)', suffix: 'g'),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Descrição', keyboard: TextInputType.text),
            if (_historico.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Vincular a uma peça (opcional)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF555577))),
              const SizedBox(height: 6),
              Container(
                  height: 130,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10)),
                  child: ListView.builder(
                      itemCount: _historico.length,
                      itemBuilder: (ctx, i) {
                        final h = _historico[i];
                        final sel = _vinculado?.id == h.id;
                        return ListTile(
                            dense: true,
                            selected: sel,
                            selectedTileColor:
                                const Color(0xFF059669).withOpacity(0.07),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            title: Text(
                                h.model.nomePeca.isNotEmpty
                                    ? h.model.nomePeca
                                    : 'Sem nome',
                                style: const TextStyle(fontSize: 13)),
                            trailing: sel
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF059669), size: 18)
                                : null,
                            onTap: () =>
                                setState(() => _vinculado = sel ? null : h));
                      })),
            ],
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _salvar,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Registrar',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)))),
          ])),
    );
  }

  Future<void> _salvar() async {
    final peso = double.tryParse(_pesoCtrl.text) ?? 0;
    if (peso <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o peso usado')));
      return;
    }
    if (peso > widget.carretel.pesoRestanteG) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peso maior que o disponível')));
      return;
    }
    await FinanceiroService.registrarUso(UsoFilamento(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        idEstoque: widget.carretel.id,
        data: DateTime.now(),
        pesoUsadoG: peso,
        descricao: _descCtrl.text.trim(),
        idHistorico: _vinculado?.id));
    widget.onSalvo();
    if (mounted) Navigator.pop(context);
  }

  Widget _field(TextEditingController ctrl, String label,
          {String? suffix, TextInputType? keyboard}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555577))),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            keyboardType: keyboard ??
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: keyboard == TextInputType.text
                ? null
                : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: InputDecoration(
                suffixText: suffix,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF059669), width: 1.8)))),
      ]);
}

// ─── Histórico de usos ────────────────────────────────────────────────────────
class _UsoHistoricoSheet extends StatelessWidget {
  final EstoqueFilamento carretel;
  final List<UsoFilamento> usos;
  final VoidCallback onRemovido;
  const _UsoHistoricoSheet(
      {required this.carretel, required this.usos, required this.onRemovido});

  @override
  Widget build(BuildContext context) {
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
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Histórico — ${carretel.material}${carretel.cor.isNotEmpty ? " ${carretel.cor}" : ""}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (usos.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('Nenhum uso registrado',
                          style: TextStyle(color: Colors.grey))))
            else
              SizedBox(
                  height: 300,
                  child: ListView.separated(
                      itemCount: usos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final u = usos[i];
                        return ListTile(
                            dense: true,
                            leading: const Icon(Icons.water_drop_outlined,
                                color: Color(0xFF059669), size: 20),
                            title: Text(
                                u.descricao.isNotEmpty
                                    ? u.descricao
                                    : 'Sem descrição',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                                '${u.data.day.toString().padLeft(2, '0')} ${m[u.data.month - 1]} ${u.data.year}',
                                style: const TextStyle(fontSize: 11)),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${u.pesoUsadoG.toStringAsFixed(0)}g',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444))),
                              IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: Colors.red),
                                  onPressed: () async {
                                    await FinanceiroService.removerUso(u);
                                    onRemovido();
                                    if (context.mounted) Navigator.pop(context);
                                  }),
                            ]));
                      })),
          ]),
    );
  }
}

class _NovoMaterialExtraSheet extends StatefulWidget {
  final VoidCallback onSalvo;
  const _NovoMaterialExtraSheet({required this.onSalvo});

  @override
  State<_NovoMaterialExtraSheet> createState() =>
      _NovoMaterialExtraSheetState();
}

class _NovoMaterialExtraSheetState extends State<_NovoMaterialExtraSheet> {
  final _nomeCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController(text: '100');
  final _valorUnitCtrl = TextEditingController();

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _qtdCtrl.dispose();
    _valorUnitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Novo material extra',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _field(_nomeCtrl, 'Nome (ex: Argola chaveiro)', TextInputType.text),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _field(
                  _qtdCtrl, 'Quantidade comprada', TextInputType.number,
                  suffix: 'un')),
          const SizedBox(width: 10),
          Expanded(
              child: _field(_valorUnitCtrl, 'Valor unitário (R\$)', null,
                  suffix: 'R\$/un')),
        ]),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _salvar,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Adicionar ao estoque',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
      ]),
    );
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    final qtd = int.tryParse(_qtdCtrl.text) ?? 0;
    final valorUnit = double.tryParse(_valorUnitCtrl.text) ?? 0;
    if (nome.isEmpty || qtd <= 0 || valorUnit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Informe nome, quantidade e valor unitário válidos')));
      return;
    }

    await FinanceiroService.salvarMaterialExtra(EstoqueMaterialExtra(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dataCadastro: DateTime.now(),
      nome: nome,
      quantidadeComprada: qtd,
      valorUnitario: valorUnit,
    ));

    widget.onSalvo();
    if (mounted) Navigator.pop(context);
  }

  Widget _field(
          TextEditingController ctrl, String label, TextInputType? keyboard,
          {String? suffix}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555577))),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            keyboardType: keyboard ??
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: keyboard == TextInputType.text
                ? null
                : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: InputDecoration(
                suffixText: suffix,
                suffixStyle: const TextStyle(
                    color: Color(0xFF059669), fontWeight: FontWeight.w600),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF059669), width: 1.8)))),
      ]);
}

class _UsarMaterialExtraSheet extends StatefulWidget {
  final EstoqueMaterialExtra item;
  final VoidCallback onSalvo;
  const _UsarMaterialExtraSheet({required this.item, required this.onSalvo});

  @override
  State<_UsarMaterialExtraSheet> createState() =>
      _UsarMaterialExtraSheetState();
}

class _UsarMaterialExtraSheetState extends State<_UsarMaterialExtraSheet> {
  final _qtdCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Registrar uso — ${widget.item.nome}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text('${widget.item.quantidadeRestante} un restantes',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 14),
        _field(_qtdCtrl, 'Unidades usadas', TextInputType.number, suffix: 'un'),
        const SizedBox(height: 10),
        _field(_descCtrl, 'Descrição', TextInputType.text),
        const SizedBox(height: 14),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _salvar,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Registrar',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
      ]),
    );
  }

  Future<void> _salvar() async {
    final qtd = int.tryParse(_qtdCtrl.text) ?? 0;
    if (qtd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe as unidades usadas')));
      return;
    }
    if (qtd > widget.item.quantidadeRestante) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantidade maior que o disponível')));
      return;
    }

    await FinanceiroService.registrarUsoMaterialExtra(UsoMaterialExtra(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      idEstoqueMaterialExtra: widget.item.id,
      data: DateTime.now(),
      quantidadeUsada: qtd,
      descricao: _descCtrl.text.trim(),
    ));

    widget.onSalvo();
    if (mounted) Navigator.pop(context);
  }

  Widget _field(
          TextEditingController ctrl, String label, TextInputType? keyboard,
          {String? suffix}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555577))),
        const SizedBox(height: 6),
        TextField(
            controller: ctrl,
            keyboardType: keyboard ?? TextInputType.number,
            inputFormatters: keyboard == TextInputType.text
                ? null
                : [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
                suffixText: suffix,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF059669), width: 1.8)))),
      ]);
}

class _UsoMaterialExtraHistoricoSheet extends StatelessWidget {
  final EstoqueMaterialExtra item;
  final List<UsoMaterialExtra> usos;
  final VoidCallback onRemovido;
  const _UsoMaterialExtraHistoricoSheet(
      {required this.item, required this.usos, required this.onRemovido});

  @override
  Widget build(BuildContext context) {
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
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Histórico — ${item.nome}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (usos.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('Nenhum uso registrado',
                      style: TextStyle(color: Colors.grey))))
        else
          SizedBox(
              height: 300,
              child: ListView.separated(
                  itemCount: usos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final u = usos[i];
                    return ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined,
                            color: Color(0xFF059669), size: 20),
                        title: Text(
                            u.descricao.isNotEmpty
                                ? u.descricao
                                : 'Sem descrição',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${u.data.day.toString().padLeft(2, '0')} ${m[u.data.month - 1]} ${u.data.year}',
                            style: const TextStyle(fontSize: 11)),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${u.quantidadeUsada} un',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444))),
                          IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              onPressed: () async {
                                await FinanceiroService.removerUsoMaterialExtra(
                                    u);
                                onRemovido();
                                if (context.mounted) Navigator.pop(context);
                              }),
                        ]));
                  })),
      ]),
    );
  }
}
