import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/financeiro_model.dart';
import '../models/pedido_model.dart';
import 'financeiro_service.dart';

/// Serviço responsável por CRUD e operações relacionadas a pedidos de clientes.
///
/// - Persiste pedidos em `SharedPreferences` sob a chave `_key`.
/// - Integra-se com `FinanceiroService` para registrar/remover transações
///   associadas a pagamentos de pedidos.
class PedidosService {
  static const _key = 'pedidos_clientes';

  /// Carrega todos os pedidos salvos do armazenamento local.
  /// Retorna lista vazia em caso de dados faltantes ou parse inválido.
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

  /// Salva ou atualiza um `PedidoItem` na lista persistida.
  /// Mantém ordenação por data (mais recente primeiro).
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

  /// Remove um pedido pelo `id`.
  /// Se o pedido possuir `idTransacaoReceita`, remove também a transação
  /// relacionada via `FinanceiroService` para manter consistência financeira.
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

  /// Registra o pagamento (total ou parcial) de um pedido.
  ///
  /// - Valida itens do pedido e limites do valor informado.
  /// - Cria ou atualiza uma transação do tipo `receita` em
  ///   `FinanceiroService` usando `salvarTransacaoComRegraDeEstoque`.
  /// - Atualiza o `PedidoItem` com `valorPago` e `idTransacaoReceita`.
  ///
  /// Retorna `null` em caso de sucesso ou uma string de erro descrevendo o
  /// problema (mensagem amigável para exibir ao usuário).
  static Future<String?> registrarPagamentoPedido({
    required PedidoItem pedido,
    required double valorPago,
    required bool pagoTotal,
  }) async {
    final itensValidos = pedido.itens
        .where((item) =>
            item.idHistorico != null &&
            item.idHistorico!.isNotEmpty &&
            item.quantidade > 0)
        .toList();
    if (itensValidos.isEmpty) {
      return 'Pedido sem itens válidos para registrar pagamento';
    }

    final valorFinal = pagoTotal ? pedido.valorCobrado : valorPago;
    if (valorFinal <= 0) {
      return 'Informe um valor pago válido';
    }
    if (!pagoTotal && valorFinal > pedido.valorCobrado) {
      return 'O valor pago não pode ser maior que o valor cobrado';
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
      valor: valorFinal,
      descricao: _descricaoReceitaPedido(
        pedido,
        pagoTotal: pagoTotal,
        valorPago: valorFinal,
      ),
      idPedido: pedido.id,
      itensVenda: itensValidos
          .map((item) => VendaPedidoItem(
                idHistorico: item.idHistorico!,
                nomeHistorico: item.nomeItemSalvo,
                quantidade: item.quantidade,
              ))
          .toList(),
      quantidadePecas: itensValidos
          .map((item) => item.quantidade)
          .fold<int>(0, (s, q) => s + q),
      nomeHistorico:
          itensValidos.isNotEmpty ? itensValidos.first.nomeItemSalvo : null,
      idHistorico:
          itensValidos.isNotEmpty ? itensValidos.first.idHistorico : null,
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
      valorPago: valorFinal,
      observacoes: pedido.observacoes,
      idTransacaoReceita: transacaoId,
    );
    await salvar(pedidoAtualizado);
    return null;
  }

  /// Gera ou atualiza a receita associada a um pedido, decidindo o valor a
  /// ser registrado com base no estado do pedido (`pagoTotal` ou `valorPago`).
  /// Encapsula `registrarPagamentoPedido` para conveniência.
  static Future<String?> gerarOuAtualizarReceita(PedidoItem pedido) async {
    return registrarPagamentoPedido(
      pedido: pedido,
      valorPago: pedido.pagoTotal || pedido.valorPago <= 0
          ? pedido.valorCobrado
          : pedido.valorPago,
      pagoTotal: pedido.pagoTotal,
    );
  }

  /// Constroi a descrição textual usada na transação de receita do pedido.
  /// Inclui itens, marca se foi pago totalmente ou parcial e valores.
  static String _descricaoReceitaPedido(PedidoItem pedido,
      {required bool pagoTotal, required double valorPago}) {
    final itens = pedido.itens
        .where((item) => item.nomeItemSalvo.trim().isNotEmpty)
        .map((item) => '${item.nomeItemSalvo} x${item.quantidade}')
        .toList();
    final base =
        itens.isEmpty ? 'Pedido de ${pedido.nomeCliente}' : itens.join(' · ');
    final restante = pedido.valorRestante;
    if (pagoTotal || restante <= 0) return '$base · pago total';
    return '$base · pago R\$ ${valorPago.toStringAsFixed(2)} · falta R\$ ${restante.toStringAsFixed(2)}';
  }

  /// Persiste a lista de pedidos em `SharedPreferences`.
  /// Serializa para JSON antes de salvar.
  static Future<void> _persistir(List<PedidoItem> itens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(itens.map((e) => e.toJson()).toList()));
  }
}
