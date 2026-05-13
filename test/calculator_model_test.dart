import 'package:flutter_test/flutter_test.dart';
import 'package:impressao3d_calc/models/calculator_model.dart';

void main() {
  group('CalculatorModel', () {
    test('calcula custo de material em modo monocor', () {
      final model = CalculatorModel()
        ..multiCor = false
        ..custoPorKg = 120
        ..pesoGramas = 250;

      expect(model.custoMaterial, closeTo(30.0, 0.0001));
      expect(model.pesoTotal, closeTo(250.0, 0.0001));
    });

    test('calcula custo e peso total em modo multicor', () {
      final model = CalculatorModel()
        ..multiCor = true
        ..cores = [
          CorFilamento(
              nome: 'Azul', material: 'PLA', pesoGramas: 100, custoPorKg: 100),
          CorFilamento(
              nome: 'Vermelho',
              material: 'PLA',
              pesoGramas: 50,
              custoPorKg: 140),
        ];

      expect(model.custoMaterial, closeTo(17.0, 0.0001));
      expect(model.pesoTotal, closeTo(150.0, 0.0001));
    });

    test('calcula energia, mao de obra e custo total', () {
      final model = CalculatorModel()
        ..multiCor = false
        ..custoPorKg = 100
        ..pesoGramas = 200
        ..potenciaImpressoraWatts = 300
        ..tempoImpressaoHoras = 4
        ..tarifaEnergia = 0.8
        ..tempoMaoDeObraMinutos = 30
        ..valorHoraMaoDeObra = 24
        ..custoHardware = 5
        ..custoEmbalagem = 3
        ..custoDepreciacao = 2
        ..materiaisExtras = [MaterialExtra(nome: 'Imã', custo: 1.5)];

      expect(model.custoMaterial, closeTo(20.0, 0.0001));
      expect(model.custoEnergia, closeTo(0.96, 0.0001));
      expect(model.custoMaoDeObra, closeTo(12.0, 0.0001));
      expect(model.custoTotalSemMargem, closeTo(44.46, 0.0001));
    });

    test('calcula preco com margem e IVA', () {
      final model = CalculatorModel()
        ..multiCor = false
        ..custoPorKg = 100
        ..pesoGramas = 100
        ..taxaIVA = 10;

      expect(model.custoTotalSemMargem, closeTo(10.0, 0.0001));
      expect(model.precoComMargem(50), closeTo(20.0, 0.0001));
      expect(model.precoComMargemEIVA(50), closeTo(22.0, 0.0001));
    });
  });
}
