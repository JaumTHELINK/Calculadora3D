import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:impressao3d_calc/models/calculator_model.dart';
import 'package:impressao3d_calc/models/financeiro_model.dart';
import 'package:impressao3d_calc/models/pedido_model.dart';
import 'package:impressao3d_calc/services/financeiro_service.dart';
import 'package:impressao3d_calc/services/historico_service.dart';
import 'package:impressao3d_calc/services/pedidos_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('gera receita do pedido com itens repetidos e baixa estoque', () async {
    final historico1 = HistoricoItem(
      id: 'h1',
      data: DateTime.now(),
      model: CalculatorModel()
        ..nomePeca = 'Suporte'
        ..multiCor = false
        ..materialSelecionado = 'PLA'
        ..pesoGramas = 20,
    );
    final historico2 = HistoricoItem(
      id: 'h2',
      data: DateTime.now(),
      model: CalculatorModel()
        ..nomePeca = 'Base'
        ..multiCor = false
        ..materialSelecionado = 'PETG'
        ..pesoGramas = 30,
    );

    await HistoricoService.salvar(historico1);
    await HistoricoService.salvar(historico2);

    await FinanceiroService.salvarCarretel(EstoqueFilamento(
      id: 'pla',
      dataCompra: DateTime(2026, 4, 1),
      marca: 'Marca A',
      material: 'PLA',
      cor: 'Branco',
      pesoCompradoG: 200,
      custoTotal: 20,
    ));
    await FinanceiroService.salvarCarretel(EstoqueFilamento(
      id: 'petg',
      dataCompra: DateTime(2026, 4, 2),
      marca: 'Marca B',
      material: 'PETG',
      cor: 'Transparente',
      pesoCompradoG: 200,
      custoTotal: 30,
    ));

    final pedido = PedidoItem(
      id: 'p1',
      data: DateTime.now(),
      nomeCliente: 'Cliente A',
      itens: [
        PedidoLinhaItem(
          id: 'i1',
          idHistorico: historico1.id,
          nomeItemSalvo: 'Suporte',
          quantidade: 2,
        ),
        PedidoLinhaItem(
          id: 'i2',
          idHistorico: historico2.id,
          nomeItemSalvo: 'Base',
          quantidade: 1,
        ),
        PedidoLinhaItem(
          id: 'i3',
          idHistorico: historico1.id,
          nomeItemSalvo: 'Suporte',
          quantidade: 1,
        ),
      ],
      valorCobrado: 120,
      valorPago: 120,
      observacoes: 'Pedido teste',
    );

    final erro = await PedidosService.gerarOuAtualizarReceita(pedido);
    expect(erro, isNull);

    final transacoes = await FinanceiroService.carregarTransacoes();
    expect(transacoes, hasLength(1));
    expect(transacoes.first.idPedido, 'p1');
    expect(transacoes.first.itensVenda, hasLength(3));

    final estoque = await FinanceiroService.carregarEstoque();
    expect(estoque.firstWhere((e) => e.id == 'pla').pesoUsadoG, closeTo(60.0, 0.0001));
    expect(estoque.firstWhere((e) => e.id == 'petg').pesoUsadoG, closeTo(30.0, 0.0001));

    final pedidos = await PedidosService.carregar();
    expect(pedidos, hasLength(1));
    expect(pedidos.first.idTransacaoReceita, isNotEmpty);
    expect(pedidos.first.pagoTotal, isTrue);
    expect(pedidos.first.valorRestante, closeTo(0.0, 0.0001));
  });
}
