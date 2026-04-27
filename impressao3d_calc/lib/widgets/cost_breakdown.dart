import 'package:flutter/material.dart';
import '../models/calculator_model.dart';

class CostBreakdown extends StatelessWidget {
  final CalculatorModel model;
  const CostBreakdown({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final total = model.custoTotalSemMargem;
    final items = [
      _CI('Material', model.custoMaterial, const Color(0xFF3B82F6)),
      _CI('Mão de obra', model.custoMaoDeObra, const Color(0xFF10B981)),
      _CI('Energia', model.custoEnergia, const Color(0xFFF59E0B)),
      _CI('Embalagem', model.custoEmbalagem, const Color(0xFF8B5CF6)),
      _CI('Hardware', model.custoHardware, const Color(0xFFEF4444)),
      _CI('Depreciação', model.custoMaquina, const Color(0xFF6B7280)),
      _CI('Mat. extras', model.custoMateriaisExtras, const Color(0xFF0EA5E9)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: items
            .map((i) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: i.c.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i.c.withOpacity(0.15))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(i.l,
                            style: TextStyle(
                                fontSize: 11,
                                color: i.c,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_fmt(i.v),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E))),
                      ]),
                ))
            .toList(),
      ),
      if (model.materiaisExtras.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Detalhamento — Materiais extras',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0EA5E9))),
            const SizedBox(height: 8),
            ...model.materiaisExtras
                .where((e) => e.custo > 0)
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                e.nome.isNotEmpty
                                    ? '${e.nome}${e.quantidadeUnidades > 1 ? ' (${e.quantidadeUnidades} un)' : ''}'
                                    : 'Item',
                                style: const TextStyle(fontSize: 13)),
                            Text(_fmt(e.custo),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0EA5E9))),
                          ]),
                    )),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      if (total > 0) ...[
        const Text('Alocação de custos',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444466))),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
              height: 18,
              child: Row(
                children: items
                    .where((i) => i.v > 0)
                    .map((i) => Flexible(
                          flex: (i.v / total * 1000).round(),
                          child: Container(color: i.c),
                        ))
                    .toList(),
              )),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: items
              .where((i) => i.v > 0)
              .map((i) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: i.c, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${i.l} ${(i.v / total * 100).toStringAsFixed(0)}%',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]))
              .toList(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100)),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Custo total entregue',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCC2222))),
            Text(_fmt(total),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFCC2222))),
          ]),
        ),
      ] else
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: Text('Nenhum dado de custo disponível',
                  style: TextStyle(color: Colors.grey))),
        ),
    ]);
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _CI {
  final String l;
  final double v;
  final Color c;
  _CI(this.l, this.v, this.c);
}
