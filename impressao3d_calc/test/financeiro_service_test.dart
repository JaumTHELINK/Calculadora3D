import 'package:flutter_test/flutter_test.dart';
import 'package:impressao3d_calc/models/calculator_model.dart';
import 'package:impressao3d_calc/services/financeiro_service.dart';

void main() {
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
}
