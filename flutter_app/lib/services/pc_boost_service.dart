import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'word_aligner.dart';

/// État de la connexion à l'ordinateur, pour l'écran de réglages.
enum PcBoostStatus { off, searching, connected, unreachable }

/// « TalkTome Boost » : quand l'ordinateur de l'utilisateur est joignable
/// (Wi-Fi de la maison, ou partout via Tailscale), les voix IA et l'IA locale
/// tournent sur lui (carte graphique) au lieu du téléphone — mêmes modèles,
/// même qualité, bien plus vite. Sinon tout se fait sur le téléphone, comme
/// avant : chaque appel ici renvoie null / lève, et l'appelant se rabat sur
/// le moteur local.
class PcBoostService {
  PcBoostService._();
  static final PcBoostService instance = PcBoostService._();

  static const int defaultPort = 47815;

  final ValueNotifier<PcBoostStatus> status = ValueNotifier(PcBoostStatus.off);

  /// Adresse de l'ordinateur actuellement utilisée (pour l'affichage).
  final ValueNotifier<String?> activeHost = ValueNotifier(null);

  bool get enabled => _box.get('boostEnabled', defaultValue: false) as bool;
  List<String> get hosts => ((_box.get('boostHosts', defaultValue: '') as String))
      .split(RegExp(r'[,\s]+'))
      .where((h) => h.isNotEmpty)
      .toList();
  String get code => _box.get('boostCode', defaultValue: '') as String;

  Box get _box => Hive.box('settings');

  // Wi-Fi de la maison : réponse quasi immédiate, on abandonne vite.
  final HttpClient _lanHttp = HttpClient()
    ..connectionTimeout = const Duration(milliseconds: 900)
    ..idleTimeout = const Duration(seconds: 30);

  // Tailscale (LTE, Wi-Fi d'ailleurs) : le premier paquet peut passer par un
  // relais et mettre plusieurs secondes à établir le tunnel — on patiente.
  final HttpClient _remoteHttp = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30);

  static bool _isRemote(String host) {
    final ip = host.split(':').first;
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length == 4 && p.every((e) => e != null)) {
      // 100.64.0.0/10 = adresses Tailscale ; tout ce qui n'est pas privé
      // est aussi traité comme distant.
      if (p[0] == 100 && p[1]! >= 64 && p[1]! < 128) return true;
      if (p[0] == 10 || p[0] == 127) return false;
      if (p[0] == 192 && p[1] == 168) return false;
      if (p[0] == 172 && p[1]! >= 16 && p[1]! < 32) return false;
      return true;
    }
    return true; // nom d'hôte (MagicDNS…) : distant
  }

  HttpClient get _http =>
      _isRemote(activeHost.value ?? '') ? _remoteHttp : _lanHttp;

  String? _base; // http://hôte:port
  DateTime _checkedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String?>? _probing;

  Future<void> configure({
    required bool enabled,
    required String hosts,
    required String code,
  }) async {
    await _box.put('boostEnabled', enabled);
    await _box.put('boostHosts', hosts.trim());
    await _box.put('boostCode', code.trim());
    forget();
    if (enabled) unawaited(base(force: true));
  }

  /// Oublie l'adresse retenue : la prochaine demande recherche l'ordinateur.
  void forget() {
    _base = null;
    activeHost.value = null;
    _checkedAt = DateTime.fromMillisecondsSinceEpoch(0);
    status.value = enabled ? PcBoostStatus.searching : PcBoostStatus.off;
  }

  /// Échec en cours d'utilisation (PC éteint, Wi-Fi perdu…) : on bascule sur
  /// le téléphone, et on ne réessaie qu'après un court délai.
  void markFailed() {
    _base = null;
    activeHost.value = null;
    _checkedAt = DateTime.now();
    if (enabled) status.value = PcBoostStatus.unreachable;
  }

  /// Base URL de l'ordinateur s'il répond, sinon null. Résultat gardé en
  /// mémoire 60 s (succès) ou 20 s (échec) pour ne pas ralentir l'app.
  Future<String?> base({bool force = false}) {
    // Sans adresse saisie, la recherche automatique sur le Wi-Fi suffit.
    if (!enabled || code.isEmpty) {
      status.value = PcBoostStatus.off;
      return Future.value(null);
    }
    final age = DateTime.now().difference(_checkedAt);
    if (!force) {
      if (_base != null && age < const Duration(seconds: 60)) return Future.value(_base);
      if (_base == null && age < const Duration(seconds: 8)) return Future.value(null);
    }
    return _probing ??= _probe().whenComplete(() => _probing = null);
  }

  /// Interroge toutes les adresses en même temps : la première qui répond
  /// gagne (le Wi-Fi de la maison répond presque toujours avant Tailscale).
  /// Si aucune ne répond, cherche l'ordinateur sur le Wi-Fi : son adresse a
  /// pu changer (la box en attribue parfois une autre).
  Future<String?> _probe() async {
    status.value = PcBoostStatus.searching;
    var found = await _firstResponding(hosts);
    if (found == null) {
      final discovered = await _discover();
      if (discovered != null) {
        found = discovered;
        await _rememberHost(discovered.$1);
      }
    }
    if (found == null) {
      markFailed();
      return null;
    }
    final (host, b, llm) = found;
    _base = b;
    _checkedAt = DateTime.now();
    activeHost.value = host;
    _llmReady = llm;
    status.value = PcBoostStatus.connected;
    return b;
  }

  /// (adresse, base URL, IA prête) de la première adresse qui répond.
  Future<(String, String, bool)?> _firstResponding(List<String> list) {
    if (list.isEmpty) return Future.value(null);
    final done = Completer<(String, String, bool)?>();
    var pending = list.length;
    for (final h in list) {
      _probeOne(h).then((ok) {
        if (ok != null && !done.isCompleted) done.complete((h, ok.$1, ok.$2));
        if (--pending == 0 && !done.isCompleted) done.complete(null);
      });
    }
    return done.future;
  }

  static const String _discoverAsk = 'TALKTOME_DISCOVER';
  static const String _discoverReply = 'TALKTOME_BOOST ';

  /// Diffuse une question sur le Wi-Fi ; l'ordinateur répond avec son port.
  /// Android seulement : sur iPhone, la diffusion réseau exige une
  /// autorisation spéciale d'Apple (adresses saisies et Tailscale à la place).
  Future<(String, String, bool)?> _discover() async {
    if (!Platform.isAndroid) return null;
    RawDatagramSocket? sock;
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.broadcastEnabled = true;
      final candidates = <String>{};
      final sub = sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = sock!.receive();
        if (d == null) return;
        final msg = utf8.decode(d.data, allowMalformed: true);
        if (!msg.startsWith(_discoverReply)) return;
        final port = int.tryParse(msg.substring(_discoverReply.length).trim());
        candidates.add('${d.address.address}:${port ?? defaultPort}');
      });
      final ask = utf8.encode(_discoverAsk);
      for (var i = 0; i < 3 && candidates.isEmpty; i++) {
        sock.send(ask, InternetAddress('255.255.255.255'), defaultPort);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await sub.cancel();
      // Le code d'appairage est vérifié comme pour une adresse saisie.
      final found = await _firstResponding(candidates.toList());
      if (found != null) debugPrint('[BOOST] ordinateur retrouvé : ${found.$1}');
      return found;
    } catch (e) {
      debugPrint('[BOOST] recherche sur le Wi-Fi impossible : $e');
      return null;
    } finally {
      sock?.close();
    }
  }

  /// Ajoute l'adresse retrouvée en tête de liste (remplace l'ancienne
  /// adresse locale du même ordinateur, garde Tailscale).
  Future<void> _rememberHost(String host) async {
    final ip = host.split(':').first;
    final kept = hosts.where((h) => _isRemote(h) && h.split(':').first != ip);
    await _box.put('boostHosts', [host, ...kept].join(', '));
  }

  /// (base URL, IA prête) si [h] répond, sinon null.
  Future<(String, bool)?> _probeOne(String h) async {
    final b = h.contains(':') ? 'http://$h' : 'http://$h:$defaultPort';
    final remote = _isRemote(h);
    try {
      final req = await (remote ? _remoteHttp : _lanHttp).getUrl(Uri.parse('$b/health'));
      req.headers.set('X-Boost-Token', code);
      final res = await req
          .close()
          .timeout(Duration(milliseconds: remote ? 8000 : 1500));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 200) {
        final j = jsonDecode(body) as Map;
        if (j['ok'] == true) return (b, j['llm'] == true);
      }
    } catch (e) {
      debugPrint('[BOOST] $h injoignable : $e');
    }
    return null;
  }

  bool _llmReady = false;

  /// L'IA locale tourne-t-elle sur l'ordinateur ?
  Future<bool> llmAvailable() async => await base() != null && _llmReady;

  /// Synthèse d'une phrase sur l'ordinateur. Écrit le WAV dans [outPath] et
  /// renvoie (début de chaque mot, durée), ou null si l'ordinateur n'est pas
  /// joignable — l'appelant synthétise alors sur le téléphone.
  Future<(List<double>, double)?> synthesize({
    required Map<String, Object> voiceSpec,
    required String text,
    required double speed,
    required String outPath,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final b = await base();
    if (b == null) return null;
    try {
      final req = await _http.postUrl(Uri.parse('$b/tts'));
      req.headers
        ..set('X-Boost-Token', code)
        ..contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({...voiceSpec, 'text': text, 'speed': speed})));
      final res = await req.close().timeout(timeout);
      final bytes = await _readAll(res).timeout(timeout);
      if (res.statusCode != 200) {
        // 422 : phrase impossible à synthétiser (ponctuation seule…) — ce
        // n'est pas une panne de l'ordinateur, on le garde.
        if (res.statusCode != 422) {
          debugPrint('[BOOST] tts HTTP ${res.statusCode}');
          markFailed();
        }
        return null;
      }
      await File(outPath).writeAsBytes(bytes, flush: false);
      // Alignement des mots sur l'audio (même algorithme qu'en local), hors
      // du fil principal pour ne pas saccader l'écran.
      return Isolate.run(() {
        final sr = ByteData.sublistView(bytes, 24, 28).getUint32(0, Endian.little);
        final pcm = ByteData.sublistView(bytes, 44);
        final n = pcm.lengthInBytes ~/ 2;
        final samples = Float32List(n);
        for (var i = 0; i < n; i++) {
          samples[i] = pcm.getInt16(i * 2, Endian.little) / 32768.0;
        }
        return (alignWordsToAudio(text, samples, sr), n / sr);
      });
    } catch (e) {
      debugPrint('[BOOST] tts échouée, retour au téléphone : $e');
      markFailed();
      return null;
    }
  }

  /// Extrait de voix Qwen3-TTS de l'ordinateur ([voiceId] = « qwen3-en-f1 »,
  /// [mood] = « sad »…), enregistré dans [outPath] pour les voix Pocket
  /// « émotions ». Faux si l'ordinateur ne répond pas ou n'a pas l'extrait.
  Future<bool> downloadVoiceRef(String voiceId, String mood, String outPath) async {
    final b = await base();
    if (b == null) return false;
    try {
      final uri = Uri.parse('$b/voice_ref').replace(
          queryParameters: {'voice': voiceId, 'mood': mood});
      final req = await _http.getUrl(uri);
      req.headers.set('X-Boost-Token', code);
      final res = await req.close().timeout(const Duration(seconds: 20));
      final bytes = await _readAll(res).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 || bytes.length < 44) return false;
      final f = File(outPath);
      await f.parent.create(recursive: true);
      final tmp = File('$outPath.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(outPath);
      return true;
    } catch (e) {
      debugPrint('[BOOST] extrait $voiceId/$mood indisponible : $e');
      return false;
    }
  }

  /// Génération de texte (Qwen) sur l'ordinateur, morceau par morceau.
  /// Lève une exception si l'ordinateur ne répond pas.
  Stream<String> generate({
    required String prompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final b = await base();
    if (b == null) throw StateError('ordinateur injoignable');
    final req = await _http.postUrl(Uri.parse('$b/llm'));
    req.headers
      ..set('X-Boost-Token', code)
      ..contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode({
      'prompt': prompt,
      'n_predict': maxTokens,
      'temperature': temperature,
      'top_k': 20,
      'top_p': 0.8,
      'min_p': 0.0,
    })));
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      if (res.statusCode == 503) _llmReady = false;
      throw StateError('IA de l\'ordinateur indisponible (${res.statusCode})');
    }
    yield* res.transform(utf8.decoder);
  }

  Future<Uint8List> _readAll(HttpClientResponse res) async {
    final b = BytesBuilder(copy: false);
    await for (final chunk in res) {
      b.add(chunk);
    }
    return b.takeBytes();
  }

  /// Appairage facilité pour le développement : un fichier `boost.json`
  /// déposé dans les données de l'app ({"hosts": "...", "code": "..."}) est
  /// importé au démarrage puis supprimé.
  Future<void> importPairingFileIfAny() async {
    try {
      final support = await getApplicationSupportDirectory();
      final f = File('${support.path}/boost.json');
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      await f.delete();
      await configure(
        enabled: true,
        hosts: j['hosts'] as String? ?? '',
        code: j['code'] as String? ?? '',
      );
      debugPrint('[BOOST] appairage importé : ${j['hosts']}');
    } catch (e) {
      debugPrint('[BOOST] fichier d\'appairage illisible : $e');
    }
  }
}
