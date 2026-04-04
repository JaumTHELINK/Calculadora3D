import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calculator_model.dart';

class HistoricoService {
  static const _key = 'historico_calculos';

  static Future<List<HistoricoItem>> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => HistoricoItem.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.data.compareTo(a.data));
    } catch (_) { return []; }
  }

  static Future<void> salvar(HistoricoItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await carregar();
    lista.insert(0, item);
    await prefs.setString(_key, jsonEncode(lista.take(100).map((e) => e.toJson()).toList()));
  }

  static Future<void> remover(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await carregar();
    lista.removeWhere((e) => e.id == id);
    await prefs.setString(_key, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> limparTudo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
