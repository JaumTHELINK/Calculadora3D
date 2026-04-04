import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financeiro_model.dart';

class FinanceiroService {
  static const _keyTransacoes = 'financeiro_transacoes';
  static const _keyEstoque    = 'financeiro_estoque';
  static const _keyUsos       = 'financeiro_usos';

  static Future<List<Transacao>> carregarTransacoes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTransacoes);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Transacao.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) { return []; }
  }

  static Future<void> salvarTransacao(Transacao t) async {
    final lista = await carregarTransacoes();
    lista.insert(0, t);
    await _persistirTransacoes(lista);
  }

  static Future<void> removerTransacao(String id) async {
    final lista = await carregarTransacoes();
    lista.removeWhere((t) => t.id == id);
    await _persistirTransacoes(lista);
  }

  static Future<void> _persistirTransacoes(List<Transacao> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTransacoes, jsonEncode(lista.map((t) => t.toJson()).toList()));
  }

  static Future<List<EstoqueFilamento>> carregarEstoque() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyEstoque);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => EstoqueFilamento.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.dataCompra.compareTo(a.dataCompra));
    } catch (_) { return []; }
  }

  static Future<void> salvarCarretel(EstoqueFilamento e) async {
    final lista = await carregarEstoque();
    final idx = lista.indexWhere((x) => x.id == e.id);
    if (idx >= 0) lista[idx] = e; else lista.insert(0, e);
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
    await prefs.setString(_keyEstoque, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<List<UsoFilamento>> carregarUsos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUsos);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => UsoFilamento.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) { return []; }
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
      estoque[idx].pesoUsadoG = (estoque[idx].pesoUsadoG - uso.pesoUsadoG).clamp(0, double.infinity);
      await _persistirEstoque(estoque);
    }
  }

  static Future<void> _persistirUsos(List<UsoFilamento> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsos, jsonEncode(lista.map((u) => u.toJson()).toList()));
  }

  static Map<String, double> resumoMes(List<Transacao> todas, int ano, int mes) {
    final f = todas.where((t) => t.data.year == ano && t.data.month == mes);
    final r = f.where((t) => t.tipo == TipoTransacao.receita).fold(0.0, (s, t) => s + t.valor);
    final d = f.where((t) => t.tipo == TipoTransacao.despesa).fold(0.0, (s, t) => s + t.valor);
    return {'receitas': r, 'despesas': d, 'saldo': r - d};
  }

  static List<Map<String, dynamic>> historico6Meses(List<Transacao> todas) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      final r = resumoMes(todas, d.year, d.month);
      return {'ano': d.year, 'mes': d.month, 'receitas': r['receitas']!, 'despesas': r['despesas']!};
    });
  }

  static Map<String, double> despesasPorCategoria(List<Transacao> todas, int ano, int mes) {
    final mapa = <String, double>{};
    for (final t in todas.where((t) => t.tipo == TipoTransacao.despesa && t.data.year == ano && t.data.month == mes)) {
      mapa[t.categoria] = (mapa[t.categoria] ?? 0) + t.valor;
    }
    return Map.fromEntries(mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }
}
