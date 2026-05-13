import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/financeiro_model.dart';
import '../../services/financeiro_service.dart';

class ResumoTab extends StatelessWidget {
  final List<Transacao> transacoes;
  final DateTime mesSelecionado;
  final Map<String, double> resumo;

  const ResumoTab({super.key, required this.transacoes, required this.mesSelecionado, required this.resumo});

  @override
  Widget build(BuildContext context) {
    final resumoGeral = FinanceiroService.resumoGeral(transacoes);
    final hist6 = FinanceiroService.historico6Meses(transacoes);
    final categorias = FinanceiroService.despesasPorCategoria(transacoes, mesSelecionado.year, mesSelecionado.month);
    final saldo = resumo['saldo']!;
    final receitas = resumo['receitas']!;
    final despesas = resumo['despesas']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        // Totais Históricos
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10)
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📊 Totais Históricos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _summaryCardDark('Receitas', resumoGeral['receitas']!, const Color(0xFF34D399), Icons.arrow_upward_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _summaryCardDark('Despesas', resumoGeral['despesas']!, const Color(0xFFFCA5A5), Icons.arrow_downward_rounded)),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Saldo total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
              Text(_fmt(resumoGeral['saldo']!),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: resumoGeral['saldo']! >= 0 ? const Color(0xFF34D399) : const Color(0xFFFCA5A5)
                )),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        // Resumo do Mês
        Text('Resumo do Mês', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF555577))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _summaryCard('Receitas', receitas, const Color(0xFF059669), Icons.arrow_upward_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Despesas', despesas, const Color(0xFFEF4444), Icons.arrow_downward_rounded)),
        ]),
        const SizedBox(height: 10),
        _saldoCard(saldo),
        const SizedBox(height: 16),
        _card('Receitas vs Despesas (6 meses)', Icons.bar_chart_rounded,
          SizedBox(height: 200, child: hist6.every((m) => (m['receitas'] as double) == 0 && (m['despesas'] as double) == 0)
            ? const Center(child: Text('Sem dados', style: TextStyle(color: Colors.grey)))
            : _BarChart(dados: hist6))),
        if (categorias.isNotEmpty) ...[
          const SizedBox(height: 12),
          _card('Despesas por categoria', Icons.pie_chart_outline_rounded,
            Column(children: categorias.entries.map((e) {
              final pct = despesas > 0 ? e.value / despesas : 0.0;
              final cat = todasCategorias.firstWhere((c) => c.nome == e.key,
                  orElse: () => const CategoriaFinanceira(nome: 'Outros', emoji: '💸', tipo: TipoTransacao.despesa));
              return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_fmt(e.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct.toDouble(), backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)), minHeight: 6)),
                  Text('${(pct*100).toStringAsFixed(1)}% das despesas', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ])),
              ]));
            }).toList())),
        ],
        const SizedBox(height: 12),
        _RoiCard(transacoes: transacoes),
      ]),
    );
  }

  Widget _summaryCard(String label, double valor, Color cor, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: cor.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: cor.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: cor, size: 16), const SizedBox(width: 6),
        Text(label, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 6),
      Text(_fmt(valor), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cor)),
    ]));

  Widget _summaryCardDark(String label, double valor, Color cor, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: cor.withOpacity(0.2))
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: cor, size: 14),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600))
      ]),
      const SizedBox(height: 4),
      Text(_fmt(valor), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cor)),
    ]));


  Widget _saldoCard(double saldo) {
    final positivo = saldo >= 0;
    return Container(width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positivo ? [const Color(0xFF059669), const Color(0xFF34D399)] : [const Color(0xFFEF4444), const Color(0xFFFCA5A5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Saldo do mês', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(_fmt(saldo.abs()), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
        ]),
        Icon(positivo ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 36),
      ]));
  }

  Widget _card(String title, IconData icon, Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 18, color: const Color(0xFF059669)), const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 14), child,
    ]));

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> dados;
  const _BarChart({required this.dados});

  @override
  Widget build(BuildContext context) {
    final meses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final maxVal = dados.fold<double>(0, (m, d) {
      final r = d['receitas'] as double; final de = d['despesas'] as double;
      return [m, r, de].reduce((a, b) => a > b ? a : b);
    });
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2 == 0 ? 100 : maxVal * 1.2,
      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, _, rod, rodIdx) => BarTooltipItem(
          '${rodIdx == 0 ? 'Receita' : 'Despesa'}\nR\$ ${rod.toY.toStringAsFixed(2)}',
          const TextStyle(color: Colors.white, fontSize: 11)))),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
          getTitlesWidget: (v, _) => Text(meses[(dados[v.toInt()]['mes'] as int) - 1],
            style: const TextStyle(fontSize: 10, color: Colors.grey)))),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42,
          getTitlesWidget: (v, _) => Text(v == 0 ? '0' : 'R\$${(v/1000).toStringAsFixed(1)}k',
            style: const TextStyle(fontSize: 9, color: Colors.grey)))),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
      barGroups: List.generate(dados.length, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: dados[i]['receitas'] as double, color: const Color(0xFF059669), width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        BarChartRodData(toY: dados[i]['despesas'] as double, color: const Color(0xFFEF4444), width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
      ])),
    ));
  }
}

class _RoiCard extends StatefulWidget {
  final List<Transacao> transacoes;
  const _RoiCard({required this.transacoes});
  @override State<_RoiCard> createState() => _RoiCardState();
}

class _RoiCardState extends State<_RoiCard> {
  final _investCtrl = TextEditingController();
  double _investimento = 0;
  @override void dispose() { _investCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final totalR = widget.transacoes.where((t) => t.tipo == TipoTransacao.receita).fold(0.0, (s, t) => s + t.valor);
    final totalD = widget.transacoes.where((t) => t.tipo == TipoTransacao.despesa).fold(0.0, (s, t) => s + t.valor);
    final lucro = totalR - totalD;
    final investTotal = _investimento + totalD;
    final roi = investTotal > 0 ? (lucro / investTotal) * 100 : 0.0;
    final recuperado = lucro >= _investimento && _investimento > 0;

    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Text('🖨️', style: TextStyle(fontSize: 18)), SizedBox(width: 8),
          Text('ROI da Impressora', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 4),
        const Text('Quanto do seu investimento você já recuperou', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Text('Valor pago na impressora (R\$)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555577)))),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: TextField(controller: _investCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
            decoration: InputDecoration(hintText: '0', prefixText: 'R\$ ', filled: true, fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8))),
            onChanged: (v) => setState(() => _investimento = double.tryParse(v) ?? 0))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _stat('Total receitas', totalR, const Color(0xFF059669))),
          const SizedBox(width: 10),
          Expanded(child: _stat('Total despesas', totalD, const Color(0xFFEF4444))),
          const SizedBox(width: 10),
          Expanded(child: _stat('Lucro acumulado', lucro, lucro >= 0 ? const Color(0xFF059669) : const Color(0xFFEF4444))),
        ]),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: recuperado ? const Color(0xFF059669).withOpacity(0.08) : const Color(0xFFF59E0B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: recuperado ? const Color(0xFF059669).withOpacity(0.2) : const Color(0xFFF59E0B).withOpacity(0.2))),
          child: Row(children: [
            Text(recuperado ? '✅' : '⏳', style: const TextStyle(fontSize: 22)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recuperado ? 'Investimento recuperado!' : _investimento > 0 ? 'Ainda em recuperação' : 'Informe o valor da impressora',
                  style: TextStyle(fontWeight: FontWeight.w700, color: recuperado ? const Color(0xFF059669) : const Color(0xFFF59E0B))),
              Text(_investimento > 0 ? 'ROI: ${roi.toStringAsFixed(1)}%' : 'para calcular o ROI',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
          ])),
      ]));
  }

  Widget _stat(String l, double v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 2),
    Text('R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
  ]);
}
