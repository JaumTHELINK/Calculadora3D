import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calculator_model.dart';
import '../services/preferencias_service.dart';
import '../services/backup_service.dart';
import '../widgets/section_card.dart';
import 'backup_screen.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});
  @override State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  bool _loading = true;
  String _material = 'PLA';
  final _custoPorKgCtrl   = TextEditingController();
  final _potenciaCtrl     = TextEditingController();
  final _tarifaCtrl       = TextEditingController();
  final _valorHoraCtrl    = TextEditingController();
  final _embalagemCtrl    = TextEditingController();
  final _ivaCtrl          = TextEditingController();
  final _depreciacaoCtrl  = TextEditingController();
  List<PlataformaConfig> _plataformas = plataformasPadrao();
  final List<TextEditingController> _taxaCtrlList = [];
  final List<TextEditingController> _taxaFixaCtrlList = [];

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    final p = await PreferenciasService.carregar();
    setState(() {
      _material = p['material'];
      _custoPorKgCtrl.text  = _fmt(p['custoPorKg']);
      _potenciaCtrl.text    = _fmt(p['potencia']);
      _tarifaCtrl.text      = _fmt(p['tarifaEnergia']);
      _valorHoraCtrl.text   = _fmt(p['valorHora']);
      _embalagemCtrl.text   = _fmt(p['custoEmbalagem']);
      _ivaCtrl.text         = _fmt(p['taxaIVA']);
      _depreciacaoCtrl.text = _fmt(p['depreciacao']);
      _plataformas = p['plataformas'] as List<PlataformaConfig>;
      _taxaCtrlList.clear(); _taxaFixaCtrlList.clear();
      for (var pl in _plataformas) {
        _taxaCtrlList.add(TextEditingController(text: _fmt(pl.taxa)));
        _taxaFixaCtrlList.add(TextEditingController(text: pl.taxaFixa > 0 ? _fmt(pl.taxaFixa) : ''));
      }
      _loading = false;
    });
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    final d = (v as num).toDouble();
    if (d == 0) return '';
    return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
  }

  Future<void> _salvar() async {
    await PreferenciasService.salvarMaterial(_material);
    final kg = double.tryParse(_custoPorKgCtrl.text) ?? 110;
    if (kg > 0) await PreferenciasService.salvarCustoPorKg(kg);
    final pot = double.tryParse(_potenciaCtrl.text) ?? 200;
    if (pot > 0) await PreferenciasService.salvarPotencia(pot);
    final tar = double.tryParse(_tarifaCtrl.text) ?? 0.75;
    if (tar > 0) await PreferenciasService.salvarTarifaEnergia(tar);
    final hora = double.tryParse(_valorHoraCtrl.text) ?? 20;
    if (hora > 0) await PreferenciasService.salvarValorHora(hora);
    await PreferenciasService.salvarCustoEmbalagem(double.tryParse(_embalagemCtrl.text) ?? 0);
    await PreferenciasService.salvarTaxaIVA(double.tryParse(_ivaCtrl.text) ?? 0);
    await PreferenciasService.salvarDepreciacao(double.tryParse(_depreciacaoCtrl.text) ?? 0);
    for (int i = 0; i < _plataformas.length; i++) {
      _plataformas[i].taxa = double.tryParse(_taxaCtrlList[i].text) ?? _plataformas[i].taxa;
      _plataformas[i].taxaFixa = double.tryParse(_taxaFixaCtrlList[i].text) ?? 0.0;
    }
    await PreferenciasService.salvarPlataformas(_plataformas);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Configurações salvas!'), backgroundColor: Color(0xFF10B981), duration: Duration(seconds: 2)));
      Navigator.pop(context, true);
    }
  }

  @override void dispose() {
    for (var c in [_custoPorKgCtrl,_potenciaCtrl,_tarifaCtrl,_valorHoraCtrl,_embalagemCtrl,_ivaCtrl,_depreciacaoCtrl]) c.dispose();
    for (var c in [..._taxaCtrlList,..._taxaFixaCtrlList]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C3CE1), foregroundColor: Colors.white,
        title: const Row(children: [Icon(Icons.settings_rounded, size: 20), SizedBox(width: 8),
          Text('Configurações', style: TextStyle(fontWeight: FontWeight.w700))]),
        actions: [TextButton.icon(onPressed: _salvar,
          icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
          label: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16,16,16,40), child: Column(children: [
        // Backup banner
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
          child: Container(
            padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C3CE1), Color(0xFF9B6DFF)]),
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.backup_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Backup Google Drive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(BackupService.isSignedIn ? 'Conectado: ${BackupService.userEmail}' : 'Toque para configurar',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),

        SectionCard(icon: Icons.water_drop_outlined, title: 'Filamento padrão', child: Column(children: [
          _label('Material padrão'), const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _material, isExpanded: true,
              items: materiais.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _material = v!)))),
          const SizedBox(height: 12),
          _numField(_custoPorKgCtrl, 'Custo por kg (R\$)', 'Ex: 110', 'R\$'),
        ])),
        const SizedBox(height: 12),
        SectionCard(icon: Icons.bolt_rounded, title: 'Energia elétrica', iconColor: const Color(0xFFF59E0B),
          child: Row(children: [
            Expanded(child: _numField(_potenciaCtrl, 'Potência da impressora', '200', 'W')),
            const SizedBox(width: 12),
            Expanded(child: _numField(_tarifaCtrl, 'Tarifa (R\$/kWh)', '0.75', 'R\$')),
          ])),
        const SizedBox(height: 12),
        SectionCard(icon: Icons.handyman_outlined, title: 'Mão de obra & Embalagem',
          child: Row(children: [
            Expanded(child: _numField(_valorHoraCtrl, 'Valor hora (R\$)', '20', 'R\$')),
            const SizedBox(width: 12),
            Expanded(child: _numField(_embalagemCtrl, 'Embalagem (R\$)', '0', 'R\$')),
          ])),
        const SizedBox(height: 12),
        SectionCard(icon: Icons.tune_rounded, title: 'Impostos & Depreciação',
          child: Row(children: [
            Expanded(child: _numField(_ivaCtrl, 'Imposto / IVA (%)', '0', '%')),
            const SizedBox(width: 12),
            Expanded(child: _numField(_depreciacaoCtrl, 'Depreciação (R\$)', '0', 'R\$')),
          ])),
        const SizedBox(height: 12),
        SectionCard(icon: Icons.storefront_outlined, title: 'Taxas das plataformas', iconColor: const Color(0xFFEF4444),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Taxa % e valor fixo por peça (R\$)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            ...List.generate(_plataformas.length, (i) {
              final p = _plataformas[i];
              return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                _plataformaIcon(p.nome), const SizedBox(width: 10),
                Expanded(child: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                _taxaField(_taxaCtrlList[i], '%'),
                const SizedBox(width: 6),
                _taxaField(_taxaFixaCtrlList[i], 'R\$', hint: '0'),
              ]));
            }),
          ])),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _salvar, icon: const Icon(Icons.save_rounded),
          label: const Text('Salvar configurações', style: TextStyle(fontSize: 15)),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C3CE1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ])),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555577)));

  Widget _numField(TextEditingController ctrl, String label, String hint, String suffix) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label), const SizedBox(height: 6),
      TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          suffixText: suffix, suffixStyle: const TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.w600, fontSize: 13),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.8)))),
    ]);

  Widget _taxaField(TextEditingController ctrl, String suffix, {String hint = '0'}) =>
    SizedBox(width: 72, child: TextField(controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        suffixText: suffix, suffixStyle: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 12),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8)))));

  Widget _plataformaIcon(String nome) {
    final icons = {'Shopee': ('🛍️', const Color(0xFFEE4D2D)), 'Mercado Livre': ('🛒', const Color(0xFFFFE600)),
      'TikTok Shop': ('🎵', const Color(0xFF010101)), 'Revendedor': ('🤝', const Color(0xFF10B981))};
    final entry = icons[nome];
    return Container(width: 36, height: 36,
      decoration: BoxDecoration(color: (entry?.$2 ?? Colors.grey).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(entry?.$1 ?? '🏪', style: const TextStyle(fontSize: 18))));
  }
}
