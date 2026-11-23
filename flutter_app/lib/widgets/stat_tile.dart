import 'package:flutter/material.dart';

import '../theme/talktome_theme.dart';

/// Carte compacte affichant une statistique (icône + valeur + label).
/// Style "Mystic night" : carte violet nuit, icône dans un médaillon or ;
/// la carte mise en avant (série) passe au rouge signet.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const StatTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = TT.accent(context);
    final dark = TT.isDark(context);
    final medal = highlight ? TT.signet : accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: highlight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TT.signet.withOpacity(dark ? 0.32 : 0.16),
                  scheme.surfaceContainerHigh.withOpacity(0.85),
                ],
              )
            : null,
        color: highlight ? null : scheme.surfaceContainerHigh.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? TT.signet.withOpacity(0.55) : accent.withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal.withOpacity(0.16),
              border: Border.all(color: medal.withOpacity(0.5)),
            ),
            child: Icon(icon, color: medal, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: highlight ? (dark ? TT.ink : TT.signetDeep) : scheme.onSurface,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
