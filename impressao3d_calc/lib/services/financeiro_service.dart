import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calculator_model.dart';
import '../models/financeiro_model.dart';
import '../services/historico_service.dart';

class FinanceiroService {
  static const _keyTransacoes = 'financeiro_transacoes';
  static const _keyEstoque = 'financeiro_estoque';
  static const _keyUsos = 'financeiro_usos';
  static const _keyEstoqueMateriaisExtras = 'financeiro_estoque_materiais';
  static const _keyUsosMateriaisExtras = 'financeiro_usos_materiais';

  static Future<List<Transacao>> carregarTransacoes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTransacoes);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Transacao.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarTransacao(Transacao t) async {
    final lista = await carregarTransacoes();
    lista.insert(0, t);
    await _persistirTransacoes(lista);
  }

  static bool _isVendaDePeca(Transacao t) =>
      t.tipo == TipoTransacao.receita && t.categoria == 'Venda de peça';

  static List<VendaPedidoItem> _itensDaVenda(Transacao transacao,
      {HistoricoItem? historico, int? quantidade, List<VendaPedidoItem>? itensVenda}) {
    if (itensVenda != null && itensVenda.isNotEmpty) {
      return itensVenda
          .where((item) => item.idHistorico.trim().isNotEmpty && item.quantidade > 0)
          .toList();
    }

    if (transacao.itensVenda.isNotEmpty) {
      return transacao.itensVenda
          .where((item) => item.idHistorico.trim().isNotEmpty && item.quantidade > 0)
          .toList();
    }

    if (historico != null && quantidade != null && quantidade > 0) {
      return [VendaPedidoItem(
        idHistorico: historico.id,
        nomeHistorico:
            historico.model.nomePeca.isNotEmpty ? historico.model.nomePeca : 'Sem nome',
        quantidade: quantidade,
      )];
    }

    if (transacao.idHistorico != null &&
        transacao.idHistorico!.isNotEmpty &&
        (transacao.quantidadePecas ?? 0) > 0) {
      return [VendaPedidoItem(
        idHistorico: transacao.idHistorico!,
        nomeHistorico:
            transacao.nomeHistorico?.isNotEmpty == true ? transacao.nomeHistorico! : 'Sem nome',
        quantidade: transacao.quantidadePecas!,
      )];
    }

    return const [];
  }

  static Map<String, double> calcularNecessidadePorMaterial(
          HistoricoItem historico, int quantidade) =>
      _calcularNecessidadePorMaterial(historico, quantidade);

  static Map<String, int> calcularNecessidadeMateriaisExtras(
          HistoricoItem historico, int quantidade) =>
      _calcularNecessidadeMateriaisExtras(historico, quantidade);

  static Future<String?> salvarOuAtualizarVendaDePeca({
    required Transacao transacao,
    HistoricoItem? historico,
    int? quantidade,
    List<VendaPedidoItem>? itensVenda,
    Transacao? transacaoAnterior,
  }) async {
    final itens = _itensDaVenda(transacao,
        historico: historico, quantidade: quantidade, itensVenda: itensVenda);
    if (itens.isEmpty) return 'Dados da venda de peça inválidos';

    final transacoes = await carregarTransacoes();
    final estoque = await carregarEstoque();
    final usos = await carregarUsos();
    final estoqueMateriaisExtras = await carregarEstoqueMateriaisExtras();
    final usosMateriaisExtras = await carregarUsosMateriaisExtras();
    final estoqueOrdenado = [...estoque]
      ..sort((a, b) => a.dataCompra.compareTo(b.dataCompra));
    final historicos = await HistoricoService.carregar();
    final historicosPorId = <String, HistoricoItem>{
      if (historico != null) historico.id: historico,
      for (final itemHistorico in historicos) itemHistorico.id: itemHistorico,
    };
    final descricaoVenda = itens
        .map((item) => item.nomeHistorico.isNotEmpty ? item.nomeHistorico : 'Sem nome')
        .join(', ');
    final resumoVenda = transacao.descricao.isNotEmpty
        ? transacao.descricao
        : 'Venda de peça: $descricaoVenda';

    final idAnterior = transacaoAnterior?.id;
    final usosAnterioresDaTransacao = idAnterior == null
        ? <UsoFilamento>[]
        : usos.where((u) => u.idTransacao == idAnterior).toList();
    final usosMateriaisAnterioresDaTransacao = idAnterior == null
        ? <UsoMaterialExtra>[]
        : usosMateriaisExtras
            .where((u) => u.idTransacao == idAnterior)
            .toList();

    for (final uso in usosAnterioresDaTransacao) {
      final idx = estoqueOrdenado.indexWhere((e) => e.id == uso.idEstoque);
      if (idx >= 0) {
        estoqueOrdenado[idx].pesoUsadoG =
            (estoqueOrdenado[idx].pesoUsadoG - uso.pesoUsadoG)
                .clamp(0, double.infinity);
      }
    }

    for (final uso in usosMateriaisAnterioresDaTransacao) {
      final idx = estoqueMateriaisExtras
          .indexWhere((e) => e.id == uso.idEstoqueMaterialExtra);
      if (idx >= 0) {
        final novoUso =
            estoqueMateriaisExtras[idx].quantidadeUsada - uso.quantidadeUsada;
        estoqueMateriaisExtras[idx].quantidadeUsada = novoUso < 0 ? 0 : novoUso;
      }
    }

    final novosUsos = <UsoFilamento>[];
    final novosUsosMateriaisExtras = <UsoMaterialExtra>[];
    final agora = DateTime.now();
    var seq = 0;
    final necessidadesPorMaterial = <String, double>{};
    final necessidadesPorExtra = <String, int>{};

    for (final item in itens) {
      final historicoItem = historicosPorId[item.idHistorico];
      if (historicoItem == null) {
        return 'Projeto vinculado ao item "${item.nomeHistorico}" não encontrado';
      }

      final necessidadePorMaterial =
          _calcularNecessidadePorMaterial(historicoItem, item.quantidade);
      final necessidadeMateriaisExtras =
          _calcularNecessidadeMateriaisExtras(historicoItem, item.quantidade);

      for (final entry in necessidadePorMaterial.entries) {
        necessidadesPorMaterial[entry.key] =
            (necessidadesPorMaterial[entry.key] ?? 0) + entry.value;
      }
      for (final entry in necessidadeMateriaisExtras.entries) {
        necessidadesPorExtra[entry.key] =
            (necessidadesPorExtra[entry.key] ?? 0) + entry.value;
      }
    }

    for (final entry in necessidadesPorMaterial.entries) {
      final material = entry.key;
      final necessario = entry.value;
      final disponivel = estoqueOrdenado
          .where((e) => e.material == material && !e.esgotado)
          .fold(0.0, (s, e) => s + e.pesoRestanteG);
      if (disponivel + 0.0001 < necessario) {
        return 'Estoque insuficiente de $material: precisa ${necessario.toStringAsFixed(1)}g e tem ${disponivel.toStringAsFixed(1)}g';
      }
    }

    for (final entry in necessidadesPorExtra.entries) {
      final idMaterial = entry.key;
      final necessario = entry.value;
      final idx = estoqueMateriaisExtras.indexWhere((e) => e.id == idMaterial);
      if (idx < 0) {
        return 'Material extra do estoque não encontrado para baixa';
      }
      final item = estoqueMateriaisExtras[idx];

      if (item.quantidadeRestante < necessario) {
        return 'Estoque insuficiente de ${item.nome}: precisa $necessario un e tem ${item.quantidadeRestante} un';
      }
    }

    for (final item in itens) {
      final historicoItem = historicosPorId[item.idHistorico];
      if (historicoItem == null) continue;

      final necessidadePorMaterial =
          _calcularNecessidadePorMaterial(historicoItem, item.quantidade);
      final necessidadeMateriaisExtras =
          _calcularNecessidadeMateriaisExtras(historicoItem, item.quantidade);

      for (final entry in necessidadePorMaterial.entries) {
        final material = entry.key;
        var restante = entry.value;
        for (final carretel in estoqueOrdenado
            .where((e) => e.material == material && !e.esgotado)) {
          if (restante <= 0) break;
          final disponivel = carretel.pesoRestanteG;
          if (disponivel <= 0) continue;
          final usar = restante < disponivel ? restante : disponivel;
          carretel.pesoUsadoG += usar;
          novosUsos.add(UsoFilamento(
            id: '${agora.microsecondsSinceEpoch}_$seq++',
            idEstoque: carretel.id,
            data: agora,
            pesoUsadoG: usar,
            descricao: resumoVenda,
            idHistorico: historicoItem.id,
            idTransacao: transacao.id,
          ));
          restante -= usar;
        }
      }

      for (final entry in necessidadeMateriaisExtras.entries) {
        final idMaterial = entry.key;
        final necessario = entry.value;
        final idx = estoqueMateriaisExtras.indexWhere((e) => e.id == idMaterial);
        if (idx < 0 || necessario <= 0) continue;

        estoqueMateriaisExtras[idx].quantidadeUsada += necessario;
        novosUsosMateriaisExtras.add(UsoMaterialExtra(
          id: '${agora.microsecondsSinceEpoch}_$seq++',
          idEstoqueMaterialExtra: idMaterial,
          data: agora,
          quantidadeUsada: necessario,
          descricao: resumoVenda,
          idHistorico: historicoItem.id,
          idTransacao: transacao.id,
        ));
      }
    }

    final usosSemAnteriores =
        usos.where((u) => u.idTransacao != idAnterior).toList();
    final usosMateriaisSemAnteriores =
        usosMateriaisExtras.where((u) => u.idTransacao != idAnterior).toList();
    final transacoesAtualizadas = [...transacoes];
    if (idAnterior != null) {
      transacoesAtualizadas.removeWhere((t) => t.id == idAnterior);
    }
    transacoesAtualizadas.insert(0, transacao);

    await _persistirEstoque(estoqueOrdenado);
    await _persistirEstoqueMateriaisExtras(estoqueMateriaisExtras);
    await _persistirUsos([...novosUsos, ...usosSemAnteriores]);
    await _persistirUsosMateriaisExtras(
        [...novosUsosMateriaisExtras, ...usosMateriaisSemAnteriores]);
    await _persistirTransacoes(transacoesAtualizadas);
    return null;
  }

  static Map<String, int> _calcularNecessidadeMateriaisExtras(
      HistoricoItem historico, int quantidade) {
    if (quantidade <= 0) return const {};

    final necessidade = <String, int>{};
    for (final extra in historico.model.materiaisExtras) {
      final idEstoque = extra.idEstoqueMaterialExtra?.trim() ?? '';
      if (idEstoque.isEmpty) continue;

      final unidadesPorPeca =
          extra.quantidadeUnidades <= 0 ? 1 : extra.quantidadeUnidades;
      final total = unidadesPorPeca * quantidade;
      if (total <= 0) continue;

      necessidade[idEstoque] = (necessidade[idEstoque] ?? 0) + total;
    }
    return necessidade;
  }

  static Map<String, double> _calcularNecessidadePorMaterial(
      HistoricoItem historico, int quantidade) {
    final model = historico.model;
    final necessidade = <String, double>{};

    if (model.multiCor && model.cores.isNotEmpty) {
      for (final cor in model.cores) {
        final material = cor.material.trim();
        final peso = cor.pesoGramas * quantidade;
        if (material.isEmpty || peso <= 0) continue;
        necessidade[material] = (necessidade[material] ?? 0) + peso;
      }
      return necessidade;
    }

    final material = model.materialSelecionado.trim();
    final peso = model.pesoTotal * quantidade;
    if (material.isNotEmpty && peso > 0) {
      necessidade[material] = peso;
    }
    return necessidade;
  }

  static Future<void> removerTransacao(String id) async {
    final lista = await carregarTransacoes();
    lista.removeWhere((t) => t.id == id);
    final usos = await carregarUsos();
    final usosDaTransacao = usos.where((u) => u.idTransacao == id).toList();
    final usosMateriais = await carregarUsosMateriaisExtras();
    final usosMateriaisDaTransacao =
        usosMateriais.where((u) => u.idTransacao == id).toList();

    if (usosDaTransacao.isNotEmpty) {
      final estoque = await carregarEstoque();
      for (final uso in usosDaTransacao) {
        final idx = estoque.indexWhere((e) => e.id == uso.idEstoque);
        if (idx >= 0) {
          estoque[idx].pesoUsadoG = (estoque[idx].pesoUsadoG - uso.pesoUsadoG)
              .clamp(0, double.infinity);
        }
      }
      await _persistirEstoque(estoque);
      await _persistirUsos(usos.where((u) => u.idTransacao != id).toList());
    }

    if (usosMateriaisDaTransacao.isNotEmpty) {
      final estoqueMateriais = await carregarEstoqueMateriaisExtras();
      for (final uso in usosMateriaisDaTransacao) {
        final idx = estoqueMateriais
            .indexWhere((e) => e.id == uso.idEstoqueMaterialExtra);
        if (idx >= 0) {
          final novoUso =
              estoqueMateriais[idx].quantidadeUsada - uso.quantidadeUsada;
          estoqueMateriais[idx].quantidadeUsada = novoUso < 0 ? 0 : novoUso;
        }
      }
      await _persistirEstoqueMateriaisExtras(estoqueMateriais);
      await _persistirUsosMateriaisExtras(
          usosMateriais.where((u) => u.idTransacao != id).toList());
    }

    await _persistirTransacoes(lista);
  }

  static Future<String?> salvarTransacaoComRegraDeEstoque({
    required Transacao transacao,
    required Transacao? transacaoAnterior,
    required HistoricoItem? historico,
    required int? quantidade,
    List<VendaPedidoItem>? itensVenda,
  }) async {
    final vendaNova = _isVendaDePeca(transacao);
    final vendaAnterior =
        transacaoAnterior != null && _isVendaDePeca(transacaoAnterior);

    if (vendaNova) {
      final itensVenda = _itensDaVenda(transacao,
          historico: historico, quantidade: quantidade);
      if (itensVenda.isEmpty) {
        return 'Dados da venda de peça inválidos';
      }
      return salvarOuAtualizarVendaDePeca(
        transacao: transacao,
        historico: historico,
        quantidade: quantidade,
        itensVenda: itensVenda,
        transacaoAnterior: vendaAnterior ? transacaoAnterior : null,
      );
    }

    final transacoes = await carregarTransacoes();
    if (transacaoAnterior != null) {
      transacoes.removeWhere((t) => t.id == transacaoAnterior.id);
      if (vendaAnterior) {
        final usos = await carregarUsos();
        final usosDaTransacao =
            usos.where((u) => u.idTransacao == transacaoAnterior.id).toList();
        if (usosDaTransacao.isNotEmpty) {
          final estoque = await carregarEstoque();
          for (final uso in usosDaTransacao) {
            final idx = estoque.indexWhere((e) => e.id == uso.idEstoque);
            if (idx >= 0) {
              estoque[idx].pesoUsadoG =
                  (estoque[idx].pesoUsadoG - uso.pesoUsadoG)
                      .clamp(0, double.infinity);
            }
          }
          await _persistirEstoque(estoque);
          await _persistirUsos(usos
              .where((u) => u.idTransacao != transacaoAnterior.id)
              .toList());
        }

        final usosMateriais = await carregarUsosMateriaisExtras();
        final usosMateriaisDaTransacao = usosMateriais
            .where((u) => u.idTransacao == transacaoAnterior.id)
            .toList();
        if (usosMateriaisDaTransacao.isNotEmpty) {
          final estoqueMateriais = await carregarEstoqueMateriaisExtras();
          for (final uso in usosMateriaisDaTransacao) {
            final idx = estoqueMateriais
                .indexWhere((e) => e.id == uso.idEstoqueMaterialExtra);
            if (idx >= 0) {
              final novoUso =
                  estoqueMateriais[idx].quantidadeUsada - uso.quantidadeUsada;
              estoqueMateriais[idx].quantidadeUsada = novoUso < 0 ? 0 : novoUso;
            }
          }
          await _persistirEstoqueMateriaisExtras(estoqueMateriais);
          await _persistirUsosMateriaisExtras(usosMateriais
              .where((u) => u.idTransacao != transacaoAnterior.id)
              .toList());
        }
      }
    }

    transacoes.insert(0, transacao);
    await _persistirTransacoes(transacoes);
    return null;
  }

  static Future<void> _persistirTransacoes(List<Transacao> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTransacoes, jsonEncode(lista.map((t) => t.toJson()).toList()));
  }

  static Future<List<EstoqueFilamento>> carregarEstoque() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyEstoque);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => EstoqueFilamento.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.dataCompra.compareTo(a.dataCompra));
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarCarretel(EstoqueFilamento e) async {
    final lista = await carregarEstoque();
    final idx = lista.indexWhere((x) => x.id == e.id);
    if (idx >= 0)
      lista[idx] = e;
    else
      lista.insert(0, e);
    await _persistirEstoque(lista);
  }

  static Future<void> removerCarretel(String id) async {
    final lista = await carregarEstoque();
    lista.removeWhere((e) => e.id == id);
    await _persistirEstoque(lista);
    final usos = await carregarUsos();
    usos.removeWhere((u) => u.idEstoque == id);
    await _persistirUsos(usos);
  }

  static Future<void> _persistirEstoque(List<EstoqueFilamento> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyEstoque, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<List<EstoqueMaterialExtra>>
      carregarEstoqueMateriaisExtras() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyEstoqueMateriaisExtras);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => EstoqueMaterialExtra.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.dataCadastro.compareTo(a.dataCadastro));
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarMaterialExtra(EstoqueMaterialExtra e) async {
    final lista = await carregarEstoqueMateriaisExtras();
    final idx = lista.indexWhere((x) => x.id == e.id);
    if (idx >= 0) {
      lista[idx] = e;
    } else {
      lista.insert(0, e);
    }
    await _persistirEstoqueMateriaisExtras(lista);
  }

  static Future<void> removerMaterialExtra(String id) async {
    final lista = await carregarEstoqueMateriaisExtras();
    lista.removeWhere((e) => e.id == id);
    await _persistirEstoqueMateriaisExtras(lista);

    final usos = await carregarUsosMateriaisExtras();
    usos.removeWhere((u) => u.idEstoqueMaterialExtra == id);
    await _persistirUsosMateriaisExtras(usos);
  }

  static Future<void> _persistirEstoqueMateriaisExtras(
      List<EstoqueMaterialExtra> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEstoqueMateriaisExtras,
        jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<List<UsoFilamento>> carregarUsos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUsos);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => UsoFilamento.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) {
      return [];
    }
  }

  static Future<void> registrarUso(UsoFilamento uso) async {
    final usos = await carregarUsos();
    usos.insert(0, uso);
    await _persistirUsos(usos);
    final estoque = await carregarEstoque();
    final idx = estoque.indexWhere((e) => e.id == uso.idEstoque);
    if (idx >= 0) {
      estoque[idx].pesoUsadoG += uso.pesoUsadoG;
      await _persistirEstoque(estoque);
    }
  }

  static Future<void> removerUso(UsoFilamento uso) async {
    final usos = await carregarUsos();
    usos.removeWhere((u) => u.id == uso.id);
    await _persistirUsos(usos);
    final estoque = await carregarEstoque();
    final idx = estoque.indexWhere((e) => e.id == uso.idEstoque);
    if (idx >= 0) {
      estoque[idx].pesoUsadoG =
          (estoque[idx].pesoUsadoG - uso.pesoUsadoG).clamp(0, double.infinity);
      await _persistirEstoque(estoque);
    }
  }

  static Future<void> _persistirUsos(List<UsoFilamento> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyUsos, jsonEncode(lista.map((u) => u.toJson()).toList()));
  }

  static Future<List<UsoMaterialExtra>> carregarUsosMateriaisExtras() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUsosMateriaisExtras);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => UsoMaterialExtra.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) {
      return [];
    }
  }

  static Future<void> registrarUsoMaterialExtra(UsoMaterialExtra uso) async {
    final usos = await carregarUsosMateriaisExtras();
    usos.insert(0, uso);
    await _persistirUsosMateriaisExtras(usos);

    final estoque = await carregarEstoqueMateriaisExtras();
    final idx = estoque.indexWhere((e) => e.id == uso.idEstoqueMaterialExtra);
    if (idx >= 0) {
      estoque[idx].quantidadeUsada += uso.quantidadeUsada;
      await _persistirEstoqueMateriaisExtras(estoque);
    }
  }

  static Future<void> removerUsoMaterialExtra(UsoMaterialExtra uso) async {
    final usos = await carregarUsosMateriaisExtras();
    usos.removeWhere((u) => u.id == uso.id);
    await _persistirUsosMateriaisExtras(usos);

    final estoque = await carregarEstoqueMateriaisExtras();
    final idx = estoque.indexWhere((e) => e.id == uso.idEstoqueMaterialExtra);
    if (idx >= 0) {
      final novoUso = estoque[idx].quantidadeUsada - uso.quantidadeUsada;
      estoque[idx].quantidadeUsada = novoUso < 0 ? 0 : novoUso;
      await _persistirEstoqueMateriaisExtras(estoque);
    }
  }

  static Future<void> _persistirUsosMateriaisExtras(
      List<UsoMaterialExtra> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsosMateriaisExtras,
        jsonEncode(lista.map((u) => u.toJson()).toList()));
  }

  static Map<String, double> resumoMes(
      List<Transacao> todas, int ano, int mes) {
    final f = todas.where((t) => t.data.year == ano && t.data.month == mes);
    final r = f
        .where((t) => t.tipo == TipoTransacao.receita)
        .fold(0.0, (s, t) => s + t.valor);
    final d = f
        .where((t) => t.tipo == TipoTransacao.despesa)
        .fold(0.0, (s, t) => s + t.valor);
    return {'receitas': r, 'despesas': d, 'saldo': r - d};
  }

  static Map<String, double> resumoGeral(List<Transacao> todas) {
    final r = todas
        .where((t) => t.tipo == TipoTransacao.receita)
        .fold(0.0, (s, t) => s + t.valor);
    final d = todas
        .where((t) => t.tipo == TipoTransacao.despesa)
        .fold(0.0, (s, t) => s + t.valor);
    return {'receitas': r, 'despesas': d, 'saldo': r - d};
  }

  static List<Map<String, dynamic>> historico6Meses(List<Transacao> todas) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      final r = resumoMes(todas, d.year, d.month);
      return {
        'ano': d.year,
        'mes': d.month,
        'receitas': r['receitas']!,
        'despesas': r['despesas']!
      };
    });
  }

  static Map<String, double> despesasPorCategoria(
      List<Transacao> todas, int ano, int mes) {
    final mapa = <String, double>{};
    for (final t in todas.where((t) =>
        t.tipo == TipoTransacao.despesa &&
        t.data.year == ano &&
        t.data.month == mes)) {
      mapa[t.categoria] = (mapa[t.categoria] ?? 0) + t.valor;
    }
    return Map.fromEntries(
        mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }
}
