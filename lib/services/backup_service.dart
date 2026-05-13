import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── HTTP client autenticado ──────────────────────────────────────────────────

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

// ─── Serviço de backup ────────────────────────────────────────────────────────

class BackupService {
  static const _fileName = 'calculadora3d_backup.json';
  static const _prefKey = 'backup_last_sync';
  static String? _lastAuthError;

  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  static GoogleSignInAccount? _currentUser;

  static bool get isSignedIn => _currentUser != null;
  static String? get userEmail => _currentUser?.email;
  static String? get userName => _currentUser?.displayName;
  static String? get lastAuthError => _lastAuthError;

  // ─── Login / logout ────────────────────────────────────────────────────────

  static Future<bool> signIn() async {
    try {
      _lastAuthError = null;
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account == null) {
        _lastAuthError = 'Login cancelado pelo usuário.';
      }
      return account != null;
    } catch (e) {
      _lastAuthError = e.toString();
      debugPrint('BackupService signIn error: $e');
      return false;
    }
  }

  static Future<bool> signInSilently() async {
    try {
      _lastAuthError = null;
      final account = await _googleSignIn.signInSilently();
      _currentUser = account;
      return account != null;
    } catch (e) {
      _lastAuthError = e.toString();
      debugPrint('BackupService signInSilently error: $e');
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // ─── Drive client ──────────────────────────────────────────────────────────

  static Future<drive.DriveApi?> _getDriveApi() async {
    final account = _currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      debugPrint('BackupService: Sem conta autenticada');
      return null;
    }
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('BackupService: Falha ao obter autenticação');
      return null;
    }
    final client = _AuthClient({'Authorization': 'Bearer $token'});
    return drive.DriveApi(client);
  }

  // ─── Backup (upload) ───────────────────────────────────────────────────────

  /// Coleta todos os dados do SharedPreferences e envia para o Drive
  static Future<BackupResult> fazerBackup() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return BackupResult.notSignedIn();

      final prefs = await SharedPreferences.getInstance();
      final allData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        final v = prefs.get(key);
        allData[key] = v;
      }
      allData['_backup_timestamp'] = DateTime.now().toIso8601String();
      allData['_backup_version'] = '1.3';

      final json = jsonEncode(allData);
      final bytes = utf8.encode(json);
      final stream = Stream.fromIterable([bytes]);

      // Procura arquivo existente
      final existing = await _findBackupFile(api);

      final meta = drive.File()
        ..name = _fileName
        ..parents = existing == null ? ['appDataFolder'] : null;

      final media =
          drive.Media(stream, bytes.length, contentType: 'application/json');

      if (existing != null) {
        await api.files.update(meta, existing, uploadMedia: media);
      } else {
        await api.files.create(meta, uploadMedia: media);
      }

      // Salva timestamp do último backup
      await prefs.setString(_prefKey, DateTime.now().toIso8601String());

      return BackupResult.success(DateTime.now());
    } catch (e) {
      debugPrint('BackupService fazerBackup error: $e');
      return BackupResult.error(e.toString());
    }
  }

  // ─── Restaurar (download) ─────────────────────────────────────────────────

  static Future<BackupResult> restaurarBackup() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return BackupResult.notSignedIn();

      final fileId = await _findBackupFile(api);
      if (fileId == null) return BackupResult.noFile();

      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = <int>[];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
      }

      final json = utf8.decode(chunks);
      final data = jsonDecode(json) as Map<String, dynamic>;

      // Restaura no SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        if (entry.key.startsWith('_backup_')) continue;
        final v = entry.value;
        if (v is String) await prefs.setString(entry.key, v);
        if (v is int) await prefs.setInt(entry.key, v);
        if (v is double) await prefs.setDouble(entry.key, v);
        if (v is bool) await prefs.setBool(entry.key, v);
      }

      final ts = data['_backup_timestamp'] as String?;
      final backupDate = ts != null ? DateTime.tryParse(ts) : null;
      return BackupResult.success(backupDate ?? DateTime.now());
    } catch (e) {
      debugPrint('BackupService restaurarBackup error: $e');
      return BackupResult.error(e.toString());
    }
  }

  // ─── Data do último backup ────────────────────────────────────────────────

  static Future<DateTime?> ultimoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefKey);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  // ─── Helper: encontra o arquivo de backup no Drive ────────────────────────

  static Future<String?> _findBackupFile(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_fileName'",
      $fields: 'files(id)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id;
    }
    return null;
  }
}

// ─── Resultado do backup ──────────────────────────────────────────────────────

enum BackupStatus { success, error, notSignedIn, noFile }

class BackupResult {
  final BackupStatus status;
  final DateTime? timestamp;
  final String? errorMessage;

  BackupResult._({required this.status, this.timestamp, this.errorMessage});

  factory BackupResult.success(DateTime ts) =>
      BackupResult._(status: BackupStatus.success, timestamp: ts);
  factory BackupResult.error(String msg) =>
      BackupResult._(status: BackupStatus.error, errorMessage: msg);
  factory BackupResult.notSignedIn() =>
      BackupResult._(status: BackupStatus.notSignedIn);
  factory BackupResult.noFile() => BackupResult._(status: BackupStatus.noFile);

  bool get isSuccess => status == BackupStatus.success;
}
