import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/financeiro_model.dart';
import '../models/pedido_model.dart';
import 'financeiro_service.dart';

class PedidosService {
  static const _key = 'pedidos_clientes';

  static Future<List<PedidoItem>> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => PedidoItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvar(PedidoItem item) async {
    final lista = await carregar();
    final idx = lista.indexWhere((x) => x.id == item.id);
    if (idx >= 0) {
      lista[idx] = item;
    } else {
      lista.insert(0, item);
    }
    await _persistir(lista);
  }

  static Future<void> remover(String id) async {
    final lista = await carregar();
    PedidoItem? pedido;
    try {
      pedido = lista.firstWhere((e) => e.id == id);
    } catch (_) {
      pedido = null;
    }
    if (pedido != null && pedido.idTransacaoReceita != null) {
      await FinanceiroService.removerTransacao(pedido.idTransacaoReceita!);
    }
    lista.removeWhere((e) => e.id == id);
    await _persistir(lista);
  }

  static Future<String?> gerarOuAtualizarReceita(PedidoItem pedido) async {
    final itensValidos = pedido.itens
        .where((item) => item.idHistorico != null && item.idHistorico!.isNotEmpty && item.quantidade > 0)
        .toList();
    if (itensValidos.isEmpty) {
      return 'Pedido sem itens válidos para gerar receita';
    }

    final valorReceita =
        pedido.pagoTotal || pedido.valorPago <= 0 ? pedido.valorCobrado : pedido.valorPago;
    if (valorReceita <= 0) {
      return 'Informe um valor cobrado válido';
    }

    final transacaoId = pedido.idTransacaoReceita ?? 'receita_${pedido.id}';
    final transacoes = await FinanceiroService.carregarTransacoes();
    Transacao? transacaoAnterior;
    try {
      transacaoAnterior = transacoes.firstWhere((t) => t.id == transacaoId);
    } catch (_) {
      transacaoAnterior = null;
    }

    final transacao = Transacao(
      id: transacaoId,
      data: DateTime.now(),
      tipo: TipoTransacao.receita,
      categoria: 'Venda de peça',
      valor: valorReceita,
      descricao: _descricaoReceitaPedido(pedido),
      idPedido: pedido.id,
      itensVenda: itensValidos
          .map((item) => VendaPedidoItem(
                idHistorico: item.idHistorico!,
                nomeHistorico: item.nomeItemSalvo,
                quantidade: item.quantidade,
              ))
          .toList(),
        quantidadePecas:
          itensValidos.map((item) => item.quantidade).fold<int>(0, (s, q) => s + q),
      nomeHistorico:
          itensValidos.isNotEmpty ? itensValidos.first.nomeItemSalvo : null,
      idHistorico: itensValidos.isNotEmpty ? itensValidos.first.idHistorico : null,
    );

    final erro = await FinanceiroService.salvarTransacaoComRegraDeEstoque(
      transacao: transacao,
      transacaoAnterior: transacaoAnterior,
      historico: null,
      quantidade: null,
      itensVenda: transacao.itensVenda,
    );
    if (erro != null) {
      return erro;
    }

    final pedidoAtualizado = PedidoItem(
      id: pedido.id,
      data: pedido.data,
      nomeCliente: pedido.nomeCliente,
      itens: pedido.itens,
      valorCobrado: pedido.valorCobrado,
      valorPago: pedido.valorPago,
      observacoes: pedido.observacoes,
      idTransacaoReceita: transacaoId,
    );
    await salvar(pedidoAtualizado);
    return null;
  }

  static String _descricaoReceitaPedido(PedidoItem pedido) {
    final itens = pedido.itens
        .where((item) => item.nomeItemSalvo.trim().isNotEmpty)
        .map((item) => '${item.nomeItemSalvo} x${item.quantidade}')
        .toList();
    final base = itens.isEmpty ? 'Pedido de ${pedido.nomeCliente}' : itens.join(' · ');
    final restante = pedido.valorRestante;
    if (restante <= 0) return base;
    return '$base · falta R\$ ${restante.toStringAsFixed(2)}';
  }

  static Future<void> _persistir(List<PedidoItem> itens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(itens.map((e) => e.toJson()).toList()));
  }
}
