import 'package:flutter/material.dart';
import '../models/calculator_model.dart';
import '../services/historico_service.dart';

class HistoricoScreen extends StatefulWidget {
  final Function(CalculatorModel)? onCarregarCalculo;
  const HistoricoScreen({super.key, this.onCarregarCalculo});
  @override State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<HistoricoItem> _itens = [];
  bool _loading = true;

  @override void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final lista = await HistoricoService.carregar();
    setState(() { _itens = lista; _loading = false; });
  }

  Future<void> _remover(HistoricoItem item) async {
    await HistoricoService.remover(item.id);
    await _carregar();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cálculo removido'), duration: Duration(seconds: 2)));
  }

  Future<void> _limparTudo() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Limpar histórico'),
      content: const Text('Deseja apagar todos os cálculos salvos?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar tudo')),
      ],
    ));
    if (ok == true) { await HistoricoService.limparTudo(); await _carregar(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C3CE1), foregroundColor: Colors.white,
        title: const Row(children: [Icon(Icons.history_rounded, size: 20), SizedBox(width: 8),
          Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700))]),
        actions: [if (_itens.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep_rounded), onPressed: _limparTudo)],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _itens.isEmpty ? _buildVazio()
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _itens.length,
              itemBuilder: (ctx, i) => _buildCard(_itens[i])),
    );
  }

  Widget _buildVazio() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16),
    const Text('Nenhum cálculo salvo ainda', style: TextStyle(fontSize: 16, color: Colors.grey)),
  ]));

  Widget _buildCard(HistoricoItem item) {
    final m = item.model;
    return Dismissible(
      key: Key(item.id), direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28)),
      onDismissed: (_) => _remover(item),
      child: Container(margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
        child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () {
          if (widget.onCarregarCalculo != null) showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Carregar cálculo'),
            content: Text('Carregar "${m.nomePeca.isNotEmpty ? m.nomePeca : 'Sem nome'}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: () { Navigator.pop(ctx); widget.onCarregarCalculo!(m); Navigator.pop(context); },
                  child: const Text('Carregar')),
            ],
          ));
        },
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(m.nomePeca.isNotEmpty ? m.nomePeca : 'Sem nome',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)))),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  onPressed: () => _remover(item), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
            Text(_fmtData(item.data), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(children: [
              _chip(m.materialSelecionado, const Color(0xFF6C3CE1)),
              const SizedBox(width: 8),
              _chip('${m.pesoTotal.toStringAsFixed(0)}g', Colors.grey),
              const SizedBox(width: 8),
              if (m.tempoImpressaoHoras > 0) _chip('${m.tempoImpressaoHoras.toStringAsFixed(1)}h', const Color(0xFF3B82F6)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _val('Custo total', m.custoTotalSemMargem, Colors.grey.shade700),
              _val('Padrão (40%)', m.precoPadrao, const Color(0xFF3B82F6)),
              _val('Premium (60%)', m.precoPremium, const Color(0xFFF59E0B)),
            ]),
          ])),
        ),
      ),
    );
  }

  Widget _chip(String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(l, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)));

  Widget _val(String l, double v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    const SizedBox(height: 2),
    Text(_fmt(v), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
  ]);

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtData(DateTime d) {
    final m = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
}
