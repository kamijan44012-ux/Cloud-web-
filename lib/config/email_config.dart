/// EmailJS configuration for sending 6-digit verification codes.
///
/// These are PUBLIC client keys (safe to commit). Get them free at
/// https://www.emailjs.com :
///   1. Create an account → add an Email Service (e.g. Gmail) → copy Service ID.
///   2. Create an Email Template with the variables {{to_email}} and {{code}}
///      in the body, e.g. "Your Chicken Hunter code is {{code}}" → copy
///      Template ID.
///   3. Account → API Keys → copy your Public Key.
///   4. In EmailJS → Account → Security, allow your site domain
///      (kamijan44012-ux.github.io) or turn off "Use Private Key for API calls".
///
/// Until these are filled in, the app falls back to Firebase's email
/// verification LINK so sign-up is never blocked.
class EmailConfig {
  static const String serviceId = '';
  static const String templateId = '';
  static const String publicKey = '';

  /// Template variable names — change only if your EmailJS template differs.
  static const String varEmail = 'to_email';
  static const String varCode = 'code';

  static bool get isConfigured =>
      serviceId.isNotEmpty && templateId.isNotEmpty && publicKey.isNotEmpty;
}
