const List<String> materiais = [
  'PLA',
  'PETG',
  'ABS',
  'TPU',
  'ASA',
  'Nylon',
  'Resina',
  'HIPS',
  'PVA',
];

class PlataformaConfig {
  String nome;
  double taxa;
  double taxaFixa;
  bool ativa;

  PlataformaConfig(
      {required this.nome,
      required this.taxa,
      this.taxaFixa = 0.0,
      this.ativa = false});

  Map<String, dynamic> toJson() =>
      {'nome': nome, 'taxa': taxa, 'taxaFixa': taxaFixa, 'ativa': ativa};
  factory PlataformaConfig.fromJson(Map<String, dynamic> j) => PlataformaConfig(
      nome: j['nome'] ?? '',
      taxa: (j['taxa'] ?? 0.0).toDouble(),
      taxaFixa: (j['taxaFixa'] ?? 0.0).toDouble(),
      ativa: j['ativa'] ?? false);
}

List<PlataformaConfig> plataformasPadrao() => [
      PlataformaConfig(nome: 'Shopee', taxa: 20.0, taxaFixa: 4.0),
      PlataformaConfig(nome: 'Mercado Livre', taxa: 17.0),
      PlataformaConfig(nome: 'TikTok Shop', taxa: 9.0),
      PlataformaConfig(nome: 'Revendedor', taxa: 30.0),
    ];

class MaterialExtra {
  String nome;
  double custo;
  String? idEstoqueMaterialExtra;
  int quantidadeUnidades;
  MaterialExtra(
      {this.nome = '',
      this.custo = 0.0,
      this.idEstoqueMaterialExtra,
      this.quantidadeUnidades = 1});
  Map<String, dynamic> toJson() => {
        'nome': nome,
        'custo': custo,
        'idEstoqueMaterialExtra': idEstoqueMaterialExtra,
        'quantidadeUnidades': quantidadeUnidades,
      };
  factory MaterialExtra.fromJson(Map<String, dynamic> j) => MaterialExtra(
      nome: j['nome'] ?? '',
      custo: (j['custo'] ?? 0.0).toDouble(),
      idEstoqueMaterialExtra: j['idEstoqueMaterialExtra'],
      quantidadeUnidades: ((j['quantidadeUnidades'] ?? 1) as num).toInt());
}

class CorFilamento {
  String nome, material;
  double pesoGramas, custoPorKg;
  CorFilamento(
      {this.nome = '',
      this.material = 'PLA',
      this.pesoGramas = 0.0,
      this.custoPorKg = 110.0});
  double get custo => (pesoGramas / 1000.0) * custoPorKg;
  Map<String, dynamic> toJson() => {
        'nome': nome,
        'material': material,
        'pesoGramas': pesoGramas,
        'custoPorKg': custoPorKg
      };
  factory CorFilamento.fromJson(Map<String, dynamic> j) => CorFilamento(
      nome: j['nome'] ?? '',
      material: j['material'] ?? 'PLA',
      pesoGramas: (j['pesoGramas'] ?? 0.0).toDouble(),
      custoPorKg: (j['custoPorKg'] ?? 110.0).toDouble());
}

class CalculatorModel {
  String nomePeca = '';
  String materialSelecionado = 'PLA';
  double custoPorKg = 110.0, pesoGramas = 0.0;
  bool multiCor = false;
  List<CorFilamento> cores = [];
  double tempoImpressaoHoras = 0.0,
      tempoMaoDeObraMinutos = 0.0,
      valorHoraMaoDeObra = 20.0;
  double custoHardware = 0.0, custoEmbalagem = 0.0;
  List<MaterialExtra> materiaisExtras = [];
  double potenciaImpressoraWatts = 200.0, tarifaEnergia = 0.75;
  double custoDepreciacao = 0.0, taxaIVA = 0.0, margemPersonalizada = 50.0;
  List<PlataformaConfig> plataformas = plataformasPadrao();

  CalculatorModel();

  double get custoMaterial {
    if (multiCor) return cores.fold(0.0, (s, c) => s + c.custo);
    if (custoPorKg <= 0 || pesoGramas <= 0) return 0.0;
    return (pesoGramas / 1000.0) * custoPorKg;
  }

  double get pesoTotal =>
      multiCor ? cores.fold(0.0, (s, c) => s + c.pesoGramas) : pesoGramas;
  double get custoEnergia =>
      (potenciaImpressoraWatts <= 0 || tempoImpressaoHoras <= 0)
          ? 0.0
          : (potenciaImpressoraWatts / 1000.0) *
              tempoImpressaoHoras *
              tarifaEnergia;
  double get custoMaoDeObra =>
      (tempoMaoDeObraMinutos <= 0 || valorHoraMaoDeObra <= 0)
          ? 0.0
          : (tempoMaoDeObraMinutos / 60.0) * valorHoraMaoDeObra;
  double get custoMaquina => custoDepreciacao;
  double get custoMateriaisExtras =>
      materiaisExtras.fold(0.0, (s, m) => s + m.custo);
  double get custoTotalSemMargem =>
      custoMaterial +
      custoHardware +
      custoEmbalagem +
      custoMaoDeObra +
      custoMaquina +
      custoEnergia +
      custoMateriaisExtras;

  double precoComMargem(double margem) => custoTotalSemMargem <= 0
      ? 0.0
      : custoTotalSemMargem / (1 - margem / 100.0);
  double precoComMargemEIVA(double margem) =>
      precoComMargem(margem) * (1 + taxaIVA / 100.0);
  double precoComPlataforma(double margem, double taxaPlataforma,
      [double taxaFixa = 0.0]) {
    final base = precoComMargemEIVA(margem);
    if (taxaPlataforma <= 0 && taxaFixa <= 0) return base;
    return (base + taxaFixa) / (1 - taxaPlataforma / 100.0);
  }

  double get precoCompetitivo => precoComMargem(25);
  double get precoCompetitivoComIVA => precoComMargemEIVA(25);
  double get precoPadrao => precoComMargem(40);
  double get precoPadraoComIVA => precoComMargemEIVA(40);
  double get precoPremium => precoComMargem(60);
  double get precoPremiumComIVA => precoComMargemEIVA(60);
  double get precoLuxo => precoComMargem(80);
  double get precoLuxoComIVA => precoComMargemEIVA(80);
  double get precoPersonalizado => precoComMargem(margemPersonalizada);
  double get precoPersonalizadoComIVA =>
      precoComMargemEIVA(margemPersonalizada);

  double custoLote(int qtd) => custoTotalSemMargem * qtd;
  double materialLote(int qtd) => custoMaterial * qtd;
  double receitaLote(int qtd, double margem) =>
      precoComMargemEIVA(margem) * qtd;

  Map<String, dynamic> toJson() => {
        'nomePeca': nomePeca,
        'materialSelecionado': materialSelecionado,
        'custoPorKg': custoPorKg,
        'pesoGramas': pesoGramas,
        'multiCor': multiCor,
        'cores': cores.map((c) => c.toJson()).toList(),
        'tempoImpressaoHoras': tempoImpressaoHoras,
        'tempoMaoDeObraMinutos': tempoMaoDeObraMinutos,
        'valorHoraMaoDeObra': valorHoraMaoDeObra,
        'custoHardware': custoHardware,
        'custoEmbalagem': custoEmbalagem,
        'potenciaImpressoraWatts': potenciaImpressoraWatts,
        'tarifaEnergia': tarifaEnergia,
        'custoDepreciacao': custoDepreciacao,
        'taxaIVA': taxaIVA,
        'margemPersonalizada': margemPersonalizada,
        'materiaisExtras': materiaisExtras.map((e) => e.toJson()).toList(),
        'plataformas': plataformas.map((p) => p.toJson()).toList(),
      };

  factory CalculatorModel.fromJson(Map<String, dynamic> j) {
    final m = CalculatorModel();
    m.nomePeca = j['nomePeca'] ?? '';
    m.materialSelecionado = j['materialSelecionado'] ?? 'PLA';
    m.custoPorKg = (j['custoPorKg'] ?? 110.0).toDouble();
    m.pesoGramas = (j['pesoGramas'] ?? 0.0).toDouble();
    m.multiCor = j['multiCor'] ?? false;
    m.cores = (j['cores'] as List<dynamic>? ?? [])
        .map((c) => CorFilamento.fromJson(c as Map<String, dynamic>))
        .toList();
    m.tempoImpressaoHoras = (j['tempoImpressaoHoras'] ?? 0.0).toDouble();
    m.tempoMaoDeObraMinutos = (j['tempoMaoDeObraMinutos'] ?? 0.0).toDouble();
    m.valorHoraMaoDeObra = (j['valorHoraMaoDeObra'] ?? 20.0).toDouble();
    m.custoHardware = (j['custoHardware'] ?? 0.0).toDouble();
    m.custoEmbalagem = (j['custoEmbalagem'] ?? 0.0).toDouble();
    m.potenciaImpressoraWatts =
        (j['potenciaImpressoraWatts'] ?? 200.0).toDouble();
    m.tarifaEnergia = (j['tarifaEnergia'] ?? 0.75).toDouble();
    m.custoDepreciacao = (j['custoDepreciacao'] ?? 0.0).toDouble();
    m.taxaIVA = (j['taxaIVA'] ?? 0.0).toDouble();
    m.margemPersonalizada = (j['margemPersonalizada'] ?? 50.0).toDouble();
    m.materiaisExtras = (j['materiaisExtras'] as List<dynamic>? ?? [])
        .map((e) => MaterialExtra.fromJson(e as Map<String, dynamic>))
        .toList();
    final plats = j['plataformas'] as List<dynamic>?;
    if (plats != null && plats.isNotEmpty)
      m.plataformas = plats
          .map((p) => PlataformaConfig.fromJson(p as Map<String, dynamic>))
          .toList();
    return m;
  }
}

class HistoricoItem {
  final String id;
  final DateTime data;
  final CalculatorModel model;
  HistoricoItem({required this.id, required this.data, required this.model});
  Map<String, dynamic> toJson() =>
      {'id': id, 'data': data.toIso8601String(), 'model': model.toJson()};
  factory HistoricoItem.fromJson(Map<String, dynamic> j) => HistoricoItem(
      id: j['id'] ?? '',
      data: DateTime.tryParse(j['data'] ?? '') ?? DateTime.now(),
      model:
          CalculatorModel.fromJson(j['model'] as Map<String, dynamic>? ?? {}));
}
