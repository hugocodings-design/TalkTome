import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/sherpa_tts_service.dart';
import '../services/voice_model_downloader.dart';

/// Téléchargement des voix IA (modèles sherpa-onnx) depuis l'application :
/// indispensable sur un téléphone où les modèles n'ont pas été copiés à la
/// main (iPhone, nouveau téléphone…).
class VoiceDownloadScreen extends StatefulWidget {
  const VoiceDownloadScreen({super.key});

  @override
  State<VoiceDownloadScreen> createState() => _VoiceDownloadScreenState();
}

class _VoiceDownloadScreenState extends State<VoiceDownloadScreen> {
  // Les modèles réservés à l'ordinateur (Qwen3-TTS) n'ont rien à installer.
  static final _phoneModels =
      SherpaTtsService.models.where((m) => m.runsOnPhone).toList();
  final _downloader = VoiceModelDownloader.instance;
  Map<String, bool> _installed = {};
  bool _fetchingEmotional = false;
  int? _emotionalCount;

  Future<void> _fetchEmotional() async {
    setState(() => _fetchingEmotional = true);
    final n = await SherpaTtsService.instance.fetchEmotionalPocketVoices();
    if (mounted) {
      setState(() {
        _fetchingEmotional = false;
        _emotionalCount = n;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _downloader.states.addListener(_onStatesChanged);
    _refreshInstalled();
  }

  @override
  void dispose() {
    _downloader.states.removeListener(_onStatesChanged);
    super.dispose();
  }

  // Une installation qui se termine (ou échoue) change la liste installée ;
  // la simple progression d'un téléchargement, non.
  Set<String> _busyIds = {};
  void _onStatesChanged() {
    final busy = {
      for (final e in _downloader.states.value.entries)
        if (e.value.phase != VoiceDownloadPhase.failed) e.key,
    };
    if (_busyIds.difference(busy).isNotEmpty) _refreshInstalled();
    _busyIds = busy;
  }

  Future<void> _refreshInstalled() async {
    final result = <String, bool>{};
    for (final m in _phoneModels) {
      result[m.id] = await SherpaTtsService.instance.isModelInstalled(m.id);
    }
    if (mounted) setState(() => _installed = result);
  }

  /// Noms des voix portées par un modèle, avec leur langue.
  String _voicesOf(SherpaModelSpec spec) {
    final byLang = <String, List<String>>{};
    for (final v in SherpaTtsService.voices) {
      if (v.modelId != spec.id) continue;
      byLang.putIfAbsent(v.languageCode, () => []).add(v.displayName);
    }
    return byLang.entries
        .map((e) => '${e.key} : ${e.value.join(', ')}')
        .join('\n');
  }

  Future<void> _installAll() async {
    for (final m in _phoneModels) {
      if (_installed[m.id] == true || _downloader.isBusy(m.id)) continue;
      await _downloader.install(m.id);
      if (!mounted) return;
    }
  }

  Future<void> _confirmDelete(SherpaModelSpec spec) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.voiceDownloads_deleteConfirm(spec.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.voiceDownloads_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.voiceDownloads_delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _downloader.remove(spec.id);
      await _refreshInstalled();
    }
  }

  Widget _trailing(BuildContext context, SherpaModelSpec spec,
      VoiceDownloadState? state) {
    final l10n = AppLocalizations.of(context)!;
    if (state != null && state.phase == VoiceDownloadPhase.downloading) {
      return IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: l10n.voiceDownloads_cancel,
        onPressed: () => _downloader.cancel(spec.id),
      );
    }
    if (state != null && state.phase == VoiceDownloadPhase.extracting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (_installed[spec.id] == true) {
      return IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: l10n.voiceDownloads_delete,
        onPressed: () => _confirmDelete(spec),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download_rounded),
      tooltip: l10n.voiceDownloads_download,
      onPressed: () => _downloader.install(spec.id),
    );
  }

  Widget _status(BuildContext context, SherpaModelSpec spec,
      VoiceDownloadState? state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final size = VoiceModelDownloader.downloadSizeMb[spec.id] ?? 0;
    switch (state?.phase) {
      case VoiceDownloadPhase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.voiceDownloads_downloading(
                (state!.progress * 100).round())),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: state.progress),
          ],
        );
      case VoiceDownloadPhase.extracting:
        return Text(l10n.voiceDownloads_extracting);
      case VoiceDownloadPhase.failed:
        return Text(
          l10n.voiceDownloads_failed,
          style: TextStyle(color: theme.colorScheme.error),
        );
      case null:
        return Text(
          _installed[spec.id] == true
              ? l10n.voiceDownloads_installed
              : l10n.voiceDownloads_sizeMb(size),
          style: TextStyle(
            color: _installed[spec.id] == true ? Colors.green : null,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<Map<String, VoiceDownloadState>>(
      valueListenable: _downloader.states,
      builder: (context, states, _) {
        final missing = _phoneModels
            .where((m) => _installed[m.id] != true && states[m.id] == null)
            .toList();
        final missingMb = missing.fold<int>(
            0, (sum, m) => sum + (VoiceModelDownloader.downloadSizeMb[m.id] ?? 0));
        return Scaffold(
          appBar: AppBar(title: Text(l10n.voiceDownloads_title)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.voiceDownloads_intro),
              ),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: FilledButton.icon(
                    onPressed: _installAll,
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(l10n.voiceDownloads_installAll(missingMb)),
                  ),
                ),
              // Voix Pocket « émotions » : extraits créés par l'ordinateur.
              Card(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.voiceDownloads_emotionalTitle,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(l10n.voiceDownloads_emotionalHint),
                      const SizedBox(height: 8),
                      if (_installed['pocket'] != true)
                        Text(l10n.voiceDownloads_emotionalNeedsPocket,
                            style: TextStyle(color: Theme.of(context).colorScheme.error))
                      else
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _fetchingEmotional ? null : _fetchEmotional,
                              icon: _fetchingEmotional
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.computer_rounded),
                              label: Text(l10n.voiceDownloads_emotionalFetch),
                            ),
                            const SizedBox(width: 12),
                            if (_emotionalCount != null)
                              Expanded(
                                child: Text(l10n.voiceDownloads_emotionalResult(_emotionalCount!)),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              for (final spec in _phoneModels)
                ListTile(
                  isThreeLine: true,
                  title: Text(spec.label),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_voicesOf(spec)),
                      const SizedBox(height: 4),
                      _status(context, spec, states[spec.id]),
                    ],
                  ),
                  trailing: _trailing(context, spec, states[spec.id]),
                  onTap: states[spec.id]?.phase == VoiceDownloadPhase.failed
                      ? () {
                          _downloader.dismissError(spec.id);
                          _downloader.install(spec.id);
                        }
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}
