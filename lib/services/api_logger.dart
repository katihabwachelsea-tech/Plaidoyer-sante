// lib/services/api_logger.dart
//
// Logger centralisé pour TOUTES les requêtes HTTP et erreurs.
// Visible dans la console Flutter (Debug Console / flutter run logs).
// Désactivé automatiquement en mode release.

import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiLogger {
  ApiLogger._();

  // ── couleurs ANSI (visibles dans VS Code / Android Studio terminal) ───────
  static const _reset  = '\x1B[0m';
  static const _cyan   = '\x1B[36m';
  static const _green  = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _red    = '\x1B[31m';
  static const _grey   = '\x1B[90m';
  static const _bold   = '\x1B[1m';

  // ── Longueur max du body loggé (caractères) ───────────────────────────────
  static const int _maxBodyLength = 800;

  // ─────────────────────────────────────────────────────────────────────────
  /// Log d'une requête sortante.
  /// Appelé AVANT d'envoyer la requête.
  // ─────────────────────────────────────────────────────────────────────────
  static void request({
    required String method,
    required String url,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;

    final time = _timestamp();
    debugPrint('$_cyan$_bold┌─ 🌐 REQUEST  [$time] ──────────────────────────────$_reset');
    debugPrint('$_cyan│$_reset  $_bold$method$_reset  $url');

    // Affiche seulement les 25 premiers chars du token Bearer pour sécurité
    if (headers != null) {
      final auth = headers['Authorization'];
      if (auth != null) {
        final preview = auth.length > 35 ? '${auth.substring(0, 35)}…' : auth;
        debugPrint('$_cyan│$_reset  ${_grey}Authorization: $preview$_reset');
      }
    }

    if (body != null) {
      final formatted = _prettyBody(body);
      debugPrint('$_cyan│$_reset  ${_grey}Body:$_reset\n${_indent(formatted)}');
    }
    debugPrint('$_cyan└──────────────────────────────────────────────────────$_reset');
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Log d'une réponse reçue.
  /// Appelé APRÈS avoir reçu la réponse, avant de la parser.
  // ─────────────────────────────────────────────────────────────────────────
  static void response({
    required String url,
    required int statusCode,
    required String body,
  }) {
    if (!kDebugMode) return;

    final time      = _timestamp();
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final isServer  = statusCode >= 500;

    final color = isSuccess ? _green : (isServer ? _red : _yellow);
    final emoji = isSuccess ? '✅' : (isServer ? '💥' : '⚠️ ');

    debugPrint('$color$_bold┌─ $emoji RESPONSE [$time] ──────────────────────────────$_reset');
    debugPrint('$color│$_reset  Status : $_bold$statusCode$_reset  ${_statusLabel(statusCode)}');
    debugPrint('$color│$_reset  URL    : $url');

    final formatted = _prettyBody(body);
    if (isSuccess) {
      debugPrint('$color│$_reset  Body   :\n${_indent(_grey + formatted + _reset)}');
    } else {
      // En cas d'erreur, on affiche le body complet en rouge pour qu'on voie tout
      debugPrint('$_red│$_reset  Body   :\n${_indent(_bold + formatted + _reset)}');
    }
    debugPrint('$color└──────────────────────────────────────────────────────$_reset');
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Log d'une erreur réseau ou exception Dart.
  /// Appelé dans les blocs catch.
  // ─────────────────────────────────────────────────────────────────────────
  static void error({
    required String url,
    required Object error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final time = _timestamp();
    debugPrint('$_red$_bold┌─ ❌ ERROR    [$time] ──────────────────────────────$_reset');
    debugPrint('$_red│$_reset  URL   : $url');
    debugPrint('$_red│$_reset  Error : $_bold$error$_reset');
    if (stackTrace != null) {
      // N'afficher que les 5 premières lignes de la stack trace
      final lines = stackTrace.toString().split('\n').take(5).join('\n');
      debugPrint('$_red│$_reset  Stack :\n${_indent(_grey + lines + _reset)}');
    }
    debugPrint('$_red└──────────────────────────────────────────────────────$_reset');
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Log simple pour les appels FCM/device-token (pas de body sensible).
  // ─────────────────────────────────────────────────────────────────────────
  static void fcm(String message) {
    if (!kDebugMode) return;
    debugPrint('$_cyan[FCM]$_reset $message');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _prettyBody(Object body) {
    String raw;
    if (body is String) {
      raw = body;
    } else if (body is Map || body is List) {
      try {
        raw = const JsonEncoder.withIndent('  ').convert(body);
      } catch (_) {
        raw = body.toString();
      }
    } else {
      raw = body.toString();
    }

    // Essayer de pretty-printer les strings JSON
    if (raw.isNotEmpty && (raw.startsWith('{') || raw.startsWith('['))) {
      try {
        final decoded = jsonDecode(raw);
        raw = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {/* pas du JSON valide, on garde tel quel */}
    }

    raw = raw.length > _maxBodyLength
        ? '${raw.substring(0, _maxBodyLength)}\n… (tronqué à $_maxBodyLength chars)'
        : raw;
    return raw;
  }

  /// Indente chaque ligne avec "│  " pour l'alignement visuel
  static String _indent(String text) {
    return text
        .split('\n')
        .map((l) => '$_grey│$_reset    $l')
        .join('\n');
  }

  static String _statusLabel(int code) {
    return switch (code) {
      200 => 'OK',
      201 => 'Created',
      204 => 'No Content',
      400 => 'Bad Request',
      401 => 'Unauthorized',
      403 => 'Forbidden',
      404 => 'Not Found',
      422 => 'Unprocessable Entity',
      429 => 'Too Many Requests',
      500 => 'Internal Server Error',
      502 => 'Bad Gateway',
      503 => 'Service Unavailable',
      _   => '',
    };
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}'
        '.${now.millisecond.toString().padLeft(3, '0')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
