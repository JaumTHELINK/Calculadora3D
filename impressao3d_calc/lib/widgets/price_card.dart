import 'package:flutter/material.dart';

class PriceCard extends StatelessWidget {
  final String label, margem;
  final double preco, precoComIVA, taxaIVA;
  final Color color;

  const PriceCard({super.key, required this.label, required this.margem,
    required this.preco, required this.precoComIVA, required this.color, required this.taxaIVA});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 6),
        Text(_fmt(preco), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        Text('$margem margem', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        if (taxaIVA > 0) ...[
          const SizedBox(height: 4),
          Text('${_fmt(precoComIVA)} c/ imposto',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}
