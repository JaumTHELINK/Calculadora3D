import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calculator_model.dart';

/// Serviço responsável por persistir e gerenciar o histórico de cálculos salvos.
///
/// Usa `SharedPreferences` para armazenar até 100 itens e mantém uma lista de
/// categorias utilizadas, com helpers para renomear/remover categorias.
class HistoricoService {
  static const _key = 'historico_calculos';
  static const _keyCategorias = 'historico_categorias';
  static const String categoriaPadrao = 'Sem categoria';

  static Future<List<HistoricoItem>> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HistoricoItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> carregarCategorias() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCategorias);
    if (raw != null) {
      try {
        final lista = (jsonDecode(raw) as List<dynamic>)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (!lista.contains(categoriaPadrao)) {
          lista.insert(0, categoriaPadrao);
        }
        return lista;
      } catch (_) {}
    }

    final historicos = await carregar();
    final categorias = <String>{categoriaPadrao};
    for (final item in historicos) {
      final categoria = item.categoria.trim();
      if (categoria.isNotEmpty) categorias.add(categoria);
    }
    final lista = categorias.toList()..sort();
    await _persistirCategorias(lista);
    return lista;
  }

  static Future<void> salvarCategoria(String categoria) async {
    final nome = categoria.trim();
    if (nome.isEmpty) return;
    final categorias = await carregarCategorias();
    if (!categorias.contains(nome)) {
      categorias.add(nome);
      categorias.sort();
      await _persistirCategorias(categorias);
    }
  }

  static Future<void> renomearCategoria(String antiga, String nova) async {
    final nomeAntigo = antiga.trim();
    final nomeNovo = nova.trim();
    if (nomeAntigo.isEmpty || nomeNovo.isEmpty || nomeAntigo == nomeNovo)
      return;

    final categorias = await carregarCategorias();
    final idx = categorias.indexWhere((c) => c == nomeAntigo);
    if (idx >= 0) {
      categorias[idx] = nomeNovo;
      final ordenadas = categorias.toSet().toList()..sort();
      await _persistirCategorias(ordenadas);
    }

    final historicos = await carregar();
    var alterou = false;
    for (final item in historicos) {
      if (item.categoria == nomeAntigo) {
        item.categoria = nomeNovo;
        alterou = true;
      }
    }
    if (alterou) {
      await _persistirHistorico(historicos);
    }
  }

  static Future<void> removerCategoria(String categoria) async {
    final nome = categoria.trim();
    if (nome.isEmpty || nome == categoriaPadrao) return;

    final categorias = await carregarCategorias();
    categorias.removeWhere((c) => c == nome);
    if (!categorias.contains(categoriaPadrao)) {
      categorias.insert(0, categoriaPadrao);
    }
    await _persistirCategorias(categorias.toSet().toList()..sort());

    final historicos = await carregar();
    var alterou = false;
    for (final item in historicos) {
      if (item.categoria == nome) {
        item.categoria = categoriaPadrao;
        alterou = true;
      }
    }
    if (alterou) {
      await _persistirHistorico(historicos);
    }
  }

  static Future<void> salvar(HistoricoItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await carregar();
    item.categoria =
        item.categoria.trim().isEmpty ? categoriaPadrao : item.categoria.trim();
    final idx = lista.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      lista[idx] = item;
    } else {
      lista.insert(0, item);
    }
    await prefs.setString(
        _key, jsonEncode(lista.take(100).map((e) => e.toJson()).toList()));
    await salvarCategoria(item.categoria);
  }

  static Future<void> remover(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await carregar();
    lista.removeWhere((e) => e.id == id);
    await prefs.setString(
        _key, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> limparTudo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _persistirHistorico(List<HistoricoItem> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(lista.take(100).map((e) => e.toJson()).toList()));
  }

  static Future<void> _persistirCategorias(List<String> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyCategorias, jsonEncode(lista.toSet().toList()..sort()));
  }
}
