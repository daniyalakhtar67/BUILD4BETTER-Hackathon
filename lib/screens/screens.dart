import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/engine.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

/// Shows a plain text message at the bottom of the screen.
void _snack(BuildContext c, String text) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)),
    duration: const Duration(seconds: 4),
  ));
}

/// Shows a message from the translation table by its key.
void _toast(BuildContext c, String key) => _snack(c, t(key));

/// Picks a text by the current app language: 0 = English, 1 = Urdu, 2 = Sindhi.
String _l(String en, String ur, String sd) => app.lang == 0 ? en : (app.lang == 1 ? ur : sd);

/// Opens the SMS app. One saved contact -> goes straight there.
/// Several contacts -> asks who to tell (one person, or everybody).
Future<void> _tell(BuildContext c, Verdict v, String text) async {
  final list = app.contacts.where((x) => x.phone.trim().isNotEmpty).toList();
  if (list.isEmpty) {
    _toast(c, 'family_none');
    return;
  }
  if (list.length == 1) {
    await tellFamily(v, text, [list.first.phone]);
    return;
  }
  final picked = await showModalBottomSheet<List<String>>(
    context: c,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_l('Who should we tell?', 'کس کو بتائیں؟', 'ڪنهن کي ٻڌايون؟'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: indigo)),
          const SizedBox(height: 10),
          for (final p in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: safeGreen.withValues(alpha: 0.14),
                child: p.name.trim().isEmpty
                    ? const Icon(Icons.person, color: safeGreen)
                    : Text(String.fromCharCode(p.name.trim().runes.first),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: safeGreen)),
              ),
              title: Text(p.name.trim().isEmpty ? _l('Family member', 'گھر کا فرد', 'گهر جو ميمبر') : p.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              subtitle: Directionality(textDirection: TextDirection.ltr, child: Text(p.phone, style: const TextStyle(fontSize: 16))),
              onTap: () => Navigator.pop(ctx, [p.phone]),
            ),
          const SizedBox(height: 8),
          BigButton(
            text: _l('Tell everyone', 'سب کو بتائیں', 'سڀني کي ٻڌايو'),
            icon: Icons.groups,
            color: crimson,
            onTap: () => Navigator.pop(ctx, list.map((e) => e.phone).toList()),
          ),
        ]),
      ),
    ),
  );
  if (picked != null) await tellFamily(v, text, picked);
}

// ───────────────────────── Shell with bottom navigation ─────────────────────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  // Tabs are built the first time they are opened, not all at once at start-up (that was a big lag).
  final Set<int> _seen = {0};

  void _go(int i) => setState(() {
    tab = i;
    _seen.add(i);
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      builder: (context) => Scaffold(
        // IndexedStack keeps each tab alive, so typed text and results are not lost.
        body: IndexedStack(index: tab, children: [
          HomeScreen(go: _go),
          _seen.contains(1) ? const CheckScreen() : const SizedBox.shrink(),
          _seen.contains(2) ? const ListenScreen() : const SizedBox.shrink(),
          _seen.contains(3) ? const FamilyScreen() : const SizedBox.shrink(),
        ]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, -3))],
          ),
          child: NavigationBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: saffron.withValues(alpha: 0.5),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 78,
            selectedIndex: tab,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              _go(i);
            },
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.home_outlined, size: 30),
                  selectedIcon: const Icon(Icons.home, size: 30, color: indigo),
                  label: t('nav_home')),
              NavigationDestination(
                  icon: const Icon(Icons.message_outlined, size: 30),
                  selectedIcon: const Icon(Icons.message, size: 30, color: indigo),
                  label: t('nav_check')),
              NavigationDestination(
                  icon: const Icon(Icons.mic_none, size: 30),
                  selectedIcon: const Icon(Icons.mic, size: 30, color: indigo),
                  label: t('nav_listen')),
              NavigationDestination(
                  icon: const Icon(Icons.group_outlined, size: 30),
                  selectedIcon: const Icon(Icons.group, size: 30, color: indigo),
                  label: t('nav_family')),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _topBar(String title, {String? sub}) {
  return AjrakHeader(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Language chips get their own row so the title always has the full width.
      const Align(alignment: AlignmentDirectional.centerEnd, child: LangChips()),
      const SizedBox(height: 6),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
      if (sub != null) ...[
        const SizedBox(height: 8),
        Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 19, height: 1.35)),
      ],
      const SizedBox(height: 6),
    ]),
  );
}

// ───────────────────────── Consent (first launch) ─────────────────────────
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  Widget _promise(IconData icon, String text) => WhiteCard(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: crimson, size: 34),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 19, height: 1.45))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      builder: (context) => Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            AjrakHeader(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Align(alignment: AlignmentDirectional.centerEnd, child: LangChips()),
                const SizedBox(height: 8),
                Row(children: [
                  const LogoBadge(size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(t('app'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 10),
                Text(t('tagline'), style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 19)),
                const SizedBox(height: 10),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FadeSlide(
                    child: Text(t('c_title'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: indigo, height: 1.3))),
                const SizedBox(height: 14),
                FadeSlide(index: 1, child: _promise(Icons.lock, t('c_p1'))),
                const SizedBox(height: 14),
                FadeSlide(index: 2, child: _promise(Icons.cloud, t('c_p2'))),
                const SizedBox(height: 14),
                FadeSlide(index: 3, child: _promise(Icons.tune, t('c_p3'))),
                const SizedBox(height: 20),
                BigButton(text: t('c_agree'), icon: Icons.check_circle, color: safeGreen, onTap: () => app.accept(true)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton(
                    onPressed: () => app.accept(false),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: indigo.withValues(alpha: 0.5), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: Text(t('c_local'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: ink)),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Home ─────────────────────────
class HomeScreen extends StatefulWidget {
  final void Function(int) go;
  const HomeScreen({super.key, required this.go});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int tip = Random().nextInt(3);

  Widget _row(IconData icon, Color color, String text, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: color, size: 34),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 19, height: 1.4))),
      ]),
    ),
  );

  String _familyLine() {
    final n = app.contacts.where((c) => c.phone.trim().isNotEmpty).length;
    if (n == 0) return t('family_none');
    if (n == 1) return t('family_is') + (app.familyName.isEmpty ? app.familyPhone : app.familyName);
    return _l('Family helpers: $n people', 'گھر کے مددگار: $n افراد', 'گهر جا مددگار: $n ماڻهو');
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(builder: (context) {
      final last = app.last;
      final famSet = app.hasFamily;
      return SingleChildScrollView(
        child: Column(children: [
          AjrakHeader(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Align(alignment: AlignmentDirectional.centerEnd, child: LangChips()),
              const SizedBox(height: 8),
              Row(children: [
                const LogoBadge(size: 56),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(t('app'),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 12),
              Text(t('tagline'), style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 20, height: 1.4)),
              const SizedBox(height: 18),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              FadeSlide(
                  child: ActionCard(
                      title: t('home_check_title'),
                      sub: t('home_check_sub'),
                      icon: Icons.message,
                      color: crimson,
                      onTap: () => widget.go(1))),
              const SizedBox(height: 16),
              FadeSlide(
                  index: 1,
                  child: ActionCard(
                      title: t('home_listen_title'),
                      sub: t('home_listen_sub'),
                      icon: Icons.mic,
                      color: indigo,
                      onTap: () => widget.go(2))),
              const SizedBox(height: 16),
              FadeSlide(
                index: 2,
                child: WhiteCard(
                  child: Column(children: [
                    _row(app.cloud ? Icons.verified_user : Icons.phone_android, safeGreen, t(app.cloud ? 'cloud_title' : 'c_local'),
                            () => widget.go(3)),
                    const Divider(height: 18),
                    _row(Icons.family_restroom, famSet ? safeGreen : warnAmber, _familyLine(), () => widget.go(3)),
                  ]),
                ),
              ),
              if (last != null) ...[
                const SizedBox(height: 16),
                FadeSlide(
                  index: 3,
                  child: WhiteCard(
                    color: levelColor(last.level).withValues(alpha: 0.12),
                    child: Row(children: [
                      Icon(levelIcon(last.level), color: levelColor(last.level), size: 40),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('last_result'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        Text(t(levelKey(last.level)),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: levelColor(last.level))),
                      ]),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FadeSlide(
                index: 4,
                child: WhiteCard(
                  color: saffron.withValues(alpha: 0.28),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb, color: indigo, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('tip_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: indigo)),
                        const SizedBox(height: 4),
                        Text(t('tip$tip'), style: const TextStyle(fontSize: 20, height: 1.45, color: ink)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      );
    });
  }
}

// ───────────────────────── Check a message ─────────────────────────
class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});
  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final _resultKey = GlobalKey();
  late final _voice = Voice();
  late final _speaker = Speaker();
  Verdict? verdict;
  String checkedText = ''; // the exact text the current result belongs to
  bool busy = false;
  bool serverFailed = false; // cloud was on but the server could not be reached
  bool dictating = false;
  bool starting = false;
  String live = ''; // words being recognised right now while dictating

  @override
  void dispose() {
    _voice.stop();
    _speaker.stop();
    _scroll.dispose();
    _c.dispose();
    super.dispose();
  }

  /// Scrolls down so the result card is on screen as soon as it appears.
  void _showResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignment: 0.02);
      }
    });
  }

  Future<void> _run() async {
    final text = _c.text.trim();
    if (text.isEmpty || busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      serverFailed = false;
      checkedText = text;
    });
    // 1) instant answer from the phone
    final local = ScamEngine.analyze(text);
    setState(() => verdict = local);
    app.setLast(local);
    _showResult();
    // 2) second opinion from the server, if allowed
    if (app.cloud) {
      final s = await Backend.analyze(text, 'message', app.lang);
      if (!mounted) return;
      if (s != null) {
        final m = ScamEngine.merge(local, s);
        setState(() => verdict = m);
        app.setLast(m);
      } else {
        setState(() => serverFailed = true);
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final txt = d?.text?.trim();
    if (txt == null || txt.isEmpty) {
      if (mounted) {
        _snack(context, _l('Nothing to paste. Copy the message first.', 'پیسٹ کرنے کے لیے کچھ نہیں۔ پہلے پیغام کاپی کریں۔',
            'پيسٽ ڪرڻ لاءِ ڪجهه ناهي. پهرين پيغام ڪاپي ڪريو.'));
      }
      return;
    }
    setState(() => _c.text = txt);
  }

  Future<void> _dictate() async {
    if (starting) return;
    if (dictating) {
      await _voice.stop();
      if (mounted) {
        setState(() {
          dictating = false;
          live = '';
        });
      }
      return;
    }
    setState(() => starting = true);
    String? warn;
    try {
      warn = await _voice.start(
        app.lang,
        continuous: false,
        onPartial: (w) {
          if (mounted) setState(() => live = w);
        },
        onFinal: (w) {
          if (!mounted) return;
          setState(() {
            live = '';
            if (w.trim().isNotEmpty) _c.text = ('${_c.text} $w').trim();
          });
        },
        onStop: () {
          if (mounted) {
            setState(() {
              dictating = false;
              live = '';
            });
          }
        },
      );
    } catch (_) {
      warn = 'mic_need';
    }
    if (!mounted) return;
    setState(() => starting = false);
    if (warn == 'mic_need' || !_voice.active) {
      _toast(context, 'mic_need');
      return;
    }
    setState(() => dictating = true);
    if (warn != null) _toast(context, warn);
  }

  String _spoken(Verdict v) {
    final k = v.level == Level.safe ? 'advice_safe' : (v.level == Level.suspicious ? 'advice_suspicious' : 'advice_scam');
    return '${t(levelKey(v.level))}. ${v.advice ?? t(k)}';
  }

  /// Ready-made messages so a person can see how the checker works.
  List<(IconData, String, String)> _examples() => [
    (
    Icons.account_balance,
    _l('Bank scam', 'بینک فراڈ', 'بئنڪ فراڊ'),
    _l(
        'Your bank account is blocked. Send your OTP and ATM PIN now to unblock it.',
        'آپ کا بینک اکاؤنٹ بلاک ہو گیا ہے۔ اکاؤنٹ کھلوانے کے لیے ابھی اپنا او ٹی پی اور اے ٹی ایم پن بھیجیں۔',
        'توهان جو بئنڪ اڪائونٽ بلاڪ ٿي ويو آهي. کولڻ لاءِ هاڻي پنهنجو او ٽي پي ۽ اي ٽي ايم پن موڪليو.')
    ),
    (
    Icons.card_giftcard,
    _l('Prize scam', 'انعام فراڈ', 'انعام فراڊ'),
    _l(
        'Congratulations! You won Rs. 500,000 in the lucky draw. Send Rs. 5,000 fee to claim your prize.',
        'مبارک ہو! آپ نے لکی ڈرا میں پانچ لاکھ روپے جیتے ہیں۔ انعام لینے کے لیے پانچ ہزار روپے فیس بھیجیں۔',
        'مبارڪون! توهان لڪي ڊرا ۾ پنج لک رپيا کٽيا آهن. انعام وٺڻ لاءِ پنج هزار رپيا فيس موڪليو.')
    ),
    (
    Icons.chat_bubble_outline,
    _l('Normal message', 'عام پیغام', 'عام پيغام'),
    _l(
        'Hi, I will reach home by 6 pm. Please keep dinner ready.',
        'السلام علیکم، میں شام چھ بجے تک گھر پہنچ جاؤں گا۔ کھانا تیار رکھیں۔',
        'السلام عليڪم، آئون شام جا ڇهه وڳي گهر پهچندس. ماني تيار رکجو.')
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScope(builder: (context) {
      final hasText = _c.text.trim().isNotEmpty;
      final stale = verdict != null && _c.text.trim() != checkedText;
      return SingleChildScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(children: [
          StepsHeader(
            title: t('check_title'),
            steps: [
              HeaderStep(Icons.content_paste_rounded,
                  _l('Paste, type or speak the message', 'پیغام پیسٹ کریں، لکھیں یا بولیں', 'پيغام پيسٽ ڪريو، لکو يا ڳالهايو')),
              HeaderStep(Icons.security_rounded, _l('Press the Check button', 'چیک کا بٹن دبائیں', 'چيڪ جو بٽڻ دٻايو')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              TextField(
                controller: _c,
                minLines: 5,
                maxLines: 9,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 22, height: 1.4),
                decoration: InputDecoration(
                  hintText: t('check_hint'),
                  hintStyle: const TextStyle(fontSize: 20, color: Colors.black38),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  suffixIcon: hasText
                      ? IconButton(
                    tooltip: _l('Clear', 'صاف کریں', 'صاف ڪريو'),
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => setState(() {
                      _c.clear();
                      verdict = null;
                      serverFailed = false;
                    }),
                  )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: indigo.withValues(alpha: 0.4), width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: indigo, width: 2.5)),
                ),
              ),
              // What the microphone is hearing right now (only while speaking a message).
              if (dictating) ...[
                const SizedBox(height: 10),
                WhiteCard(
                  color: crimson.withValues(alpha: 0.07),
                  child: Row(children: [
                    const Icon(Icons.graphic_eq, color: crimson, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        live.isEmpty ? _l('Listening… speak now', 'سن رہا ہے… اب بولیں', 'ٻڌي رهيو آهي… هاڻي ڳالهايو') : live,
                        style: TextStyle(fontSize: 19, height: 1.4, color: live.isEmpty ? Colors.black45 : ink),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: SoftButton(text: t('paste'), icon: Icons.content_paste, onTap: _paste)),
                const SizedBox(width: 12),
                Expanded(
                    child: SoftButton(
                      text: starting
                          ? _l('Starting…', 'شروع ہو رہا ہے…', 'شروع ٿي رهيو آهي…')
                          : (dictating ? _l('Stop', 'روکیں', 'بند ڪريو') : t('speak_msg')),
                      icon: dictating ? Icons.stop_rounded : Icons.mic,
                      iconColor: dictating ? crimson : indigo,
                      onTap: _dictate,
                    )),
              ]),
              const SizedBox(height: 16),
              // Examples
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(_l('Try an example', 'مثال آزمائیں', 'مثال آزمايو'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black54)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in _examples())
                    ActionChip(
                      avatar: Icon(e.$1, size: 20, color: indigo),
                      label: Text(e.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: indigo.withValues(alpha: 0.3)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _c.text = e.$3);
                      },
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              BigButton(
                text: busy ? t('checking') : t('check_now'),
                icon: Icons.security,
                color: indigo,
                onTap: (!hasText || busy) ? null : _run,
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(minHeight: 6, color: crimson, backgroundColor: Color(0x22000000)),
                ),
              ],
              if (verdict != null) ...[
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: _resultKey,
                  child: Column(children: [
                    if (stale) ...[
                      StatusPill(
                        text: _l('The message changed. Press Check again.', 'پیغام بدل گیا ہے۔ دوبارہ چیک دبائیں۔',
                            'پيغام بدلجي ويو آهي. ٻيهر چيڪ دٻايو.'),
                        icon: Icons.edit_note,
                        color: warnAmber,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (serverFailed && !stale) ...[
                      StatusPill(
                        text: _l('Server not reachable. This result is from your phone.', 'سرور نہیں مل رہا۔ یہ نتیجہ آپ کے فون سے ہے۔',
                            'سرور نه ملي رهيو. هي نتيجو توهان جي فون مان آهي.'),
                        icon: Icons.cloud_off,
                        color: warnAmber,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Opacity(
                      opacity: stale ? 0.45 : 1,
                      child: ResultCard(
                        v: verdict!,
                        onSpeak: () => _speaker.speak(_spoken(verdict!), app.lang),
                        onFamily: () => _tell(context, verdict!, checkedText),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      );
    });
  }
}

// ───────────────────────── Listen to a call ─────────────────────────
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});
  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late final _voice = Voice();
  late final _speaker = Speaker();
  final _scroll = ScrollController();
  bool active = false;
  bool starting = false; // mic is being prepared (permission / engine start-up)
  bool warned = false;
  bool copied = false;
  String transcript = '';
  String partial = '';
  Verdict? verdict;
  int lastCloudLen = 0;
  int callLang = app.lang;
  DateTime _lastPartial = DateTime(2000);

  /// Copies everything heard so far (including the part still being recognised).
  Future<void> _copy() async {
    final text = ('$transcript $partial').trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => copied = false);
    });
  }

  /// Keeps the newest words in view inside the "What we heard" box.
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _voice.stop();
    _speaker.stop();
    _scroll.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _apply(Verdict v) {
    if (!mounted) return;
    final cur = verdict;
    if (cur == null || v.score >= cur.score) {
      setState(() => verdict = v);
      app.setLast(v);
    }
    if (v.level == Level.scam && !warned) {
      warned = true;
      vibrateAlert();
      _speaker.speak(t('alert_call'), app.lang);
    }
  }

  void _evaluate() {
    final snap = transcript;
    final local = ScamEngine.analyze(snap);
    _apply(local);
    if (app.cloud && snap.length - lastCloudLen >= 40) {
      lastCloudLen = snap.length;
      Backend.analyze(snap, 'call', app.lang).then((s) {
        if (s != null) _apply(ScamEngine.merge(local, s));
      });
    }
  }

  Future<void> _toggle() async {
    if (starting) return; // ignore taps while the mic is still starting
    if (active) {
      await _voice.stop();
      WakelockPlus.disable();
      if (mounted) setState(() => active = false);
      return;
    }
    setState(() => starting = true);
    String? warn;
    try {
      warn = await _voice.start(
        callLang,
        continuous: true,
        onPartial: (w) {
          if (!mounted) return;
          // The recogniser sends many updates per second. Redraw at most ~6 times a second.
          final now = DateTime.now();
          if (now.difference(_lastPartial).inMilliseconds < 160) {
            partial = w;
            return;
          }
          _lastPartial = now;
          setState(() => partial = w);
          _scrollDown();
        },
        onFinal: (w) {
          if (!mounted || w.trim().isEmpty) return;
          setState(() {
            partial = '';
            transcript = ('$transcript $w').trim();
          });
          _scrollDown();
          _evaluate();
        },
        onStop: () {
          WakelockPlus.disable();
          if (mounted) setState(() => active = false);
        },
      );
    } catch (_) {
      warn = 'mic_need';
    }
    if (!mounted) return;
    setState(() => starting = false);
    if (warn == 'mic_need' || !_voice.active) {
      _toast(context, 'mic_need');
      return;
    }
    WakelockPlus.enable(); // keep screen awake during the call
    setState(() => active = true);
    if (warn != null) _toast(context, warn);
  }

  void _reset() => setState(() {
    transcript = '';
    partial = '';
    verdict = null;
    warned = false;
    lastCloudLen = 0;
  });

  // ── Call language: three equal boxes ──
  Widget _langBox(int i) {
    const labels = ['EN', 'اردو', 'سنڌي'];
    final sel = callLang == i;
    final locked = active || starting;
    return Opacity(
      opacity: locked && !sel ? 0.45 : 1,
      child: GestureDetector(
        onTap: locked
            ? null
            : () {
          HapticFeedback.selectionClick();
          setState(() => callLang = i);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? saffron : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? saffron : indigo.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Text(labels[i],
              style: TextStyle(fontSize: 21, fontWeight: sel ? FontWeight.w900 : FontWeight.w600, color: sel ? indigoDeep : ink)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(builder: (context) {
      final v = verdict;
      final hasText = transcript.isNotEmpty || partial.isNotEmpty;
      final status = starting
          ? _l('Starting…', 'شروع ہو رہا ہے…', 'شروع ٿي رهيو آهي…')
          : (active
          ? _l('Listening… press to stop', 'سن رہا ہے… روکنے کے لیے دبائیں', 'ٻڌي رهيو آهي… بند ڪرڻ لاءِ دٻايو')
          : t('tap_start'));
      return SingleChildScrollView(
        child: Column(children: [
          StepsHeader(
            title: t('listen_title'),
            steps: [
              HeaderStep(Icons.volume_up_rounded, _l('Put the call on SPEAKER', 'کال کو اسپیکر پر لگائیں', 'ڪال کي اسپيڪر تي رکو')),
              HeaderStep(Icons.mic_rounded, _l('Press the big button', 'بڑا بٹن دبائیں', 'وڏو بٽڻ دٻايو')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              if (v != null && v.level == Level.scam) ...[
                FadeSlide(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: crimson,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: crimson.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Row(children: [
                      const Icon(Icons.phone_disabled, color: Colors.white, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(t('alert_banner'),
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.3)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(t('call_lang'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _langBox(i)),
                ],
              ]),
              const SizedBox(height: 14),
              // Big mic button (shows a spinner while the microphone is starting).
              Stack(alignment: Alignment.center, children: [
                PulseMic(active: active, onTap: _toggle),
                if (starting)
                  const IgnorePointer(
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      child: Center(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(strokeWidth: 5, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ]),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(status,
                    key: ValueKey(status),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: active ? crimson : indigo)),
              ),
              const SizedBox(height: 18),
              if (v != null) ...[
                ResultCard(
                  v: v,
                  onSpeak: () => _speaker.speak(t('alert_call'), app.lang),
                  onFamily: () => _tell(context, v, transcript),
                ),
                const SizedBox(height: 14),
              ],
              WhiteCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(t('heard'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: indigo)),
                    ),
                    // Copy button: always visible, turns green for 2 seconds after copying.
                    TextButton.icon(
                      onPressed: hasText ? _copy : null,
                      style: TextButton.styleFrom(
                        foregroundColor: copied ? safeGreen : indigo,
                        backgroundColor: (copied ? safeGreen : indigo).withValues(alpha: hasText ? 0.10 : 0.0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(copied ? Icons.check_circle : Icons.copy_rounded, size: 24),
                      label: Text(
                        copied ? _l('Copied', 'کاپی ہو گیا', 'ڪاپي ٿي ويو') : _l('Copy', 'کاپی', 'ڪاپي'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                  const Divider(height: 18),
                  if (!hasText)
                    Text(t('heard_empty'), style: const TextStyle(fontSize: 19, height: 1.45, color: Colors.grey))
                  else
                  // Long calls scroll inside the box, newest words stay visible.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: Scrollbar(
                        controller: _scroll,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          child: SizedBox(
                            width: double.infinity,
                            child: SelectableText.rich(TextSpan(children: [
                              TextSpan(text: transcript, style: const TextStyle(fontSize: 21, height: 1.5, color: ink)),
                              TextSpan(
                                  text: transcript.isEmpty ? partial : ' $partial',
                                  style: const TextStyle(fontSize: 21, height: 1.5, color: Colors.grey)),
                            ])),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              if (transcript.isNotEmpty || verdict != null) ...[
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: SoftButton(text: t('clear'), icon: Icons.refresh, onTap: _reset)),
              ],
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      );
    });
  }
}

// ───────────────────────── Family & privacy ─────────────────────────
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  /// true = the add / change form is open.
  late bool formOpen = app.contacts.isEmpty;

  /// Which saved contact is being changed. null = adding a new one.
  int? editing;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _validPhone(String s) => s.replaceAll(RegExp(r'[^0-9]'), '').length >= 7;

  void _openAdd() {
    _name.clear();
    _phone.clear();
    setState(() {
      editing = null;
      formOpen = true;
    });
  }

  void _openEdit(int i) {
    _name.text = app.contacts[i].name;
    _phone.text = app.contacts[i].phone;
    setState(() {
      editing = i;
      formOpen = true;
    });
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    setState(() {
      editing = null;
      formOpen = false;
    });
  }

  void _save() {
    final phone = _phone.text.trim();
    final name = _name.text.trim();
    if (!_validPhone(phone)) {
      _snack(context, _l('Please enter a valid phone number.', 'براہ کرم صحیح فون نمبر لکھیں۔', 'مهرباني ڪري صحيح فون نمبر لکو.'));
      return;
    }
    if (editing != null) {
      app.updateContact(editing!, name, phone);
    } else if (!app.addContact(name, phone)) {
      _snack(context, _l('You can save up to $kMaxContacts people.', 'آپ زیادہ سے زیادہ $kMaxContacts افراد محفوظ کر سکتے ہیں۔',
          'توهان وڌ ۾ وڌ $kMaxContacts ماڻهو محفوظ ڪري سگهو ٿا.'));
      return;
    }
    FocusScope.of(context).unfocus();
    _name.clear();
    _phone.clear();
    setState(() {
      editing = null;
      formOpen = false;
    });
    _snack(context, t('fam_saved'));
  }

  void _remove(int i) {
    app.removeContact(i);
    setState(() {
      if (app.contacts.isEmpty) formOpen = true;
    });
    _snack(context, _l('Contact removed.', 'رابطہ ہٹا دیا گیا۔', 'رابطو هٽايو ويو.'));
  }

  /// One saved family member.
  Widget _contactCard(int i) {
    final c = app.contacts[i];
    final name = c.name.trim();
    final shown = name.isEmpty ? _l('Family member', 'گھر کا فرد', 'گهر جو ميمبر') : name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WhiteCard(
        child: Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: safeGreen.withValues(alpha: 0.14),
            child: name.isEmpty
                ? const Icon(Icons.favorite, color: safeGreen, size: 26)
                : Text(String.fromCharCode(name.runes.first),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: safeGreen)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shown, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink)),
              // Phone numbers always read left-to-right.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(c.phone, style: const TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          IconButton(
            tooltip: _l('Edit', 'تبدیل کریں', 'تبديل ڪريو'),
            icon: const Icon(Icons.edit, color: indigo, size: 26),
            onPressed: () => _openEdit(i),
          ),
          IconButton(
            tooltip: _l('Remove', 'ہٹائیں', 'هٽايو'),
            icon: const Icon(Icons.delete_outline, color: crimson, size: 28),
            onPressed: () => _remove(i),
          ),
        ]),
      ),
    );
  }

  /// The form for adding or changing one family member.
  Widget _form() {
    final isEdit = editing != null;
    return Column(children: [
      SectionTitle(
        text: isEdit
            ? _l('Change family member', 'گھر کے فرد کو تبدیل کریں', 'گهر جو ميمبر تبديل ڪريو')
            : _l('Add a family member', 'گھر کا فرد شامل کریں', 'گهر جو ميمبر شامل ڪريو'),
        icon: Icons.person_add_alt_1,
      ),
      const SizedBox(height: 14),
      TextField(
        key: const ValueKey('fam_name'),
        controller: _name,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 22),
        decoration: fieldDecoration(t('fam_name'), Icons.person),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const ValueKey('fam_phone'),
        controller: _phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        textDirection: TextDirection.ltr,
        onSubmitted: (_) => _save(),
        style: const TextStyle(fontSize: 22),
        decoration: fieldDecoration(t('fam_phone'), Icons.phone, hint: '03XX XXXXXXX'),
      ),
      const SizedBox(height: 16),
      BigButton(text: t('fam_save'), icon: Icons.save, color: indigo, onTap: _save),
      if (app.contacts.isNotEmpty) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SoftButton(text: _l('Cancel', 'منسوخ کریں', 'رد ڪريو'), icon: Icons.close, onTap: _cancel),
        ),
      ],
    ]);
  }

  /// The list of saved people, plus the "add another" button.
  Widget _list() {
    final full = app.contacts.length >= kMaxContacts;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(
        text: _l('My family (${app.contacts.length})', 'میرا خاندان (${app.contacts.length})', 'منهنجو خاندان (${app.contacts.length})'),
        icon: Icons.groups,
        color: safeGreen,
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < app.contacts.length; i++) _contactCard(i),
      const SizedBox(height: 2),
      StatusPill(
        text: _l('Used when you press “Tell family”. With more than one person, you choose who to tell.',
            '"گھر والوں کو بتائیں" دبانے پر استعمال ہوں گے۔ ایک سے زیادہ ہوں تو آپ چنتے ہیں کس کو بتانا ہے۔',
            '"گهر وارن کي ٻڌايو" دٻائڻ تي استعمال ٿيندا. هڪ کان وڌيڪ هجن ته توهان چونڊيو ٿا ڪنهن کي ٻڌائڻو آهي.'),
        icon: Icons.info_outline,
        color: indigo,
      ),
      const SizedBox(height: 14),
      if (full)
        Text(_l('You have saved the maximum of $kMaxContacts people.', 'آپ نے زیادہ سے زیادہ $kMaxContacts افراد محفوظ کر لیے ہیں۔',
            'توهان وڌ ۾ وڌ $kMaxContacts ماڻهو محفوظ ڪري ڇڏيا آهن.'),
            style: const TextStyle(fontSize: 16, color: Colors.black54))
      else
        BigButton(
          text: _l('Add another family member', 'ایک اور فرد شامل کریں', 'هڪ ٻيو ميمبر شامل ڪريو'),
          icon: Icons.person_add,
          color: indigo,
          onTap: _openAdd,
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      builder: (context) {
        final showForm = formOpen || app.contacts.isEmpty;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(children: [
            _topBar(t('fam_title'), sub: t('fam_help')),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (app.contacts.isNotEmpty && !showForm) _list(),
                if (showForm) ...[
                  if (app.contacts.isNotEmpty) ...[
                    for (var i = 0; i < app.contacts.length; i++)
                      if (editing != i) _contactCard(i),
                    const SizedBox(height: 8),
                  ],
                  _form(),
                ],
                const SizedBox(height: 22),
                WhiteCard(
                  child: Row(children: [
                    const Icon(Icons.cloud, color: crimson, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('cloud_title'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.3)),
                        Text(t('cloud_desc'), style: const TextStyle(fontSize: 17, height: 1.4, color: Colors.black54)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Switch(value: app.cloud, activeTrackColor: safeGreen, onChanged: (v) => app.setCloud(v)),
                  ]),
                ),
                const SizedBox(height: 14),
                WhiteCard(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lock, color: crimson, size: 34),
                    const SizedBox(width: 14),
                    Expanded(child: Text(t('c_p1'), style: const TextStyle(fontSize: 18, height: 1.45))),
                  ]),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ]),
        );
      },
    );
  }
}