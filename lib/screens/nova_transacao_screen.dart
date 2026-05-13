import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/financeiro_model.dart';
import '../models/calculator_model.dart';
import '../services/financeiro_service.dart';
import '../services/historico_service.dart';
import '../widgets/section_card.dart';

class NovaTransacaoScreen extends StatefulWidget {
  final TipoTransacao tipoInicial;
  final Transacao? edicao;
  final String? categoriaInicial;
  final double? valorInicial;
  final int? quantidadeInicial;
  final String? idHistoricoInicial;
  final String? descricaoInicial;
  const NovaTransacaoScreen(
      {super.key,
      required this.tipoInicial,
      this.edicao,
      this.categoriaInicial,
      this.valorInicial,
      this.quantidadeInicial,
      this.idHistoricoInicial,
      this.descricaoInicial});
  @override
  State<NovaTransacaoScreen> createState() => _NovaTransacaoScreenState();
}

class _NovaTransacaoScreenState extends State<NovaTransacaoScreen> {
  late TipoTransacao _tipo;
  String? _categoriaSelecionada;
  final _valorCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _quantidadeCtrl = TextEditingController(text: '1');
  DateTime _data = DateTime.now();
  HistoricoItem? _historicoVinculado;
  List<HistoricoItem> _historico = [];
  List<EstoqueFilamento> _estoque = [];
  List<EstoqueMaterialExtra> _estoqueMateriaisExtras = [];

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    if (widget.edicao != null) {
      final e = widget.edicao!;
      _tipo = e.tipo;
      _categoriaSelecionada = e.categoria;
      _valorCtrl.text = e.valor.toStringAsFixed(2);
      _descricaoCtrl.text = e.descricao;
      _data = e.data;
      if (e.quantidadePecas != null && e.quantidadePecas! > 0) {
        _quantidadeCtrl.text = e.quantidadePecas.toString();
      }
    } else {
      if (widget.categoriaInicial != null) {
        _categoriaSelecionada = widget.categoriaInicial;
      }
      if (widget.valorInicial != null && widget.valorInicial! > 0) {
        _valorCtrl.text = widget.valorInicial!.toStringAsFixed(2);
      }
      if (widget.quantidadeInicial != null && widget.quantidadeInicial! > 0) {
        _quantidadeCtrl.text = widget.quantidadeInicial.toString();
      }
      if (widget.descricaoInicial != null &&
          widget.descricaoInicial!.trim().isNotEmpty) {
        _descricaoCtrl.text = widget.descricaoInicial!.trim();
      }
    }
    HistoricoService.carregar().then((h) => setState(() {
          _historico = h;
          final idInicial =
              widget.edicao?.idHistorico ?? widget.idHistoricoInicial;
          if (idInicial != null) {
            try {
              _historicoVinculado =
                  _historico.firstWhere((x) => x.id == idInicial);
            } catch (_) {}
          }
        }));
    FinanceiroService.carregarEstoque().then((e) {
      if (!mounted) return;
      setState(() => _estoque = e);
    });
    FinanceiroService.carregarEstoqueMateriaisExtras().then((e) {
      if (!mounted) return;
      setState(() => _estoqueMateriaisExtras = e);
    });
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descricaoCtrl.dispose();
    _quantidadeCtrl.dispose();
    super.dispose();
  }

  List<CategoriaFinanceira> get _categorias =>
      _tipo == TipoTransacao.receita ? categoriasReceita : categoriasDespesa;

  bool get _isVendaDePeca =>
      _tipo == TipoTransacao.receita &&
      _categoriaSelecionada == 'Venda de peça';

  int get _quantidadeAtual => int.tryParse(_quantidadeCtrl.text) ?? 0;

  Map<String, double> get _necessidadeAtual {
    if (!_isVendaDePeca ||
        _historicoVinculado == null ||
        _quantidadeAtual <= 0) {
      return const {};
    }
    return FinanceiroService.calcularNecessidadePorMaterial(
      _historicoVinculado!,
      _quantidadeAtual,
    );
  }

  Map<String, int> get _necessidadeMateriaisExtrasAtual {
    if (!_isVendaDePeca ||
        _historicoVinculado == null ||
        _quantidadeAtual <= 0) {
      return const {};
    }
    return FinanceiroService.calcularNecessidadeMateriaisExtras(
      _historicoVinculado!,
      _quantidadeAtual,
    );
  }

  double _disponivelMaterial(String material) {
    return _estoque
        .where((e) => e.material == material && !e.esgotado)
        .fold(0.0, (s, e) => s + e.pesoRestanteG);
  }

  int _disponivelMaterialExtra(String id) {
    final idx = _estoqueMateriaisExtras.indexWhere((e) => e.id == id);
    if (idx < 0) return 0;
    return _estoqueMateriaisExtras[idx].quantidadeRestante;
  }

  String _nomeMaterialExtra(String id) {
    final idx = _estoqueMateriaisExtras.indexWhere((e) => e.id == id);
    if (idx < 0) return 'Material extra';
    return _estoqueMateriaisExtras[idx].nome;
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      _snack('Informe um valor válido');
      return;
    }
    if (_categoriaSelecionada == null) {
      _snack('Selecione uma categoria');
      return;
    }

    final vendaDePeca = _isVendaDePeca;
    final quantidade = int.tryParse(_quantidadeCtrl.text) ?? 0;
    if (vendaDePeca) {
      if (_historicoVinculado == null) {
        _snack('Selecione um projeto salvo');
        return;
      }
      if (quantidade <= 0) {
        _snack('Informe uma quantidade válida');
        return;
      }
    }

    final t = Transacao(
      id: widget.edicao?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      data: _data,
      tipo: _tipo,
      categoria: _categoriaSelecionada!,
      valor: valor,
      descricao: _descricaoCtrl.text.trim(),
      idHistorico: widget.edicao?.itensVenda.isNotEmpty == true
        ? widget.edicao!.idHistorico
        : _historicoVinculado?.id,
      nomeHistorico: widget.edicao?.itensVenda.isNotEmpty == true
        ? widget.edicao!.nomeHistorico
        : _historicoVinculado?.model.nomePeca,
      quantidadePecas: widget.edicao?.itensVenda.isNotEmpty == true
        ? widget.edicao!.quantidadePecas
        : (vendaDePeca ? quantidade : null),
      pesoFilamentoConsumidoG: widget.edicao?.itensVenda.isNotEmpty == true
        ? widget.edicao!.pesoFilamentoConsumidoG
        : (vendaDePeca && _historicoVinculado != null
          ? _historicoVinculado!.model.pesoTotal * quantidade
          : null),
      itensVenda: widget.edicao?.itensVenda.isNotEmpty == true
        ? widget.edicao!.itensVenda
        : vendaDePeca
          ? [
              VendaPedidoItem(
                idHistorico: _historicoVinculado?.id ?? '',
                nomeHistorico:
                    _historicoVinculado?.model.nomePeca.isNotEmpty == true
                        ? _historicoVinculado!.model.nomePeca
                        : 'Sem nome',
                quantidade: quantidade,
              )
            ]
          : const [],
    );

    final erro = await FinanceiroService.salvarTransacaoComRegraDeEstoque(
      transacao: t,
      transacaoAnterior: widget.edicao,
      historico: vendaDePeca ? _historicoVinculado : null,
      quantidade: vendaDePeca ? quantidade : null,
    );
    if (erro != null) {
      _snack(erro);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _escolherData() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _data,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (picked != null) setState(() => _data = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isReceita = _tipo == TipoTransacao.receita;
    final cor = isReceita ? const Color(0xFF059669) : const Color(0xFFEF4444);
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        title: Text(
            widget.edicao != null
                ? 'Editar lançamento'
                : isReceita
                    ? '+ Nova receita'
                    : '− Nova despesa',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
              onPressed: _salvar,
              child: const Text('Salvar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (widget.edicao == null) ...[
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                _tipoBtn(
                    'Receita', TipoTransacao.receita, const Color(0xFF059669)),
                _tipoBtn(
                    'Despesa', TipoTransacao.despesa, const Color(0xFFEF4444)),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          SectionCard(
              icon: Icons.attach_money_rounded,
              title: 'Valor',
              iconColor: cor,
              child: TextField(
                  controller: _valorCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*'))
                  ],
                  autofocus: true,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: cor),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      hintText: '0,00',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade300, fontSize: 28),
                      prefixText: 'R\$ ',
                      prefixStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cor),
                      border: InputBorder.none))),
          const SizedBox(height: 12),
          SectionCard(
              icon: Icons.category_outlined,
              title: 'Categoria',
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categorias.map((cat) {
                    final sel = _categoriaSelecionada == cat.nome;
                    return GestureDetector(
                        onTap: () =>
                            setState(() => _categoriaSelecionada = cat.nome),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: sel
                                    ? cor.withOpacity(0.12)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel
                                        ? cor.withOpacity(0.5)
                                        : Colors.transparent)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(cat.emoji,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(cat.nome,
                                  style: TextStyle(
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: sel ? cor : Colors.black87,
                                      fontSize: 13)),
                            ])));
                  }).toList())),
          const SizedBox(height: 12),
          SectionCard(
              icon: Icons.notes_rounded,
              title: 'Detalhes',
              child: Column(children: [
                TextField(
                    controller: _descricaoCtrl,
                    keyboardType: TextInputType.text,
                    maxLines: 2,
                    decoration: InputDecoration(
                        hintText: 'Descrição (opcional)',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
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
                            borderSide: BorderSide(color: cor, width: 1.8)))),
                const SizedBox(height: 12),
                InkWell(
                    onTap: _escolherData,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: Row(children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 18, color: cor),
                          const SizedBox(width: 10),
                          Text(_fmtData(_data),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const Spacer(),
                          const Icon(Icons.edit_rounded,
                              size: 16, color: Colors.grey),
                        ]))),
              ])),
          if (_isVendaDePeca) ...[
            const SizedBox(height: 12),
            SectionCard(
                icon: Icons.link_rounded,
                title: 'Projeto salvo e produção',
                iconColor: const Color(0xFF6C3CE1),
                child: _historico.isEmpty
                    ? const Text('Nenhum cálculo salvo no histórico.',
                        style: TextStyle(color: Colors.grey))
                    : Column(children: [
                        TextField(
                          controller: _quantidadeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: 'Quantidade produzida',
                            hintText: 'Ex: 10',
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
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_historicoVinculado != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Consumo estimado: ${_necessidadeAtual.values.fold(0.0, (s, v) => s + v).toStringAsFixed(1)}g de filamento',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6C3CE1),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estoque disponível por material',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                if (_necessidadeAtual.isEmpty &&
                                    _necessidadeMateriaisExtrasAtual.isEmpty)
                                  const Text(
                                      'Informe quantidade e selecione um projeto',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey))
                                else ...[
                                  ..._necessidadeAtual.entries.map((entry) {
                                    final disponivel =
                                        _disponivelMaterial(entry.key);
                                    final ok =
                                        disponivel + 0.0001 >= entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${entry.key}: precisa ${entry.value.toStringAsFixed(1)}g',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Text(
                                            'tem ${disponivel.toStringAsFixed(1)}g',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: ok
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (_necessidadeMateriaisExtrasAtual
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    const Text('Materiais extras (unidades)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF334155))),
                                    const SizedBox(height: 4),
                                    ..._necessidadeMateriaisExtrasAtual.entries
                                        .map((entry) {
                                      final disponivel =
                                          _disponivelMaterialExtra(entry.key);
                                      final ok = disponivel >= entry.value;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${_nomeMaterialExtra(entry.key)}: precisa ${entry.value} un',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                            Text(
                                              'tem $disponivel un',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: ok
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (_historicoVinculado != null)
                          Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF6C3CE1).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF6C3CE1)
                                          .withOpacity(0.3))),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF6C3CE1), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        _historicoVinculado!
                                                .model.nomePeca.isNotEmpty
                                            ? _historicoVinculado!
                                                .model.nomePeca
                                            : 'Sem nome',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 16, color: Colors.grey),
                                    onPressed: () => setState(
                                        () => _historicoVinculado = null),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints()),
                              ])),
                        SizedBox(
                            height: 200,
                            child: ListView.builder(
                                itemCount: _historico.length,
                                itemBuilder: (ctx, i) {
                                  final h = _historico[i];
                                  final sel = _historicoVinculado?.id == h.id;
                                  return ListTile(
                                      dense: true,
                                      selected: sel,
                                      selectedTileColor: const Color(0xFF6C3CE1)
                                          .withOpacity(0.07),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      leading: Text(h.model.materialSelecionado,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      title: Text(
                                          h.model.nomePeca.isNotEmpty
                                              ? h.model.nomePeca
                                              : 'Sem nome',
                                          style: const TextStyle(fontSize: 13)),
                                      subtitle: Text(_fmtData(h.data),
                                          style: const TextStyle(fontSize: 11)),
                                      trailing: Text(
                                          'R\$ ${h.model.precoPadrao.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF6C3CE1))),
                                      onTap: () => setState(
                                          () => _historicoVinculado = h));
                                })),
                      ])),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _tipoBtn(String label, TipoTransacao tipo, Color cor) {
    final sel = _tipo == tipo;
    return Expanded(
        child: GestureDetector(
            onTap: () => setState(() {
                  _tipo = tipo;
                  _categoriaSelecionada = null;
                }),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: sel ? cor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : Colors.grey)))));
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
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }
}
