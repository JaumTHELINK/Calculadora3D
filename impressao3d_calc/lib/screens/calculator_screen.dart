import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calculator_model.dart';
import '../models/financeiro_model.dart';
import '../services/financeiro_service.dart';
import '../services/historico_service.dart';
import '../services/preferencias_service.dart';
import '../widgets/section_card.dart';
import '../widgets/input_field.dart';
import '../widgets/price_card.dart';
import '../widgets/cost_breakdown.dart';
import 'historico_screen.dart';
import 'configuracoes_screen.dart';
import 'nova_transacao_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  final CalculatorModel _model = CalculatorModel();
  late TabController _tabController;
  Timer? _prefsDebounce;

  final _nomePecaCtrl = TextEditingController();
  final _custoPorKgCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _tempoHrsCtrl = TextEditingController();
  final _tempoMaoDeObraCtrl = TextEditingController();
  final _valorHoraMaoDeObraCtrl = TextEditingController();
  final _custoHardwareCtrl = TextEditingController();
  final _custoEmbalagemCtrl = TextEditingController();
  final _potenciaCtrl = TextEditingController();
  final _tarifaEnergiaCtrl = TextEditingController();
  final _taxaIVACtrl = TextEditingController();
  final _depreciacaoCtrl = TextEditingController();
  final _margemCtrl = TextEditingController(text: '50');
  final _qtdLoteCtrl = TextEditingController(text: '1');

  final List<TextEditingController> _corNomeCtrlList = [];
  final List<TextEditingController> _corPesoCtrlList = [];
  final List<TextEditingController> _corCustoKgCtrlList = [];
  final List<String> _corMaterialList = [];
  final List<TextEditingController> _extraNomeCtrlList = [];
  final List<TextEditingController> _extraValorCtrlList = [];
  List<EstoqueFilamento> _estoqueFilamentos = [];
  String? _carretelSelecionadoId;

  int _qtdLote = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarPreferencias();
    _carregarEstoqueFilamentos();
  }

  @override
  void dispose() {
    _prefsDebounce?.cancel();
    _tabController.dispose();
    for (var c in [
      _nomePecaCtrl,
      _custoPorKgCtrl,
      _pesoCtrl,
      _tempoHrsCtrl,
      _tempoMaoDeObraCtrl,
      _valorHoraMaoDeObraCtrl,
      _custoHardwareCtrl,
      _custoEmbalagemCtrl,
      _potenciaCtrl,
      _tarifaEnergiaCtrl,
      _taxaIVACtrl,
      _depreciacaoCtrl,
      _margemCtrl,
      _qtdLoteCtrl
    ]) {
      c.dispose();
    }
    for (var c in [
      ..._corNomeCtrlList,
      ..._corPesoCtrlList,
      ..._corCustoKgCtrlList,
      ..._extraNomeCtrlList,
      ..._extraValorCtrlList
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarPreferencias() async {
    final p = await PreferenciasService.carregar();
    setState(() {
      _model.materialSelecionado = p['material'];
      _custoPorKgCtrl.text = _fmtP(p['custoPorKg']);
      _potenciaCtrl.text = _fmtP(p['potencia']);
      _tarifaEnergiaCtrl.text = _fmtP(p['tarifaEnergia']);
      _valorHoraMaoDeObraCtrl.text = _fmtP(p['valorHora']);
      if ((p['custoEmbalagem'] as double) > 0)
        _custoEmbalagemCtrl.text = _fmtP(p['custoEmbalagem']);
      if ((p['taxaIVA'] as double) > 0) _taxaIVACtrl.text = _fmtP(p['taxaIVA']);
      if ((p['depreciacao'] as double) > 0)
        _depreciacaoCtrl.text = _fmtP(p['depreciacao']);
      final plats = p['plataformas'] as List<PlataformaConfig>;
      _model.plataformas = plats
          .map((pl) => PlataformaConfig(
              nome: pl.nome,
              taxa: pl.taxa,
              taxaFixa: pl.taxaFixa,
              ativa: false))
          .toList();
      _update();
    });
  }

  String _fmtP(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  void _salvarPreferencias() {
    PreferenciasService.salvarMaterial(_model.materialSelecionado);
    if (_model.custoPorKg > 0)
      PreferenciasService.salvarCustoPorKg(_model.custoPorKg);
    if (_model.potenciaImpressoraWatts > 0)
      PreferenciasService.salvarPotencia(_model.potenciaImpressoraWatts);
    if (_model.tarifaEnergia > 0)
      PreferenciasService.salvarTarifaEnergia(_model.tarifaEnergia);
    if (_model.valorHoraMaoDeObra > 0)
      PreferenciasService.salvarValorHora(_model.valorHoraMaoDeObra);
    PreferenciasService.salvarCustoEmbalagem(_model.custoEmbalagem);
    PreferenciasService.salvarTaxaIVA(_model.taxaIVA);
    PreferenciasService.salvarDepreciacao(_model.custoDepreciacao);
  }

  void _agendarSalvarPreferencias() {
    _prefsDebounce?.cancel();
    _prefsDebounce =
        Timer(const Duration(milliseconds: 700), _salvarPreferencias);
  }

  Future<void> _carregarEstoqueFilamentos() async {
    final estoque = await FinanceiroService.carregarEstoque();
    if (!mounted) return;
    setState(() {
      _estoqueFilamentos = estoque.where((e) => !e.esgotado).toList();
      if (_carretelSelecionadoId != null &&
          !_estoqueFilamentos.any((e) => e.id == _carretelSelecionadoId)) {
        _carretelSelecionadoId = null;
      }
    });
  }

  void _aplicarCarretelEstoque(String? id) {
    setState(() {
      _carretelSelecionadoId = id;
      if (id == null) return;
      final carretel = _estoqueFilamentos.firstWhere((e) => e.id == id);
      _model.materialSelecionado = carretel.material;
      _custoPorKgCtrl.text = _fmtP(carretel.custoPorG * 1000);
    });
    _update();
  }

  void _update() {
    setState(() {
      _model.nomePeca = _nomePecaCtrl.text;
      _model.custoPorKg = double.tryParse(_custoPorKgCtrl.text) ?? 0;
      _model.pesoGramas = double.tryParse(_pesoCtrl.text) ?? 0;
      _model.tempoImpressaoHoras = double.tryParse(_tempoHrsCtrl.text) ?? 0;
      _model.tempoMaoDeObraMinutos =
          double.tryParse(_tempoMaoDeObraCtrl.text) ?? 0;
      _model.valorHoraMaoDeObra =
          double.tryParse(_valorHoraMaoDeObraCtrl.text) ?? 0;
      _model.custoHardware = double.tryParse(_custoHardwareCtrl.text) ?? 0;
      _model.custoEmbalagem = double.tryParse(_custoEmbalagemCtrl.text) ?? 0;
      _model.potenciaImpressoraWatts = double.tryParse(_potenciaCtrl.text) ?? 0;
      _model.tarifaEnergia = double.tryParse(_tarifaEnergiaCtrl.text) ?? 0;
      _model.taxaIVA = double.tryParse(_taxaIVACtrl.text) ?? 0;
      _model.custoDepreciacao = double.tryParse(_depreciacaoCtrl.text) ?? 0;
      _model.cores = List.generate(
          _corNomeCtrlList.length,
          (i) => CorFilamento(
              nome: _corNomeCtrlList[i].text,
              material:
                  i < _corMaterialList.length ? _corMaterialList[i] : 'PLA',
              pesoGramas: double.tryParse(_corPesoCtrlList[i].text) ?? 0,
              custoPorKg: double.tryParse(_corCustoKgCtrlList[i].text) ?? 0));
      _model.materiaisExtras = List.generate(
          _extraNomeCtrlList.length,
          (i) => MaterialExtra(
              nome: _extraNomeCtrlList[i].text,
              custo: double.tryParse(_extraValorCtrlList[i].text) ?? 0));
    });
    _agendarSalvarPreferencias();
  }

  void _addCor() {
    setState(() {
      _corNomeCtrlList.add(TextEditingController());
      _corPesoCtrlList.add(TextEditingController());
      _corCustoKgCtrlList
          .add(TextEditingController(text: _custoPorKgCtrl.text));
      _corMaterialList.add(_model.materialSelecionado);
    });
  }

  void _removeCor(int i) {
    setState(() {
      _corNomeCtrlList[i].dispose();
      _corPesoCtrlList[i].dispose();
      _corCustoKgCtrlList[i].dispose();
      _corNomeCtrlList.removeAt(i);
      _corPesoCtrlList.removeAt(i);
      _corCustoKgCtrlList.removeAt(i);
      _corMaterialList.removeAt(i);
      _update();
    });
  }

  void _addExtra() => setState(() {
        _extraNomeCtrlList.add(TextEditingController());
        _extraValorCtrlList.add(TextEditingController());
      });

  void _removeExtra(int i) {
    setState(() {
      _extraNomeCtrlList[i].dispose();
      _extraValorCtrlList[i].dispose();
      _extraNomeCtrlList.removeAt(i);
      _extraValorCtrlList.removeAt(i);
      _update();
    });
  }

  void _resetAll() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Limpar calculadora'),
                content: const Text(
                    'Apaga os dados da peça atual. Valores fixos são mantidos.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          for (var c in [
                            _nomePecaCtrl,
                            _pesoCtrl,
                            _tempoHrsCtrl,
                            _tempoMaoDeObraCtrl,
                            _custoHardwareCtrl
                          ]) c.clear();
                          for (var c in [
                            ..._corNomeCtrlList,
                            ..._corPesoCtrlList,
                            ..._corCustoKgCtrlList,
                            ..._extraNomeCtrlList,
                            ..._extraValorCtrlList
                          ]) c.dispose();
                          _corNomeCtrlList.clear();
                          _corPesoCtrlList.clear();
                          _corCustoKgCtrlList.clear();
                          _corMaterialList.clear();
                          _extraNomeCtrlList.clear();
                          _extraValorCtrlList.clear();
                          _model.multiCor = false;
                          _carretelSelecionadoId = null;
                          _model.margemPersonalizada = 50;
                          _margemCtrl.text = '50';
                          _qtdLoteCtrl.text = '1';
                          _qtdLote = 1;
                          for (var p in _model.plataformas) {
                            p.ativa = false;
                          }
                          _carregarPreferencias();
                        });
                      },
                      child: const Text('Limpar')),
                ]));
  }

  void _carregarModel(CalculatorModel m) {
    setState(() {
      _nomePecaCtrl.text = m.nomePeca;
      _custoPorKgCtrl.text = _fmtP(m.custoPorKg);
      _pesoCtrl.text = m.pesoGramas > 0 ? _fmtP(m.pesoGramas) : '';
      _tempoHrsCtrl.text =
          m.tempoImpressaoHoras > 0 ? m.tempoImpressaoHoras.toString() : '';
      _tempoMaoDeObraCtrl.text =
          m.tempoMaoDeObraMinutos > 0 ? _fmtP(m.tempoMaoDeObraMinutos) : '';
      _valorHoraMaoDeObraCtrl.text = _fmtP(m.valorHoraMaoDeObra);
      _custoHardwareCtrl.text =
          m.custoHardware > 0 ? _fmtP(m.custoHardware) : '';
      _custoEmbalagemCtrl.text =
          m.custoEmbalagem > 0 ? _fmtP(m.custoEmbalagem) : '';
      _potenciaCtrl.text = _fmtP(m.potenciaImpressoraWatts);
      _tarifaEnergiaCtrl.text = _fmtP(m.tarifaEnergia);
      _taxaIVACtrl.text = _fmtP(m.taxaIVA);
      _depreciacaoCtrl.text =
          m.custoDepreciacao > 0 ? _fmtP(m.custoDepreciacao) : '';
      _model.materialSelecionado = m.materialSelecionado;
      _carretelSelecionadoId = null;
      _model.margemPersonalizada = m.margemPersonalizada;
      _margemCtrl.text = m.margemPersonalizada.toStringAsFixed(0);
      _model.multiCor = m.multiCor;
      _model.plataformas = m.plataformas;
      for (var c in [
        ..._corNomeCtrlList,
        ..._corPesoCtrlList,
        ..._corCustoKgCtrlList
      ]) c.dispose();
      _corNomeCtrlList.clear();
      _corPesoCtrlList.clear();
      _corCustoKgCtrlList.clear();
      _corMaterialList.clear();
      for (var cor in m.cores) {
        _corNomeCtrlList.add(TextEditingController(text: cor.nome));
        _corPesoCtrlList.add(TextEditingController(
            text: cor.pesoGramas > 0 ? _fmtP(cor.pesoGramas) : ''));
        _corCustoKgCtrlList
            .add(TextEditingController(text: _fmtP(cor.custoPorKg)));
        _corMaterialList.add(cor.material);
      }
      for (var c in [..._extraNomeCtrlList, ..._extraValorCtrlList])
        c.dispose();
      _extraNomeCtrlList.clear();
      _extraValorCtrlList.clear();
      for (var e in m.materiaisExtras) {
        _extraNomeCtrlList.add(TextEditingController(text: e.nome));
        _extraValorCtrlList.add(
            TextEditingController(text: e.custo > 0 ? _fmtP(e.custo) : ''));
      }
      _update();
    });
  }

  Future<void> _salvarHistorico() async {
    _update();
    if (_model.custoTotalSemMargem <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preencha ao menos um custo para salvar.')));
      return;
    }
    await HistoricoService.salvar(HistoricoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: DateTime.now(),
        model: CalculatorModel.fromJson(_model.toJson())));
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Cálculo salvo no histórico!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2)));
  }

  Future<void> _abrirNovaReceitaRapida() async {
    _update();
    if (_model.custoTotalSemMargem <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preencha os custos antes de criar uma receita.')));
      return;
    }

    final plat = _model.plataformas.firstWhere((p) => p.ativa,
        orElse: () => PlataformaConfig(nome: '', taxa: 0));
    final temPlat = plat.nome.isNotEmpty;
    final valorSugerido = temPlat
        ? _model.precoComPlataforma(
            _model.margemPersonalizada, plat.taxa, plat.taxaFixa)
        : _model.precoPersonalizadoComIVA;

    final item = HistoricoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: DateTime.now(),
      model: CalculatorModel.fromJson(_model.toJson()),
    );
    await HistoricoService.salvar(item);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovaTransacaoScreen(
          tipoInicial: TipoTransacao.receita,
          categoriaInicial: 'Venda de peça',
          idHistoricoInicial: item.id,
          quantidadeInicial: _qtdLote,
          valorInicial: valorSugerido,
          descricaoInicial:
              _model.nomePeca.isNotEmpty ? 'Venda: ${_model.nomePeca}' : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.view_in_ar_rounded, size: 22),
          SizedBox(width: 8),
          Text('Calculadora 3D',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Configurações',
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConfiguracoesScreen()));
                if (changed == true) _carregarPreferencias();
              }),
          IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Histórico',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          HistoricoScreen(onCarregarCalculo: _carregarModel)))),
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Limpar',
              onPressed: _resetAll),
        ],
        bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [Tab(text: 'Dados da peça'), Tab(text: 'Resultados')]),
      ),
      body: TabBarView(
          controller: _tabController,
          children: [_buildInputTab(), _buildResultsTab()]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _update();
            _tabController.animateTo(1);
          },
          backgroundColor: const Color(0xFF6C3CE1),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('Calcular')),
    );
  }

  // ══ ABA 1 ══════════════════════════════════════════════════════════════════

  Widget _buildInputTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        SectionCard(
            icon: Icons.info_outline_rounded,
            title: 'Detalhes do projeto',
            child: InputField(
                controller: _nomePecaCtrl,
                label: 'Nome da peça',
                hint: 'Ex: Chaveiro personalizado',
                keyboardType: TextInputType.text,
                onChanged: (_) => _update())),
        const SizedBox(height: 12),

        // Filamento
        SectionCard(
            icon: Icons.water_drop_outlined,
            title: 'Filamento',
            child: Column(children: [
              if (!_model.multiCor) ...[
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _carretelSelecionadoId,
                      decoration: InputDecoration(
                        labelText: 'Usar filamento do estoque (opcional)',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF6C3CE1), width: 1.8)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Não usar estoque'),
                        ),
                        ..._estoqueFilamentos
                            .map((e) => DropdownMenuItem<String?>(
                                  value: e.id,
                                  child: Text(
                                      '${e.material}${e.cor.isNotEmpty ? " ${e.cor}" : ""} · ${e.pesoRestanteG.toStringAsFixed(0)}g · R\$ ${(e.custoPorG * 1000).toStringAsFixed(2)}/kg'),
                                )),
                      ],
                      onChanged: _aplicarCarretelEstoque,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar estoque',
                    onPressed: _carregarEstoqueFilamentos,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF6C3CE1)),
                  ),
                ]),
                if (_estoqueFilamentos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nenhum carretel ativo no estoque.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
              _switchRow(
                  Icons.palette_outlined,
                  const Color(0xFF8B5CF6),
                  'Multi-cor / Multi-material',
                  'Ative para usar filamentos diferentes',
                  _model.multiCor, (v) {
                setState(() {
                  _model.multiCor = v;
                  if (v && _corNomeCtrlList.isEmpty) _addCor();
                });
              }),
              const SizedBox(height: 14),
              if (!_model.multiCor) ...[
                Row(children: [
                  Expanded(
                      child: _matDropdown(
                          _model.materialSelecionado,
                          (v) => setState(() {
                                _carretelSelecionadoId = null;
                                _model.materialSelecionado = v!;
                              }))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: InputField(
                          controller: _custoPorKgCtrl,
                          label: 'Custo / kg (R\$)',
                          hint: '110',
                          onChanged: (_) => _update())),
                ]),
                const SizedBox(height: 12),
                InputField(
                    controller: _pesoCtrl,
                    label: 'Peso da peça (g)',
                    hint: '0',
                    suffix: 'g',
                    onChanged: (_) => _update()),
              ] else ...[
                if (_corNomeCtrlList.isEmpty)
                  Center(
                      child: Text('Adicione ao menos uma cor',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13))),
                ...List.generate(
                    _corNomeCtrlList.length, (i) => _buildCorRow(i)),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        onPressed: _addCor,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Adicionar cor'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8B5CF6),
                            side: const BorderSide(color: Color(0xFF8B5CF6)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))))),
                if (_model.cores.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Peso total',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                                Text('${_model.pesoTotal.toStringAsFixed(1)}g',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF8B5CF6))),
                              ]))),
              ],
            ])),
        const SizedBox(height: 12),

        // Tempo
        SectionCard(
            icon: Icons.timer_outlined,
            title: 'Tempo',
            child: Column(children: [
              InputField(
                  controller: _tempoHrsCtrl,
                  label: 'Tempo de impressão (horas)',
                  hint: 'Ex: 3.8',
                  suffix: 'h',
                  onChanged: (_) => _update()),
              const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 12),
                  child: Text('Formato decimal: 1h30min = 1.5 · 2h45min = 2.75',
                      style: TextStyle(fontSize: 11, color: Colors.grey))),
              Row(children: [
                Expanded(
                    child: InputField(
                        controller: _tempoMaoDeObraCtrl,
                        label: 'Mão de obra (min)',
                        hint: '0',
                        suffix: 'min',
                        onChanged: (_) => _update())),
                const SizedBox(width: 12),
                Expanded(
                    child: InputField(
                        controller: _valorHoraMaoDeObraCtrl,
                        label: 'Valor hora (R\$)',
                        hint: '20',
                        onChanged: (_) => _update())),
              ]),
            ])),
        const SizedBox(height: 12),

        // Custos adicionais
        SectionCard(
            icon: Icons.inventory_2_outlined,
            title: 'Custos adicionais',
            child: Row(children: [
              Expanded(
                  child: InputField(
                      controller: _custoHardwareCtrl,
                      label: 'Hardware (R\$)',
                      hint: '0',
                      onChanged: (_) => _update())),
              const SizedBox(width: 12),
              Expanded(
                  child: InputField(
                      controller: _custoEmbalagemCtrl,
                      label: 'Embalagem (R\$)',
                      hint: '0',
                      onChanged: (_) => _update())),
            ])),
        const SizedBox(height: 12),

        // Plataformas
        SectionCard(
            icon: Icons.storefront_outlined,
            title: 'Plataforma de venda',
            iconColor: const Color(0xFFEF4444),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ative a plataforma onde pretende vender.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              ...List.generate(_model.plataformas.length, (i) {
                final p = _model.plataformas[i];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                        decoration: BoxDecoration(
                            color: p.ativa
                                ? const Color(0xFFEF4444).withOpacity(0.06)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: p.ativa
                                    ? const Color(0xFFEF4444).withOpacity(0.25)
                                    : Colors.grey.shade200)),
                        child: SwitchListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                            title: Text(p.nome,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                p.taxaFixa > 0
                                    ? 'Taxa: ${p.taxa.toStringAsFixed(1)}% + R\$ ${p.taxaFixa.toStringAsFixed(2)} por peça'
                                    : 'Taxa: ${p.taxa.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            value: p.ativa,
                            activeColor: const Color(0xFFEF4444),
                            onChanged: (v) => setState(() {
                                  for (var pl in _model.plataformas)
                                    pl.ativa = false;
                                  p.ativa = v;
                                  _update();
                                }))));
              }),
              if (_model.plataformas.every((p) => !p.ativa))
                const Text('Nenhuma plataforma ativa — preço sem taxa',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
        const SizedBox(height: 12),

        // Materiais extras
        SectionCard(
            icon: Icons.add_shopping_cart_rounded,
            title: 'Materiais extras',
            iconColor: const Color(0xFF10B981),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ex: argola de chaveiro, parafuso, imã...',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              if (_extraNomeCtrlList.isEmpty)
                Center(
                    child: Text('Nenhum material extra adicionado',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400))),
              ...List.generate(
                  _extraNomeCtrlList.length,
                  (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Expanded(
                            flex: 5,
                            child: _miniTF(_extraNomeCtrlList[i],
                                'Nome (ex: argola)', TextInputType.text,
                                borderColor: const Color(0xFF10B981))),
                        const SizedBox(width: 8),
                        Expanded(
                            flex: 3,
                            child: _miniTF(_extraValorCtrlList[i], '0,00', null,
                                suffix: 'R\$',
                                borderColor: const Color(0xFF10B981))),
                        const SizedBox(width: 4),
                        IconButton(
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: Colors.red,
                                size: 22),
                            onPressed: () => _removeExtra(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints()),
                      ]))),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: _addExtra,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Adicionar material extra'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))))),
            ])),
        const SizedBox(height: 12),

        // Energia
        SectionCard(
            icon: Icons.bolt_rounded,
            title: 'Energia elétrica',
            iconColor: const Color(0xFFF59E0B),
            child: Row(children: [
              Expanded(
                  child: InputField(
                      controller: _potenciaCtrl,
                      label: 'Potência impressora',
                      hint: '200',
                      suffix: 'W',
                      onChanged: (_) => _update())),
              const SizedBox(width: 12),
              Expanded(
                  child: InputField(
                      controller: _tarifaEnergiaCtrl,
                      label: 'Tarifa (R\$/kWh)',
                      hint: '0.75',
                      onChanged: (_) => _update())),
            ])),
      ]),
    );
  }

  Widget _buildCorRow(int i) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Cor ${i + 1}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF8B5CF6))),
          const Spacer(),
          IconButton(
              icon:
                  const Icon(Icons.close_rounded, size: 18, color: Colors.red),
              onPressed: () => _removeCor(i),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 8),
        _miniTF(
            _corNomeCtrlList[i], 'Nome da cor (ex: Azul)', TextInputType.text,
            borderColor: const Color(0xFF8B5CF6)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _matDropdown(
                  i < _corMaterialList.length ? _corMaterialList[i] : 'PLA',
                  (v) => setState(() {
                        if (i < _corMaterialList.length)
                          _corMaterialList[i] = v!;
                      }),
                  accent: const Color(0xFF8B5CF6))),
          const SizedBox(width: 8),
          Expanded(
              child: _miniTF(_corPesoCtrlList[i], 'Peso (g)', null,
                  suffix: 'g', borderColor: const Color(0xFF8B5CF6))),
          const SizedBox(width: 8),
          Expanded(
              child: _miniTF(_corCustoKgCtrlList[i], 'R\$/kg', null,
                  borderColor: const Color(0xFF8B5CF6))),
        ]),
      ]));

  // ══ ABA 2 ══════════════════════════════════════════════════════════════════

  Widget _buildResultsTab() {
    final plat = _model.plataformas.firstWhere((p) => p.ativa,
        orElse: () => PlataformaConfig(nome: '', taxa: 0));
    final temPlat = plat.nome.isNotEmpty;

    double precoPlat(double m) => temPlat
        ? _model.precoComPlataforma(m, plat.taxa, plat.taxaFixa)
        : _model.precoComMargemEIVA(m);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(children: [
        // Banner
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C3CE1), Color(0xFF9B6DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF6C3CE1).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Custo Total',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_fmt(_model.custoTotalSemMargem),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              if (_model.nomePeca.isNotEmpty)
                Text('📦 ${_model.nomePeca}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                  _model.multiCor
                      ? '🎨 Multi-cor · ${_model.pesoTotal.toStringAsFixed(1)}g'
                      : '🧵 ${_model.materialSelecionado} · ${_model.pesoGramas.toStringAsFixed(0)}g${_model.tempoImpressaoHoras > 0 ? ' · ${_model.tempoImpressaoHoras.toStringAsFixed(1)}h' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (temPlat)
                Text(
                    '🏪 ${plat.nome} (${plat.taxa.toStringAsFixed(1)}%${plat.taxaFixa > 0 ? ' + R\$ ${plat.taxaFixa.toStringAsFixed(2)}/peça' : ''})',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
        const SizedBox(height: 12),

        // Salvar
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                onPressed: _salvarHistorico,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('Salvar no histórico'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C3CE1),
                    side: const BorderSide(color: Color(0xFF6C3CE1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: _abrirNovaReceitaRapida,
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: const Text('Nova receita com este cálculo'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
        const SizedBox(height: 14),

        // Preços sugeridos
        SectionCard(
            icon: Icons.sell_outlined,
            title: temPlat
                ? 'Preços sugeridos + ${plat.nome}'
                : 'Preços sugeridos',
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: PriceCard(
                        label: 'Competitivo',
                        margem: '25%',
                        preco: precoPlat(25),
                        precoComIVA: precoPlat(25),
                        color: const Color(0xFF10B981),
                        taxaIVA: temPlat ? 0 : _model.taxaIVA)),
                const SizedBox(width: 10),
                Expanded(
                    child: PriceCard(
                        label: 'Padrão',
                        margem: '40%',
                        preco: precoPlat(40),
                        precoComIVA: precoPlat(40),
                        color: const Color(0xFF3B82F6),
                        taxaIVA: temPlat ? 0 : _model.taxaIVA)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: PriceCard(
                        label: 'Premium',
                        margem: '60%',
                        preco: precoPlat(60),
                        precoComIVA: precoPlat(60),
                        color: const Color(0xFFF59E0B),
                        taxaIVA: temPlat ? 0 : _model.taxaIVA)),
                const SizedBox(width: 10),
                Expanded(
                    child: PriceCard(
                        label: 'Luxo',
                        margem: '80%',
                        preco: precoPlat(80),
                        precoComIVA: precoPlat(80),
                        color: const Color(0xFF8B5CF6),
                        taxaIVA: temPlat ? 0 : _model.taxaIVA)),
              ]),
              const SizedBox(height: 14), const Divider(),
              const SizedBox(height: 10),
              // Margem personalizada
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Margem personalizada',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(
                    width: 80,
                    child: TextField(
                        controller: _margemCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6C3CE1)),
                        decoration: InputDecoration(
                            suffixText: '%',
                            suffixStyle: const TextStyle(
                                color: Color(0xFF6C3CE1),
                                fontWeight: FontWeight.w600),
                            filled: true,
                            fillColor: const Color(0xFFF3EEFF),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: const Color(0xFF6C3CE1)
                                        .withOpacity(0.3))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: const Color(0xFF6C3CE1)
                                        .withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF6C3CE1), width: 1.8))),
                        onChanged: (v) {
                          final p = double.tryParse(v);
                          if (p != null && p >= 1 && p <= 99)
                            setState(() {
                              _model.margemPersonalizada = p;
                              _margemCtrl.text = v;
                            });
                        })),
              ]),
              Slider(
                  value: _model.margemPersonalizada.clamp(1.0, 95.0),
                  min: 1,
                  max: 95,
                  divisions: 94,
                  activeColor: const Color(0xFF6C3CE1),
                  onChanged: (v) {
                    setState(() {
                      _model.margemPersonalizada = v;
                      _margemCtrl.text = v.toStringAsFixed(0);
                    });
                  }),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3EEFF),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_fmt(precoPlat(_model.margemPersonalizada)),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6C3CE1))),
                              Text(temPlat ? 'Com ${plat.nome}' : 'Sem imposto',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ]),
                        if (!temPlat && _model.taxaIVA > 0)
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_fmt(_model.precoPersonalizadoComIVA),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6C3CE1))),
                                Text(
                                    'Com ${_model.taxaIVA.toStringAsFixed(0)}% imposto',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ]),
                      ])),
            ])),
        const SizedBox(height: 12),

        // Lote
        SectionCard(
            icon: Icons.layers_rounded,
            title: 'Produção em lote',
            iconColor: const Color(0xFF0EA5E9),
            child: Column(children: [
              const Text('Simule o custo e lucro para múltiplas unidades.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 14),
              Row(children: [
                const Text('Quantidade:',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                _qtyBtn(Icons.remove_rounded, () {
                  if (_qtdLote > 1)
                    setState(() {
                      _qtdLote--;
                      _qtdLoteCtrl.text = _qtdLote.toString();
                    });
                }),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                        width: 72,
                        child: TextField(
                            controller: _qtdLoteCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0EA5E9)),
                            decoration: InputDecoration(
                                filled: true,
                                fillColor:
                                    const Color(0xFF0EA5E9).withOpacity(0.07),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: const Color(0xFF0EA5E9)
                                            .withOpacity(0.3))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: const Color(0xFF0EA5E9)
                                            .withOpacity(0.3))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 1.8))),
                            onChanged: (v) {
                              final p = int.tryParse(v);
                              if (p != null && p >= 1)
                                setState(() => _qtdLote = p);
                            }))),
                _qtyBtn(
                    Icons.add_rounded,
                    () => setState(() {
                          _qtdLote++;
                          _qtdLoteCtrl.text = _qtdLote.toString();
                        })),
              ]),
              const SizedBox(height: 4),
              Slider(
                  value: _qtdLote.toDouble(),
                  min: 1,
                  max: 500,
                  divisions: 499,
                  activeColor: const Color(0xFF0EA5E9),
                  onChanged: (v) => setState(() {
                        _qtdLote = v.toInt();
                        _qtdLoteCtrl.text = _qtdLote.toString();
                      })),
              const SizedBox(height: 8),
              _buildLoteGrid(plat, temPlat),
            ])),
        const SizedBox(height: 12),

        SectionCard(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Discriminação de custos',
            child: CostBreakdown(model: _model)),
      ]),
    );
  }

  Widget _buildLoteGrid(PlataformaConfig plat, bool temPlat) {
    final margem = _model.margemPersonalizada;
    final precoUnit = temPlat
        ? _model.precoComPlataforma(margem, plat.taxa, plat.taxaFixa)
        : _model.precoPersonalizadoComIVA;
    final custo = _model.custoLote(_qtdLote);
    final receita = precoUnit * _qtdLote;
    final lucro = receita - custo;
    final pesoLote = _model.pesoTotal * _qtdLote;

    return Column(children: [
      Row(children: [
        Expanded(
            child: _loteCard(
                'Material total',
                _fmt(_model.materialLote(_qtdLote)),
                '${pesoLote.toStringAsFixed(0)}g',
                const Color(0xFF3B82F6))),
        const SizedBox(width: 10),
        Expanded(
            child: _loteCard('Custo total', _fmt(custo), '$_qtdLote peças',
                const Color(0xFFEF4444))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _loteCard(
                'Receita total',
                _fmt(receita),
                'Margem ${margem.toStringAsFixed(0)}%',
                const Color(0xFF10B981))),
        const SizedBox(width: 10),
        Expanded(
            child: _loteCard('Lucro total', _fmt(lucro), 'Depois dos custos',
                lucro >= 0 ? const Color(0xFF8B5CF6) : Colors.red)),
      ]),
      if (_qtdLote > 1) ...[
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF0EA5E9).withOpacity(0.2))),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lucro por unidade',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text(_fmt(lucro / _qtdLote),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0EA5E9))),
                ])),
      ],
    ]);
  }

  Widget _loteCard(String label, String valor, String sub, Color color) =>
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valor,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E))),
            Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]));

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF0EA5E9), size: 20)));

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _switchRow(IconData icon, Color iconColor, String label,
          String subtitle, bool value, ValueChanged<bool> onChanged) =>
      Container(
          decoration: BoxDecoration(
              color: value ? iconColor.withOpacity(0.06) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: value
                      ? iconColor.withOpacity(0.25)
                      : Colors.grey.shade200)),
          child: SwitchListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              secondary: Icon(icon, color: iconColor, size: 20),
              title: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              value: value,
              activeColor: iconColor,
              onChanged: onChanged));

  Widget _matDropdown(String value, ValueChanged<String?> onChanged,
          {Color? accent}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Material',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555577))),
        const SizedBox(height: 6),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    items: materiais
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: onChanged))),
      ]);

  Widget _miniTF(
          TextEditingController ctrl, String hint, TextInputType? keyboard,
          {String? suffix, Color borderColor = const Color(0xFF6C3CE1)}) =>
      TextField(
          controller: ctrl,
          keyboardType:
              keyboard ?? const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: keyboard == TextInputType.text
              ? null
              : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          onChanged: (_) => _update(),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              suffixText: suffix,
              suffixStyle: TextStyle(
                  color: borderColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              filled: true,
              fillColor: Colors.white,
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
                  borderSide: BorderSide(color: borderColor, width: 1.8))));

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}
