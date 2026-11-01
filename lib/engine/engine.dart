enum Level { safe, suspicious, scam }

class Verdict {
  final Level level;
  final int score;
  final List<String> reasons; // keys like "r_otp" -> localized in strings.dart
  final bool fromServer;
  final String? advice;
  const Verdict(this.level, this.score, this.reasons, {this.fromServer = false, this.advice});
}

class _Rule {
  final String key;
  final int weight;
  final RegExp rx;
  _Rule(this.key, this.weight, String p) : rx = RegExp(p, caseSensitive: false);
}

/// On-phone detector. Works offline: English, Roman-Urdu, Urdu and Sindhi script.
class ScamEngine {
  static final List<_Rule> _rules = [
    _Rule('r_urgent', 15, r'''urgent|immediately|right now|last chance|within \d+ ?(hours?|hrs|minutes?|mins)|abhi|foran|jaldi|فوری|فوراً|فورا|ابھی|جلدی|هاڻي ئي|جلدي|فوري'''),
    _Rule('r_prize', 25, r'''you('ve| have)? won|winner|lottery|prize|lucky draw|free (money|gift|sim|cash)|bisp|benazir|ehsaas|\b8171\b|inam|انعام|لاٹری|لاٽري|بینظیر|بي نظير|احساس|مبارک ہو|مبارڪ'''),
    _Rule('r_otp', 40, r'''\botp\b|\bpin\b|\bcvv\b|password|verification code|secret code|share (the )?code|code (share|send|bata)|او ?ٹی ?پی|او ?ٽي ?پي|پاس ?ورڈ|پاسورڊ|پن کوڈ|پن نمبر|کوڈ بتا|ڪوڊ ٻڌاي|ڪوڊ ڏيو'''),
    _Rule('r_link', 20, r'''https?://\S+|www\.\S+|\b[a-z0-9-]+\.(xyz|top|click|info|shop|cc|buzz|link)\b'''),
    _Rule('r_link', 15, r'''bit\.ly|tinyurl|cutt\.ly|rb\.gy|goo\.gl|t\.co/|wa\.me'''),
    _Rule('r_blocked', 20, r'''block(ed)?\b|suspend|deactivat|will expire|sim (band|block)|account (band|closed)|بلاک|بند ہو|بند کر|معطل|بلاڪ|بند ٿي'''),
    _Rule('r_authority', 15, r'''\bfia\b|nadra|\bpta\b|\bfbr\b|state bank|police|\bbank\b|customer care|helpline|jazz ?cash|easy ?paisa|\bhbl\b|\bubl\b|meezan|اسٹیٹ بینک|پولیس|ایف آئی اے|نادرا|بینک|بئنڪ|پوليس|اسٽيٽ بئنڪ'''),
    _Rule('r_money', 25, r'''send (me )?(the )?(money|rs\.?|amount)|transfer|load (card|balance)|account (number|no)|پیسے بھیج|رقم|ٹرانسفر|اکاؤنٹ نمبر|اڪائونٽ نمبر|پئسا موڪل|رقم موڪل|ٽرانسفر'''),
    _Rule('r_family', 30, r'''accident|arrested|kidnap|\bbail\b|حادثہ|گرفتار|اغوا|حادثو'''),
    _Rule('r_secret', 20, r'''don'?t tell|do not tell|keep (it )?(a )?secret|kisi ko (na|mat)|کسی کو (نہ|مت)|راز|ڪنهن کي نه|ڳجهو'''),
  ];

  static final RegExp _reassurance = RegExp(
      r'''never share|do not share|don't share|نہ بتائیں|نه ٻڌايو|نہ دیں''',
      caseSensitive: false);

  static const _pushy = ['r_link', 'r_money', 'r_urgent', 'r_blocked', 'r_prize', 'r_secret', 'r_family'];

  static Verdict analyze(String text) {
    final t = text.trim();
    if (t.isEmpty) return const Verdict(Level.safe, 0, []);
    int score = 0;
    final keys = <String>{};
    for (final r in _rules) {
      if (r.rx.hasMatch(t)) {
        score += r.weight;
        keys.add(r.key);
      }
    }
    if (keys.contains('r_otp') &&
        (keys.contains('r_urgent') || keys.contains('r_blocked') || keys.contains('r_authority'))) {
      score += 15;
    }
    if (keys.contains('r_prize') && keys.contains('r_link')) score += 10;
    // A genuine bank warning such as "Never share your OTP" must not be flagged.
    if (keys.contains('r_otp') && _reassurance.hasMatch(t) && !_pushy.any(keys.contains)) {
      score -= 45;
    }
    score = score.clamp(0, 100).toInt();
    final level = score >= 55 ? Level.scam : (score >= 25 ? Level.suspicious : Level.safe);
    return Verdict(level, score, keys.toList());
  }

  /// Hide long digit runs (phone numbers, card numbers, OTPs) before anything leaves the phone.
  static String redact(String s) =>
      s.replaceAll(RegExp(r'[0-9۰-۹٠-٩][0-9۰-۹٠-٩ \-]{3,}[0-9۰-۹٠-٩]'), '•••');

  /// Combine on-phone result with the AI server's opinion; never silently drop a strong local warning.
  static Verdict merge(Verdict local, Verdict server) {
    var level = server.level;
    var score = server.score;
    if (local.level == Level.scam && level == Level.safe) {
      level = Level.suspicious;
      if (score < 30) score = 30;
    }
    return Verdict(level, score, {...server.reasons, ...local.reasons}.toList(),
        fromServer: true, advice: server.advice);
  }
}