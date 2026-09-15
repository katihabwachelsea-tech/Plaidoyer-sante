// lib/services/api_logger.dart
//
// Logger centralisé pour toutes les requêtes HTTP.
// Visible dans la console Flutter (Run > Debug Console).

import 'package:flutter/foundation.dart';

class ApiLogger {
  ApiLogger._();

  // ── couleurs ANSI (visibles dans VS Code / Android Studio) ───────────────
  static const _reset  = '\x1B[0m';
  static const _cyan   = '\x1B[36m';
  static const _green  = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _red    = '\x1B[31m';
  static const _grey   = '\x1B[90m';
  static const _bold   = '\x1B[1m';

  /// Log d'une requête sortante
  static void request({
    required String method,
    required String url,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;

    final time = _timestamp();
    debugPrint('$_cyan$_bold┌─ 🌐 REQUEST [$time] ─────────────────────────$_reset');
    debugPrint('$_cyan│$_reset $_bold$method$_reset  $url');
    if (headers != null) {
      final authHeader = headers['Authorization'];
      if (authHeader != null) {
        final preview = authHeader.length > 30
            ? '${authHeader.substring(0, 30)}…'
            : authHeader;
        debugPrint('$_cyan│$_reset ${_grey}Authorization: $preview$_reset');
      }
    }
    if (body != null) {
      debugPrint('$_cyan│$_reset ${_grey}Body: $body$_reset');
    }
    debugPrint('$_cyan└─────────────────────────────────────────────$_reset');
  }

  /// Log d'une réponse reçue
  static void response({
    required String url,
    required int statusCode,
    required String body,
  }) {
    if (!kDebugMode) return;

    final time = _timestamp();
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final color   = isSuccess ? _green : (statusCode >= 500 ? _red : _yellow);
    final emoji   = isSuccess ? '✅' : (statusCode >= 500 ? '💥' : '⚠️');
    final preview = body.length > 300 ? '${body.substring(0, 300)}…' : body;

    debugPrint('$color$_bold┌─ $emoji RESPONSE [$time] ───────────────────────$_reset');
    debugPrint('$color│$_reset Status: $_bold$statusCode$_reset');
    debugPrint('$color│$_reset URL:    $url');
    debugPrint('$color│$_reset Body:   $_grey$preview$_reset');
    debugPrint('$color└─────────────────────────────────────────────$_reset');
  }

  /// Log d'une erreur réseau / exception
  static void error({
    required String url,
    required Object error,
  }) {
    if (!kDebugMode) return;

    final time = _timestamp();
    debugPrint('$_red$_bold┌─ ❌ ERROR [$time] ────────────────────────────$_reset');
    debugPrint('$_red│$_reset URL:   $url');
    debugPrint('$_red│$_reset Error: $_bold$error$_reset');
    debugPrint('$_red└─────────────────────────────────────────────$_reset');
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}'
        '.${now.millisecond.toString().padLeft(3, '0')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
