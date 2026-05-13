import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calculator_model.dart';

class PreferenciasService {
  static const _material       = 'pref_material';
  static const _custoPorKg     = 'pref_custo_por_kg';
  static const _potencia       = 'pref_potencia';
  static const _tarifaEnergia  = 'pref_tarifa_energia';
  static const _valorHora      = 'pref_valor_hora';
  static const _custoEmbalagem = 'pref_custo_embalagem';
  static const _taxaIVA        = 'pref_taxa_iva';
  static const _depreciacao    = 'pref_depreciacao';
  static const _plataformas    = 'pref_plataformas';

  static Future<void> salvarMaterial(String v) async =>
      (await SharedPreferences.getInstance()).setString(_material, v);
  static Future<void> salvarCustoPorKg(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_custoPorKg, v);
  static Future<void> salvarPotencia(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_potencia, v);
  static Future<void> salvarTarifaEnergia(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_tarifaEnergia, v);
  static Future<void> salvarValorHora(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_valorHora, v);
  static Future<void> salvarCustoEmbalagem(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_custoEmbalagem, v);
  static Future<void> salvarTaxaIVA(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_taxaIVA, v);
  static Future<void> salvarDepreciacao(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_depreciacao, v);
  static Future<void> salvarPlataformas(List<PlataformaConfig> plats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plataformas, jsonEncode(plats.map((p) => p.toJson()).toList()));
  }

  static Future<Map<String, dynamic>> carregar() async {
    final p = await SharedPreferences.getInstance();
    List<PlataformaConfig> plats = plataformasPadrao();
    final platsRaw = p.getString(_plataformas);
    if (platsRaw != null) {
      try {
        final list = jsonDecode(platsRaw) as List<dynamic>;
        plats = list.map((e) => PlataformaConfig.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return {
      'material':       p.getString(_material)       ?? 'PLA',
      'custoPorKg':     p.getDouble(_custoPorKg)      ?? 110.0,
      'potencia':       p.getDouble(_potencia)         ?? 200.0,
      'tarifaEnergia':  p.getDouble(_tarifaEnergia)   ?? 0.75,
      'valorHora':      p.getDouble(_valorHora)        ?? 20.0,
      'custoEmbalagem': p.getDouble(_custoEmbalagem)  ?? 0.0,
      'taxaIVA':        p.getDouble(_taxaIVA)          ?? 0.0,
      'depreciacao':    p.getDouble(_depreciacao)      ?? 0.0,
      'plataformas':    plats,
    };
  }
}
