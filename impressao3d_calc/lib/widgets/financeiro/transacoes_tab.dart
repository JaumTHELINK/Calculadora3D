import 'package:flutter/material.dart';
import '../../models/calculator_model.dart';
import '../../models/financeiro_model.dart';
import '../../services/financeiro_service.dart';
import '../../services/historico_service.dart';
import '../../screens/nova_transacao_screen.dart';

class TransacoesTab extends StatelessWidget {
  final List<Transacao> transacoes;
  final VoidCallback onRefresh;
  const TransacoesTab(
      {super.key, required this.transacoes, required this.onRefresh});

  Future<bool> _confirmarExclusao(BuildContext context, Transacao t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transação'),
        content: Text(
            'Deseja excluir "${t.descricao.isNotEmpty ? t.descricao : t.categoria}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _desfazerExclusao(Transacao t) async {
    final isVenda =
        t.tipo == TipoTransacao.receita && t.categoria == 'Venda de peça';
    if (!isVenda) {
      await FinanceiroService.salvarTransacao(t);
      return null;
    }

    final qtd = t.quantidadePecas;
    final idHistorico = t.idHistorico;
    if (qtd == null || qtd <= 0 || idHistorico == null) {
      return 'Não foi possível desfazer: faltam dados da venda de peça.';
    }

    final historico = await HistoricoService.carregar();
    HistoricoItem? item;
    try {
      item = historico.firstWhere((h) => h.id == idHistorico);
    } catch (_) {
      item = null;
    }
    if (item == null) {
      return 'Não foi possível desfazer: projeto vinculado não encontrado.';
    }

    return FinanceiroService.salvarTransacaoComRegraDeEstoque(
      transacao: t,
      transacaoAnterior: null,
      historico: item,
      quantidade: qtd,
    );
  }

  Future<void> _removerComUndo(BuildContext context, Transacao t) async {
    await FinanceiroService.removerTransacao(t.id);
    onRefresh();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('Transação excluída'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            final erro = await _desfazerExclusao(t);
            if (erro != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(erro)),
              );
            }
            onRefresh();
          },
        ),
      ),
    );

    // Garante que o aviso não fique preso na tela em cenários de acessibilidade.
    Future.delayed(const Duration(seconds: 6), () {
      if (context.mounted) {
        controller.close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (transacoes.isEmpty)
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('💸', style: TextStyle(fontSize: 48)),
        SizedBox(height: 16),
        Text('Nenhuma transação neste mês',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
      ]));

    final porDia = <String, List<Transacao>>{};
    for (final t in transacoes) {
      porDia
          .putIfAbsent('${t.data.year}-${t.data.month}-${t.data.day}', () => [])
          .add(t);
    }
    final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: dias.length,
      itemBuilder: (ctx, i) {
        final lista = porDia[dias[i]]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_fmtDia(lista.first.data),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey))),
          ...lista.map((t) => _buildItem(context, t)),
        ]);
      },
    );
  }

  Widget _buildItem(BuildContext context, Transacao t) {
    final isReceita = t.tipo == TipoTransacao.receita;
    final cor = isReceita ? const Color(0xFF059669) : const Color(0xFFEF4444);
    final cat = todasCategorias.firstWhere((c) => c.nome == t.categoria,
        orElse: () =>
            CategoriaFinanceira(nome: t.categoria, emoji: '💰', tipo: t.tipo));

    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmarExclusao(context, t),
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(14)),
          child:
              const Icon(Icons.delete_rounded, color: Colors.white, size: 24)),
      onDismissed: (_) async {
        await _removerComUndo(context, t);
      },
      child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: cor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child:
                        Text(cat.emoji, style: const TextStyle(fontSize: 20)))),
            title: Text(t.descricao.isNotEmpty ? t.descricao : t.categoria,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.categoria,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (t.quantidadePecas != null)
                Text('Quantidade: ${t.quantidadePecas} peça(s)',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF0F766E))),
              if (t.nomeHistorico != null)
                Text('📦 ${t.nomeHistorico}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6C3CE1))),
            ]),
            trailing: Text(
                '${isReceita ? '+' : '-'} R\$ ${t.valor.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15, color: cor)),
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          NovaTransacaoScreen(tipoInicial: t.tipo, edicao: t)));
              onRefresh();
            },
          )),
    );
  }

  String _fmtDia(DateTime d) {
    final meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    if (d.day == hoje.day && d.month == hoje.month && d.year == hoje.year)
      return 'Hoje';
    if (d.day == ontem.day && d.month == ontem.month && d.year == ontem.year)
      return 'Ontem';
    return '${d.day} de ${meses[d.month - 1]}';
  }
}
