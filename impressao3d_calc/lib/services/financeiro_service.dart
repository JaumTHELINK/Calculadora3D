import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calculator_model.dart';
import '../models/financeiro_model.dart';

class FinanceiroService {
  static const _keyTransacoes = 'financeiro_transacoes';
  static const _keyEstoque = 'financeiro_estoque';
  static const _keyUsos = 'financeiro_usos';

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

  static Map<String, double> calcularNecessidadePorMaterial(
          HistoricoItem historico, int quantidade) =>
      _calcularNecessidadePorMaterial(historico, quantidade);

  static Future<String?> salvarOuAtualizarVendaDePeca({
    required Transacao transacao,
    required HistoricoItem historico,
    required int quantidade,
    Transacao? transacaoAnterior,
  }) async {
    if (quantidade <= 0) return 'Informe uma quantidade válida';

    final necessidadePorMaterial =
        _calcularNecessidadePorMaterial(historico, quantidade);
    if (necessidadePorMaterial.isEmpty) {
      return 'Projeto sem consumo de filamento para baixar no estoque';
    }

    final transacoes = await carregarTransacoes();
    final estoque = await carregarEstoque();
    final usos = await carregarUsos();
    final estoqueOrdenado = [...estoque]
      ..sort((a, b) => a.dataCompra.compareTo(b.dataCompra));

    final idAnterior = transacaoAnterior?.id;
    final usosAnterioresDaTransacao = idAnterior == null
        ? <UsoFilamento>[]
        : usos.where((u) => u.idTransacao == idAnterior).toList();

    for (final uso in usosAnterioresDaTransacao) {
      final idx = estoqueOrdenado.indexWhere((e) => e.id == uso.idEstoque);
      if (idx >= 0) {
        estoqueOrdenado[idx].pesoUsadoG =
            (estoqueOrdenado[idx].pesoUsadoG - uso.pesoUsadoG)
                .clamp(0, double.infinity);
      }
    }

    for (final entry in necessidadePorMaterial.entries) {
      final material = entry.key;
      final necessario = entry.value;
      final disponivel = estoqueOrdenado
          .where((e) => e.material == material && !e.esgotado)
          .fold(0.0, (s, e) => s + e.pesoRestanteG);
      if (disponivel + 0.0001 < necessario) {
        return 'Estoque insuficiente de $material: precisa ${necessario.toStringAsFixed(1)}g e tem ${disponivel.toStringAsFixed(1)}g';
      }
    }

    final novosUsos = <UsoFilamento>[];
    final agora = DateTime.now();
    var seq = 0;
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
          id: '${agora.microsecondsSinceEpoch}_${seq++}',
          idEstoque: carretel.id,
          data: agora,
          pesoUsadoG: usar,
          descricao:
              'Venda de peça: ${historico.model.nomePeca.isNotEmpty ? historico.model.nomePeca : "Sem nome"} (x$quantidade)',
          idHistorico: historico.id,
          idTransacao: transacao.id,
        ));
        restante -= usar;
      }
    }

    final usosSemAnteriores =
        usos.where((u) => u.idTransacao != idAnterior).toList();
    final transacoesAtualizadas = [...transacoes];
    if (idAnterior != null) {
      transacoesAtualizadas.removeWhere((t) => t.id == idAnterior);
    }
    transacoesAtualizadas.insert(0, transacao);

    await _persistirEstoque(estoqueOrdenado);
    await _persistirUsos([...novosUsos, ...usosSemAnteriores]);
    await _persistirTransacoes(transacoesAtualizadas);
    return null;
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

    await _persistirTransacoes(lista);
  }

  static Future<String?> salvarTransacaoComRegraDeEstoque({
    required Transacao transacao,
    required Transacao? transacaoAnterior,
    required HistoricoItem? historico,
    required int? quantidade,
  }) async {
    final vendaNova = _isVendaDePeca(transacao);
    final vendaAnterior =
        transacaoAnterior != null && _isVendaDePeca(transacaoAnterior);

    if (vendaNova) {
      if (historico == null || quantidade == null || quantidade <= 0) {
        return 'Dados da venda de peça inválidos';
      }
      return salvarOuAtualizarVendaDePeca(
        transacao: transacao,
        historico: historico,
        quantidade: quantidade,
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
