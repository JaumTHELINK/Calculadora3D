import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/calculator_model.dart';
import '../models/pedido_model.dart';
import '../services/historico_service.dart';
import '../services/pedidos_service.dart';

class _LinhaPedidoForm {
  final String id;
  String? idHistorico;
  final TextEditingController quantidadeCtrl;

  _LinhaPedidoForm({
    required this.id,
    this.idHistorico,
    required int quantidade,
  }) : quantidadeCtrl = TextEditingController(text: '$quantidade');

  void dispose() => quantidadeCtrl.dispose();
}

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => PedidosScreenState();
}

class PedidosScreenState extends State<PedidosScreen> {
  List<PedidoItem> _pedidos = [];
  List<HistoricoItem> _historico = [];
  bool _loading = true;

  Future<void> recarregarDados() => _carregar();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final dados = await Future.wait([
      PedidosService.carregar(),
      HistoricoService.carregar(),
    ]);
    if (!mounted) return;
    setState(() {
      _pedidos = dados[0] as List<PedidoItem>;
      _historico = dados[1] as List<HistoricoItem>;
      _loading = false;
    });
  }

  Future<void> _abrirFormulario([PedidoItem? edicao]) async {
    final nomeCtrl = TextEditingController(text: edicao?.nomeCliente ?? '');
    final valorCobradoCtrl = TextEditingController(
        text: edicao != null && edicao.valorCobrado > 0
            ? edicao.valorCobrado.toStringAsFixed(2)
            : '');
    final valorPagoCtrl = TextEditingController(
        text: edicao != null && edicao.valorPago > 0
            ? edicao.valorPago.toStringAsFixed(2)
            : '');
    final observacoesCtrl = TextEditingController(text: edicao?.observacoes ?? '');

    final linhas = <_LinhaPedidoForm>[];
    if (edicao != null && edicao.itens.isNotEmpty) {
      for (final item in edicao.itens) {
        linhas.add(_LinhaPedidoForm(
          id: item.id,
          idHistorico: item.idHistorico,
          quantidade: item.quantidade,
        ));
      }
    } else {
      linhas.add(_LinhaPedidoForm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        quantidade: 1,
      ));
    }

    bool pagoTotal = edicao?.pagoTotal ?? false;

    final salvo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final historicoIds = _historico.map((h) => h.id).toSet();

          String resumoItens() {
            if (linhas.isEmpty) return 'Nenhum item';
            final partes = <String>[];
            for (final linha in linhas) {
              final historico = _historico.firstWhere(
                (h) => h.id == linha.idHistorico,
                orElse: () => HistoricoItem(
                  id: '',
                  data: DateTime.now(),
                  model: CalculatorModel(),
                ),
              );
              if (historico.id.isNotEmpty) {
                final nome = historico.model.nomePeca.isNotEmpty
                    ? historico.model.nomePeca
                    : 'Sem nome';
                partes.add('$nome x${int.tryParse(linha.quantidadeCtrl.text) ?? 0}');
              }
            }
            return partes.isEmpty ? 'Nenhum item selecionado' : partes.join(' · ');
          }

          double valorCobrado() =>
              double.tryParse(valorCobradoCtrl.text.replaceAll(',', '.')) ?? 0;

          double valorPago() {
            if (pagoTotal) return valorCobrado();
            return double.tryParse(valorPagoCtrl.text.replaceAll(',', '.')) ?? 0;
          }

          double valorFaltante() {
            final falta = valorCobrado() - valorPago();
            return falta > 0 ? falta : 0;
          }

          void atualizarPagamentoCompleto() {
            if (pagoTotal) {
              valorPagoCtrl.text = valorCobradoCtrl.text;
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(edicao == null ? 'Novo pedido' : 'Editar pedido',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  _field(nomeCtrl, 'Nome do cliente', TextInputType.text),
                  const SizedBox(height: 10),
                  const Text('Itens do pedido',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555577))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...List.generate(linhas.length, (index) {
                          final linha = linhas[index];
                          final valorSelecionado = historicoIds.contains(linha.idHistorico)
                              ? linha.idHistorico
                              : null;
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: index == linhas.length - 1 ? 0 : 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String?>(
                                    value: valorSelecionado,
                                    hint: const Text('Projeto salvo'),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
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
                                    items: _historico
                                        .map((h) => DropdownMenuItem<String?>(
                                              value: h.id,
                                              child: Text(
                                                h.model.nomePeca.isNotEmpty
                                                    ? h.model.nomePeca
                                                    : 'Sem nome',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      setModalState(() {
                                        linha.idHistorico = v;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: linha.quantidadeCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Qtd',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide:
                                              BorderSide(color: Colors.grey.shade300)),
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                                if (linhas.length > 1) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => setModalState(() {
                                      final removida = linhas.removeAt(index);
                                      removida.dispose();
                                    }),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    color: Colors.red.shade400,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => setModalState(() {
                            linhas.add(_LinhaPedidoForm(
                              id: DateTime.now().microsecondsSinceEpoch.toString(),
                              quantidade: 1,
                            ));
                          }),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Adicionar item'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          resumoItens(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _field(
                              valorCobradoCtrl,
                              'Valor total cobrado',
                              const TextInputType.numberWithOptions(decimal: true),
                              suffix: 'R\$')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                            valorPagoCtrl,
                            'Valor pago',
                            const TextInputType.numberWithOptions(decimal: true),
                            suffix: 'R\$'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cliente pagou tudo'),
                    value: pagoTotal,
                    onChanged: (v) => setModalState(() {
                      pagoTotal = v;
                      atualizarPagamentoCompleto();
                    }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Falta pagar: R\$ ${valorFaltante().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C3CE1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _field(
                    observacoesCtrl,
                    'Observações',
                    TextInputType.text,
                    suffix: '',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final nome = nomeCtrl.text.trim();
                        final valor = double.tryParse(valorCobradoCtrl.text.replaceAll(',', '.')) ?? 0;
                        final pago = pagoTotal
                            ? valor
                            : double.tryParse(valorPagoCtrl.text.replaceAll(',', '.')) ?? 0;
                        final itens = <PedidoLinhaItem>[];
                        for (final linha in linhas) {
                          final quantidade = int.tryParse(linha.quantidadeCtrl.text) ?? 0;
                          if (linha.idHistorico == null || linha.idHistorico!.isEmpty) continue;
                          if (quantidade <= 0) continue;
                          final historico = _historico.firstWhere(
                            (h) => h.id == linha.idHistorico,
                            orElse: () => HistoricoItem(
                              id: '',
                              data: DateTime.now(),
                              model: CalculatorModel(),
                            ),
                          );
                          if (historico.id.isEmpty) continue;
                          itens.add(PedidoLinhaItem(
                            id: linha.id,
                            idHistorico: historico.id,
                            nomeItemSalvo: historico.model.nomePeca.isNotEmpty
                                ? historico.model.nomePeca
                                : 'Sem nome',
                            quantidade: quantidade,
                          ));
                        }
                        if (nome.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Informe o nome do cliente')));
                          return;
                        }
                        if (itens.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Adicione ao menos um item válido')));
                          return;
                        }
                        if (valor <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Informe quanto voce cobrou')));
                          return;
                        }
                        if (pago < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Informe um valor pago válido')));
                          return;
                        }

                        final pedido = PedidoItem(
                          id: edicao?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          data: edicao?.data ?? DateTime.now(),
                          nomeCliente: nome,
                          itens: itens,
                          valorCobrado: valor,
                          valorPago: pago,
                          observacoes: observacoesCtrl.text.trim(),
                          idTransacaoReceita: edicao?.idTransacaoReceita,
                        );
                        await PedidosService.salvar(pedido);
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C3CE1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Salvar pedido'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    nomeCtrl.dispose();
    valorCobradoCtrl.dispose();
    valorPagoCtrl.dispose();
    observacoesCtrl.dispose();
    for (final linha in linhas) {
      linha.dispose();
    }

    if (salvo == true) {
      await _carregar();
    }
  }

  Future<void> _remover(PedidoItem p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover pedido'),
        content: Text('Deseja remover o pedido de ${p.nomeCliente}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (ok == true) {
      await PedidosService.remover(p.id);
      await _carregar();
    }
  }

  Future<void> _gerarOuAtualizarReceita(PedidoItem pedido) async {
    final erro = await PedidosService.gerarOuAtualizarReceita(pedido);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erro ?? 'Receita do pedido gerada com sucesso',
        ),
        backgroundColor: erro == null ? const Color(0xFF059669) : Colors.red,
      ),
    );
    if (erro == null) {
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _pedidos.fold(0.0, (s, p) => s + p.valorCobrado);
    final restante = _pedidos.fold(0.0, (s, p) => s + p.valorRestante);
    
    final pedidosEmAberto = _pedidos.where((p) => !p.pagoTotal).toList();
    final pedidosPagos = _pedidos.where((p) => p.pagoTotal).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.assignment_rounded, size: 22),
            SizedBox(width: 8),
            Text('Pedidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _pedidos.isEmpty
                  ? _vazio()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF6C3CE1),
                                Color(0xFF9B6DFF)
                              ]),
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _stat('Pedidos', '${_pedidos.length}'),
                              _stat('Total cobrado',
                                  'R\$ ${total.toStringAsFixed(2)}'),
                              _stat('A receber', 'R\$ ${restante.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (pedidosEmAberto.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Pedidos em aberto',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...pedidosEmAberto.map(_cardPedido),
                          const SizedBox(height: 16),
                        ],
                        if (pedidosPagos.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Pedidos pagos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...pedidosPagos.map(_cardPedido),
                        ],
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo pedido'),
      ),
    );
  }

  Widget _vazio() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
              child: Text('Sem pedidos anotados',
                  style: TextStyle(color: Colors.grey))),
        ],
      );

  Widget _cardPedido(PedidoItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFF6C3CE1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.person_rounded, color: Color(0xFF6C3CE1)),
        ),
        title: Text(p.nomeCliente,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                p.itens.isNotEmpty
                    ? p.itens
                        .map((i) => '${i.nomeItemSalvo} x${i.quantidade}')
                        .join(' · ')
                    : 'Item sem nome',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
                'Qtd: ${p.quantidade} · Cobrado: R\$ ${p.valorCobrado.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
            Text(
              p.pagoTotal
                  ? 'Pago total'
                  : 'Falta R\$ ${p.valorRestante.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: p.pagoTotal ? const Color(0xFF059669) : const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _gerarOuAtualizarReceita(p),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: const Color(0xFF6C3CE1),
                  ),
                  icon: Icon(
                    p.receitaGerada ? Icons.refresh_rounded : Icons.receipt_long,
                    size: 18,
                  ),
                  label: Text(
                    p.receitaGerada ? 'Atualizar receita' : 'Gerar receita',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'editar') await _abrirFormulario(p);
            if (v == 'remover') await _remover(p);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar',
              child: Text('Editar'),
            ),
            const PopupMenuItem(
              value: 'remover',
              child: Text('Remover'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String l, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );

  Widget _field(
      TextEditingController ctrl, String label, TextInputType? keyboard,
      {String? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555577))),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType:
            keyboard ?? const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: keyboard == TextInputType.text
            ? null
            : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(
                color: Color(0xFF6C3CE1), fontWeight: FontWeight.w600),
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
                borderSide:
                    const BorderSide(color: Color(0xFF6C3CE1), width: 1.8))),
      ),
    ]);
  }
}
