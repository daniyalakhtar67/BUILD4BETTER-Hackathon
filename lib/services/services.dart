import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../engine/engine.dart';
import '../string/string.dart';

// ───────────── Config ─────────────
// Android emulator -> your PC:   http://10.0.2.2:3000
// Real phone -> your PC WiFi IP: http://192.168.1.10:3000  (same WiFi)
// After deploying use your https:// URL.
// NOTE: on a real phone 10.0.2.2 will NOT work. Put your PC's WiFi IP here.
const String kBaseUrl = 'http://10.0.2.2:3000';

/// Most family members a person can save.
const int kMaxContacts = 5;

// ───────────── One family member ─────────────
class Contact {
  final String name;
  final String phone;
  const Contact(this.name, this.phone);

  Map<String, String> toJson() => {'n': name, 'p': phone};
  factory Contact.fromJson(Map<String, dynamic> j) => Contact((j['n'] ?? '').toString(), (j['p'] ?? '').toString());
}

// ───────────── App state (language, consent, family, last result) ─────────────
class AppState extends ChangeNotifier {
  late SharedPreferences _sp;
  int lang = 2; // 0 EN, 1 UR, 2 SD
  bool consent = false;
  bool cloud = true;
  List<Contact> contacts = [];
  Verdict? last;

  // Kept so older code that asks for "the" family contact still works (= the first one).
  String get familyName => contacts.isEmpty ? '' : contacts.first.name;
  String get familyPhone => contacts.isEmpty ? '' : contacts.first.phone;
  bool get hasFamily => contacts.any((c) => c.phone.trim().isNotEmpty);

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    lang = _sp.getInt('lang') ?? 2;
    consent = _sp.getBool('consent') ?? false;
    cloud = _sp.getBool('cloud') ?? true;

    final raw = _sp.getString('contacts');
    if (raw != null) {
      try {
        contacts = (jsonDecode(raw) as List).map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        contacts = [];
      }
    } else {
      // Older versions saved just one contact. Move it into the new list.
      final oldPhone = _sp.getString('familyPhone') ?? '';
      if (oldPhone.trim().isNotEmpty) {
        contacts = [Contact(_sp.getString('familyName') ?? '', oldPhone)];
        _saveContacts();
      }
    }
  }

  void _saveContacts() => _sp.setString('contacts', jsonEncode(contacts.map((c) => c.toJson()).toList()));

  void setLang(int l) {
    lang = l;
    _sp.setInt('lang', l);
    notifyListeners();
  }

  void accept(bool cloudOn) {
    consent = true;
    cloud = cloudOn;
    _sp.setBool('consent', true);
    _sp.setBool('cloud', cloudOn);
    notifyListeners();
  }

  void setCloud(bool v) {
    cloud = v;
    _sp.setBool('cloud', v);
    notifyListeners();
  }

  /// Returns false if the list is already full.
  bool addContact(String name, String phone) {
    if (contacts.length >= kMaxContacts) return false;
    contacts = [...contacts, Contact(name, phone)];
    _saveContacts();
    notifyListeners();
    return true;
  }

  void updateContact(int i, String name, String phone) {
    if (i < 0 || i >= contacts.length) return;
    final copy = [...contacts];
    copy[i] = Contact(name, phone);
    contacts = copy;
    _saveContacts();
    notifyListeners();
  }

  void removeContact(int i) {
    if (i < 0 || i >= contacts.length) return;
    final copy = [...contacts]..removeAt(i);
    contacts = copy;
    _saveContacts();
    notifyListeners();
  }

  /// Old single-contact API, kept so any older code still compiles. Changes the first contact.
  void saveFamily(String name, String phone) {
    if (phone.trim().isEmpty) {
      if (contacts.isNotEmpty) removeContact(0);
    } else if (contacts.isEmpty) {
      addContact(name, phone);
    } else {
      updateContact(0, name, phone);
    }
  }

  void setLast(Verdict v) {
    last = v;
    notifyListeners();
  }
}

final AppState app = AppState();

/// Translate a key into the current language.
String t(String k) => Strings.get(k, app.lang);

// ───────────── Backend (AI second opinion) ─────────────
class Backend {
  static const _codes = ['en', 'ur', 'sd'];
  static String _cut(String s) => s.length > 4000 ? s.substring(0, 4000) : s;

  /// Returns null when the server is unreachable -> the app keeps the on-phone result.
  static Future<Verdict?> analyze(String text, String channel, int lang) async {
    try {
      final res = await http
          .post(
        Uri.parse('$kBaseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': _cut(ScamEngine.redact(text)),
          'channel': channel,
          'lang': _codes[lang.clamp(0, 2).toInt()],
        }),
      )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final level = Level.values.firstWhere(
            (l) => l.name == (j['level'] as String? ?? 'SAFE').toLowerCase(),
        orElse: () => Level.safe,
      );
      final reasons = ((j['reasons'] as List?) ?? []).map((e) => e.toString()).toList();
      final adv = (j['advice'] as String?) ?? '';
      return Verdict(level, ((j['score'] as num?) ?? 0).toInt().clamp(0, 100).toInt(), reasons,
          fromServer: true, advice: adv.isEmpty ? null : adv);
    } catch (_) {
      return null;
    }
  }
}

// ───────────── Speech → text ─────────────
/// Android does NOT let apps record the other side of a call, so the user puts the call
/// on speaker and this listens through the microphone.
class Voice {
  late final stt.SpeechToText _s = stt.SpeechToText(); // created only when first used
  bool _ready = false;
  bool active = false;
  bool _continuous = false;
  bool _restartQueued = false;
  String? _locale;
  List<stt.LocaleName>? _locs;
  void Function(String)? _onPartial;
  void Function(String)? _onFinal;
  void Function()? _onStop;

  /// Returns null if all fine, or a string-key to show ("mic_need" / "lang_unsupported").
  /// After it returns, check [active]: if false, listening could not start.
  Future<String?> start(
      int lang, {
        required bool continuous,
        required void Function(String) onPartial,
        required void Function(String) onFinal,
        required void Function() onStop,
      }) async {
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onStop = onStop;
    _continuous = continuous;
    _restartQueued = false;

    try {
      // Clean slate in case an earlier session is still winding down.
      if (_ready && _s.isListening) {
        await _s.cancel();
      }
      if (!_ready) {
        _ready = await _s.initialize(
          onStatus: _status,
          onError: (e) {
            if (e.permanent) {
              active = false;
              _onStop?.call();
            }
          },
        );
      }
      if (!_ready) return 'mic_need';

      _locs ??= await _s.locales(); // slow call: do it once, not on every start
      final locs = _locs!;
      String? find(String code) {
        for (final l in locs) {
          if (l.localeId.toLowerCase().startsWith(code)) return l.localeId;
        }
        return null;
      }

      String? warn;
      _locale = find(['en', 'ur', 'sd'][lang]);
      if (_locale == null) {
        _locale = find('ur') ?? find('en');
        warn = 'lang_unsupported';
      }
      active = true;
      await _listen();
      return warn;
    } catch (_) {
      active = false;
      return 'mic_need';
    }
  }

  Future<void> _listen() async {
    if (!active || _s.isListening) return;
    try {
      await _s.listen(
        onResult: (r) {
          if (r.finalResult) {
            _onFinal?.call(r.recognizedWords);
          } else {
            _onPartial?.call(r.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: _locale,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      active = false;
      _onStop?.call();
    }
  }

  void _status(String status) {
    if (status == 'done' || status == 'notListening') {
      if (active && _continuous) {
        // The plugin reports both 'notListening' and 'done'; restart only once.
        if (_restartQueued) return;
        _restartQueued = true;
        Future.delayed(const Duration(milliseconds: 400), () {
          _restartQueued = false;
          _listen();
        });
      } else if (active) {
        active = false;
        _onStop?.call();
      }
    }
  }

  Future<void> stop() async {
    active = false;
    try {
      await _s.stop();
    } catch (_) {}
  }
}

// ───────────── Text → speech (reads verdict aloud) ─────────────
class Speaker {
  late final FlutterTts _t = FlutterTts(); // created only when first used (it is slow to start)
  int? _langSet; // the voice language is chosen once per app language

  Future<void> speak(String text, int lang) async {
    try {
      if (_langSet != lang) {
        final cands = lang == 0
            ? ['en-US']
            : lang == 1
            ? ['ur-PK', 'en-US']
            : ['sd-PK', 'sd-IN', 'ur-PK', 'en-US']; // Sindhi voice missing -> Urdu -> English
        for (final c in cands) {
          final ok = await _t.isLanguageAvailable(c);
          if (ok == true || ok == 1) {
            await _t.setLanguage(c);
            break;
          }
        }
        await _t.setSpeechRate(0.45); // slower, easier to follow
        _langSet = lang;
      }
      await _t.stop();
      await _t.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _t.stop();
    } catch (_) {}
  }
}

// ───────────── Helpers ─────────────
Future<void> vibrateAlert() async {
  for (var i = 0; i < 4; i++) {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 350));
  }
}

/// Opens the SMS app with a ready message to one or more numbers. The user only presses send.
Future<bool> tellFamily(Verdict v, String snippet, [List<String>? phones]) async {
  final numbers = (phones ?? app.contacts.map((c) => c.phone).toList()).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (numbers.isEmpty) return false;
  final lvl = Strings.get(v.level == Level.safe ? 'safe' : (v.level == Level.suspicious ? 'suspicious' : 'scam'), app.lang);
  final red = ScamEngine.redact(snippet);
  final body = Strings.get('tell_family_msg', app.lang)
      .replaceFirst('%s', lvl)
      .replaceFirst('%s', red.length > 120 ? red.substring(0, 120) : red);
  final uri = Uri.parse('sms:${numbers.join(',')}?body=${Uri.encodeComponent(body)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}