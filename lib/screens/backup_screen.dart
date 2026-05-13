import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  bool _signedIn = false;
  String? _userEmail;
  String? _userName;
  DateTime? _ultimoBackup;
  String? _statusMsg;
  bool _statusOk = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await BackupService.signInSilently();
    final ultimo = await BackupService.ultimoBackup();
    setState(() {
      _signedIn = BackupService.isSignedIn;
      _userEmail = BackupService.userEmail;
      _userName = BackupService.userName;
      _ultimoBackup = ultimo;
      _loading = false;
    });
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final ok = await BackupService.signIn();
    final authError = BackupService.lastAuthError;
    setState(() {
      _signedIn = ok;
      _userEmail = BackupService.userEmail;
      _userName = BackupService.userName;
      _loading = false;
      _statusMsg = ok
          ? 'Conta conectada com sucesso!'
          : authError == null
              ? 'Não foi possível conectar.'
              : 'Não foi possível conectar. Detalhe: $authError';
      _statusOk = ok;
    });
  }

  Future<void> _signOut() async {
    await BackupService.signOut();
    setState(() {
      _signedIn = false;
      _userEmail = null;
      _userName = null;
      _statusMsg = 'Conta desconectada.';
      _statusOk = true;
    });
  }

  Future<void> _fazerBackup() async {
    setState(() {
      _loading = true;
      _statusMsg = null;
    });
    final result = await BackupService.fazerBackup();
    final ultimo = await BackupService.ultimoBackup();
    setState(() {
      _loading = false;
      _ultimoBackup = ultimo;
      _statusOk = result.isSuccess;
      _statusMsg = result.isSuccess
          ? '✅ Backup realizado com sucesso!'
          : result.status == BackupStatus.notSignedIn
              ? 'Conecte sua conta Google primeiro.'
              : 'Erro: ${result.errorMessage}';
    });
  }

  Future<void> _restaurar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: const Text(
            'Isso vai substituir todos os dados atuais pelo backup salvo no Google Drive. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _loading = true;
      _statusMsg = null;
    });
    final result = await BackupService.restaurarBackup();
    setState(() {
      _loading = false;
      _statusOk = result.isSuccess;
      _statusMsg = result.isSuccess
          ? '✅ Dados restaurados! Reinicie o app para ver as mudanças.'
          : result.status == BackupStatus.noFile
              ? 'Nenhum backup encontrado no Drive.'
              : result.status == BackupStatus.notSignedIn
                  ? 'Conecte sua conta Google primeiro.'
                  : 'Erro: ${result.errorMessage}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C3CE1),
        foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.backup_rounded, size: 20),
          SizedBox(width: 8),
          Text('Backup Google Drive',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status da conta
                  _buildContaCard(),
                  const SizedBox(height: 16),

                  // Info
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // Último backup
                  if (_ultimoBackup != null) ...[
                    _buildUltimoBackupCard(),
                    const SizedBox(height: 16),
                  ],

                  // Status msg
                  if (_statusMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _statusOk
                            ? const Color(0xFF059669).withOpacity(0.1)
                            : const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _statusOk
                              ? const Color(0xFF059669).withOpacity(0.3)
                              : const Color(0xFFEF4444).withOpacity(0.3),
                        ),
                      ),
                      child: Text(_statusMsg!,
                          style: TextStyle(
                              color: _statusOk
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Botões
                  if (!_signedIn)
                    _bigBtn(
                      icon: Icons.login_rounded,
                      label: 'Conectar conta Google',
                      color: const Color(0xFF6C3CE1),
                      onTap: _signIn,
                    )
                  else ...[
                    _bigBtn(
                      icon: Icons.cloud_upload_rounded,
                      label: 'Fazer backup agora',
                      color: const Color(0xFF6C3CE1),
                      onTap: _fazerBackup,
                    ),
                    const SizedBox(height: 10),
                    _bigBtn(
                      icon: Icons.cloud_download_rounded,
                      label: 'Restaurar backup',
                      color: const Color(0xFFF59E0B),
                      onTap: _restaurar,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Desconectar conta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildContaCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _signedIn
                    ? const Color(0xFF059669).withOpacity(0.1)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _signedIn
                    ? Icons.account_circle_rounded
                    : Icons.person_outline_rounded,
                color: _signedIn ? const Color(0xFF059669) : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _signedIn ? (_userName ?? 'Conectado') : 'Não conectado',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    _signedIn
                        ? (_userEmail ?? '')
                        : 'Faça login para ativar o backup',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _signedIn
                    ? const Color(0xFF059669).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _signedIn ? 'Ativo' : 'Inativo',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _signedIn ? const Color(0xFF059669) : Colors.grey),
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF6C3CE1).withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6C3CE1).withOpacity(0.2)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF6C3CE1)),
              SizedBox(width: 8),
              Text('Como funciona',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C3CE1),
                      fontSize: 13)),
            ]),
            SizedBox(height: 8),
            Text(
              '• O backup salva todos os seus dados (histórico, financeiro, estoque) em um arquivo privado no seu Google Drive.\n'
              '• Apenas este app tem acesso ao arquivo — não aparece na pasta normal do Drive.\n'
              '• Use "Restaurar" para recuperar os dados em um novo celular ou após reinstalar o app.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF6C3CE1), height: 1.6),
            ),
          ],
        ),
      );

  Widget _buildUltimoBackupCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF059669), size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Último backup',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_fmtData(_ultimoBackup!),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ],
        ),
      );

  Widget _bigBtn(
          {required IconData icon,
          required String label,
          required Color color,
          required VoidCallback onTap}) =>
      FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  String _fmtData(DateTime d) {
    final meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
