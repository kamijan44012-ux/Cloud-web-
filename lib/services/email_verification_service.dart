import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/email_config.dart';

/// Sends and checks 6-digit email verification codes via EmailJS (a free
/// client-side email service). Used only when [EmailConfig.isConfigured]; the
/// app otherwise falls back to Firebase's verification link.
class EmailVerificationService {
  EmailVerificationService._();
  static final EmailVerificationService instance =
      EmailVerificationService._();

  String? _code;
  String? _email;
  DateTime? _sentAt;

  bool get usesCode => EmailConfig.isConfigured;

  String _generate() {
    final Random rnd = Random.secure();
    return (rnd.nextInt(900000) + 100000).toString(); // 100000–999999
  }

  /// Generates and emails a fresh code to [email]. Returns null on success or
  /// an error message to show the player.
  Future<String?> sendCode(String email) async {
    if (!usesCode) return 'Email code service not configured.';
    final String code = _generate();
    _code = code;
    _email = email.trim();
    _sentAt = DateTime.now();
    try {
      final http.Response res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'service_id': EmailConfig.serviceId,
          'template_id': EmailConfig.templateId,
          'user_id': EmailConfig.publicKey,
          'template_params': <String, String>{
            EmailConfig.varEmail: _email!,
            EmailConfig.varCode: code,
          },
        }),
      );
      if (res.statusCode == 200) return null;
      final String detail = res.body.trim();
      debugPrint('EmailJS send failed: ${res.statusCode} $detail');
      return 'Email error ${res.statusCode}: '
          '${detail.isEmpty ? "no detail from EmailJS" : detail}';
    } catch (e) {
      debugPrint('EmailVerificationService.sendCode: $e');
      return 'Network/CORS error contacting EmailJS: $e';
    }
  }

  /// Returns true if [input] matches the last code sent (within 15 minutes).
  bool verify(String input) {
    if (_code == null || _sentAt == null) return false;
    if (DateTime.now().difference(_sentAt!) > const Duration(minutes: 15)) {
      return false;
    }
    final bool ok = input.trim() == _code;
    if (ok) {
      _code = null; // single-use
    }
    return ok;
  }

  void clear() {
    _code = null;
    _email = null;
    _sentAt = null;
  }
}
