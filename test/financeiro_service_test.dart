import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impressao3d_calc/models/calculator_model.dart';
import 'package:impressao3d_calc/models/financeiro_model.dart';
import 'package:impressao3d_calc/services/financeiro_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FinanceiroService.calcularNecessidadePorMaterial', () {
    test('retorna vazio quando quantidade invalida', () {
      final historico = HistoricoItem(
        id: 'h1',
        data: DateTime.now(),
        model: CalculatorModel()
          ..multiCor = false
          ..materialSelecionado = 'PLA'
          ..pesoGramas = 50,
      );

      final necessidade =
          FinanceiroService.calcularNecessidadePorMaterial(historico, 0);
      expect(necessidade, isEmpty);
    });

    test('calcula necessidade para projeto monocor', () {
      final historico = HistoricoItem(
        id: 'h2',
        data: DateTime.now(),
        model: CalculatorModel()
          ..multiCor = false
          ..materialSelecionado = 'PETG'
          ..pesoGramas = 80,
      );

      final necessidade =
          FinanceiroService.calcularNecessidadePorMaterial(historico, 3);
      expect(necessidade.length, 1);
      expect(necessidade['PETG'], closeTo(240.0, 0.0001));
    });

    test('agrupa materiais no projeto multicor', () {
      final model = CalculatorModel()
        ..multiCor = true
        ..cores = [
          CorFilamento(
              nome: 'A', material: 'PLA', pesoGramas: 30, custoPorKg: 100),
          CorFilamento(
              nome: 'B', material: 'PLA', pesoGramas: 20, custoPorKg: 100),
          CorFilamento(
              nome: 'C', material: 'PETG', pesoGramas: 10, custoPorKg: 120),
        ];

      final historico =
          HistoricoItem(id: 'h3', data: DateTime.now(), model: model);
      final necessidade =
          FinanceiroService.calcularNecessidadePorMaterial(historico, 2);

      expect(necessidade.length, 2);
      expect(necessidade['PLA'], closeTo(100.0, 0.0001));
      expect(necessidade['PETG'], closeTo(20.0, 0.0001));
    });
  });

  group('FinanceiroService.salvarOuAtualizarVendaDePeca', () {
    test('baixa estoque de filamentos em venda multicor', () async {
      final historico = HistoricoItem(
        id: 'h-multi',
        data: DateTime.now(),
        model: CalculatorModel()
          ..multiCor = true
          ..cores = [
            CorFilamento(
                nome: 'Parte A',
                material: 'PLA',
                pesoGramas: 30,
                custoPorKg: 100),
            CorFilamento(
                nome: 'Parte B',
                material: 'PLA',
                pesoGramas: 20,
                custoPorKg: 100),
            CorFilamento(
                nome: 'Parte C',
                material: 'PETG',
                pesoGramas: 10,
                custoPorKg: 120),
          ],
      );

      await FinanceiroService.salvarCarretel(EstoqueFilamento(
        id: 'e1',
        dataCompra: DateTime(2026, 4, 1),
        marca: 'Marca A',
        material: 'PLA',
        cor: 'Branco',
        pesoCompradoG: 200,
        custoTotal: 20,
      ));
      await FinanceiroService.salvarCarretel(EstoqueFilamento(
        id: 'e2',
        dataCompra: DateTime(2026, 4, 2),
        marca: 'Marca B',
        material: 'PETG',
        cor: 'Transparente',
        pesoCompradoG: 100,
        custoTotal: 15,
      ));

      final transacao = Transacao(
        id: 't-multi',
        data: DateTime.now(),
        tipo: TipoTransacao.receita,
        categoria: 'Venda de peça',
        valor: 150,
        descricao: 'Venda teste multi',
        idHistorico: historico.id,
        nomeHistorico: historico.model.nomePeca,
        quantidadePecas: 2,
        pesoFilamentoConsumidoG: 80,
      );

      final erro = await FinanceiroService.salvarOuAtualizarVendaDePeca(
        transacao: transacao,
        historico: historico,
        quantidade: 2,
      );

      expect(erro, isNull);

      final estoque = await FinanceiroService.carregarEstoque();
      final pla = estoque.firstWhere((e) => e.id == 'e1');
      final petg = estoque.firstWhere((e) => e.id == 'e2');
      expect(pla.pesoUsadoG, closeTo(100.0, 0.0001));
      expect(petg.pesoUsadoG, closeTo(20.0, 0.0001));

      final usos = await FinanceiroService.carregarUsos();
      expect(usos.where((u) => u.idTransacao == 't-multi').length, 2);
    });
  });
}
