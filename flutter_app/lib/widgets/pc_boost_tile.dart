import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/pc_boost_service.dart';

/// Réglage « TalkTome Boost » (écran Profil) : état de la connexion à
/// l'ordinateur, et panneau pour activer / saisir l'adresse Home Connections
/// et sa clé (ou les anciennes adresses Boost et leur code).
class PcBoostTile extends StatefulWidget {
  const PcBoostTile({super.key});

  @override
  State<PcBoostTile> createState() => _PcBoostTileState();
}

class _PcBoostTileState extends State<PcBoostTile> {
  final _boost = PcBoostService.instance;

  @override
  void initState() {
    super.initState();
    if (_boost.enabled) _boost.base(force: true);
  }

  String _statusText(AppLocalizations l10n, PcBoostStatus s, String? host) {
    switch (s) {
      case PcBoostStatus.off:
        return l10n.profileScreen_boostOff;
      case PcBoostStatus.searching:
        return l10n.profileScreen_boostSearching;
      case PcBoostStatus.connected:
        return l10n.profileScreen_boostConnected(host ?? '');
      case PcBoostStatus.unreachable:
        return l10n.profileScreen_boostUnreachable;
      case PcBoostStatus.keyRefused:
        return l10n.profileScreen_boostKeyRefused;
      case PcBoostStatus.blocked:
        return l10n.profileScreen_boostBlocked;
    }
  }

  Color _statusColor(BuildContext context, PcBoostStatus s) {
    switch (s) {
      case PcBoostStatus.connected:
        return Colors.green;
      case PcBoostStatus.unreachable:
      case PcBoostStatus.keyRefused:
      case PcBoostStatus.blocked:
        return Colors.orange;
      case PcBoostStatus.searching:
        return Theme.of(context).colorScheme.primary;
      case PcBoostStatus.off:
        return Colors.grey;
    }
  }

  Future<void> _openPanel() async {
    final l10n = AppLocalizations.of(context)!;
    var enabled = _boost.enabled;
    final hosts = TextEditingController(
        text: _boost.hosts.isEmpty
            ? PcBoostService.defaultAddress
            : _boost.hosts.join(', '));
    final code = TextEditingController(text: _boost.code);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> apply() =>
            _boost.configure(enabled: enabled, hosts: hosts.text, code: code.text);
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TalkTome Boost',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.profileScreen_boostEnable),
                value: enabled,
                onChanged: (v) {
                  setSheet(() => enabled = v);
                  apply();
                },
              ),
              TextField(
                controller: hosts,
                decoration: InputDecoration(
                  labelText: l10n.profileScreen_boostHosts,
                  helperText: l10n.profileScreen_boostHostsHint,
                  hintText: PcBoostService.defaultAddress,
                  helperMaxLines: 3,
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => apply(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: l10n.profileScreen_boostCode,
                  helperText: l10n.profileScreen_boostCodeHint,
                ),
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => apply(),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<PcBoostStatus>(
                valueListenable: _boost.status,
                builder: (context, s, _) => Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: _statusColor(context, s)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusText(l10n, s, _boost.activeHost.value))),
                    FilledButton.tonal(
                      onPressed: () async {
                        await apply();
                        await _boost.base(force: true);
                      },
                      child: Text(l10n.profileScreen_boostTest),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
    // Panneau fermé : enregistrer ce qui a été saisi.
    await _boost.configure(enabled: enabled, hosts: hosts.text, code: code.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<PcBoostStatus>(
      valueListenable: _boost.status,
      builder: (context, s, _) => ListTile(
        leading: Icon(Icons.computer_rounded, color: _statusColor(context, s)),
        title: const Text('TalkTome Boost'),
        subtitle: Text(_statusText(l10n, s, _boost.activeHost.value)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _openPanel,
      ),
    );
  }
}
