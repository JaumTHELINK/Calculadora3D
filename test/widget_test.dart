import 'package:flutter_test/flutter_test.dart';
import 'package:impressao3d_calc/models/financeiro_model.dart';

void main() {
  test('serializa e desserializa transacao com campos de venda', () {
    final transacao = Transacao(
      id: 't1',
      data: DateTime(2026, 4, 3),
      tipo: TipoTransacao.receita,
      categoria: 'Venda de peça',
      valor: 99.9,
      descricao: 'Venda Etsy',
      idHistorico: 'h1',
      nomeHistorico: 'Suporte Camera',
      quantidadePecas: 4,
      pesoFilamentoConsumidoG: 180.5,
    );

    final map = transacao.toJson();
    final restaurada = Transacao.fromJson(map);

    expect(restaurada.id, 't1');
    expect(restaurada.tipo, TipoTransacao.receita);
    expect(restaurada.categoria, 'Venda de peça');
    expect(restaurada.quantidadePecas, 4);
    expect(restaurada.pesoFilamentoConsumidoG, closeTo(180.5, 0.0001));
    expect(restaurada.idHistorico, 'h1');
  });
}
