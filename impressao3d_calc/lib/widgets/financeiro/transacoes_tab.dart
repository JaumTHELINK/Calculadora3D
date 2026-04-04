import 'package:flutter/material.dart';
import '../../models/financeiro_model.dart';
import '../../services/financeiro_service.dart';
import '../../screens/nova_transacao_screen.dart';

class TransacoesTab extends StatelessWidget {
  final List<Transacao> transacoes;
  final VoidCallback onRefresh;
  const TransacoesTab({super.key, required this.transacoes, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (transacoes.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('💸', style: TextStyle(fontSize: 48)), SizedBox(height: 16),
      Text('Nenhuma transação neste mês', style: TextStyle(fontSize: 16, color: Colors.grey)),
    ]));

    final porDia = <String, List<Transacao>>{};
    for (final t in transacoes) {
      porDia.putIfAbsent('${t.data.year}-${t.data.month}-${t.data.day}', () => []).add(t);
    }
    final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: dias.length,
      itemBuilder: (ctx, i) {
        final lista = porDia[dias[i]]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_fmtDia(lista.first.data), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey))),
          ...lista.map((t) => _buildItem(context, t)),
        ]);
      },
    );
  }

  Widget _buildItem(BuildContext context, Transacao t) {
    final isReceita = t.tipo == TipoTransacao.receita;
    final cor = isReceita ? const Color(0xFF059669) : const Color(0xFFEF4444);
    final cat = todasCategorias.firstWhere((c) => c.nome == t.categoria,
        orElse: () => CategoriaFinanceira(nome: t.categoria, emoji: '💰', tipo: t.tipo));

    return Dismissible(
      key: Key(t.id), direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24)),
      onDismissed: (_) async { await FinanceiroService.removerTransacao(t.id); onRefresh(); },
      child: Container(margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(width: 42, height: 42,
            decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 20)))),
          title: Text(t.descricao.isNotEmpty ? t.descricao : t.categoria,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.categoria, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (t.nomeHistorico != null) Text('📦 ${t.nomeHistorico}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6C3CE1))),
          ]),
          trailing: Text('${isReceita ? '+' : '-'} R\$ ${t.valor.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: cor)),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => NovaTransacaoScreen(tipoInicial: t.tipo, edicao: t)));
            onRefresh();
          },
        )),
    );
  }

  String _fmtDia(DateTime d) {
    final meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    final hoje = DateTime.now(); final ontem = hoje.subtract(const Duration(days: 1));
    if (d.day == hoje.day && d.month == hoje.month && d.year == hoje.year) return 'Hoje';
    if (d.day == ontem.day && d.month == ontem.month && d.year == ontem.year) return 'Ontem';
    return '${d.day} de ${meses[d.month - 1]}';
  }
}
