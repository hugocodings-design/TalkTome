import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../l10n/generated/app_localizations.dart';
import '../main.dart'
    show themeModeNotifier, fontFamilyNotifier, fontSizeNotifier, dictionaryLanguageNotifier,
        translationLanguageNotifier, appLocaleNotifier;
import '../services/sherpa_tts_service.dart';
import '../services/stats_service.dart';
import 'voice_download_screen.dart';
import '../widgets/pc_boost_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Période sélectionnée : 0=Jour, 1=Semaine, 2=Mois, 3=6 mois, 4=Année
  int _selectedPeriod = 1;

  List<String> _periodLabels(AppLocalizations l10n) => [
        l10n.profileScreen_periodDay,
        l10n.profileScreen_periodWeek,
        l10n.profileScreen_periodMonth,
        l10n.profileScreen_periodSixMonths,
        l10n.profileScreen_periodYear,
      ];

  void _setTheme(ThemeMode mode) {
    themeModeNotifier.value = mode;
    final key = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    Hive.box('settings').put('themeMode', key);
  }

  void _setFontSize(double size) {
    fontSizeNotifier.value = size;
    Hive.box('settings').put('fontSize', size);
  }

  void _setFontFamily(String? family) {
    fontFamilyNotifier.value = family;
    Hive.box('settings').put('fontFamily', family);
  }

  void _setDictionaryLanguage(String code) {
    dictionaryLanguageNotifier.value = code;
    Hive.box('settings').put('dictionaryLanguage', code);
  }

  void _setTranslationLanguage(String code) {
    translationLanguageNotifier.value = code;
    Hive.box('settings').put('translationLanguage', code);
  }

  void _setAppLanguage(String? code) {
    appLocaleNotifier.value = code != null ? Locale(code) : null;
    if (code != null) {
      Hive.box('settings').put('appLanguage', code);
    } else {
      Hive.box('settings').delete('appLanguage');
    }
  }

  DateTimeRange _getRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedPeriod) {
      case 0: // Jour
        return DateTimeRange(start: today, end: today);
      case 1: // Semaine
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
      case 2: // Mois
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
      case 3: // 6 mois
        return DateTimeRange(start: DateTime(now.year, now.month - 5, 1), end: today);
      case 4: // Année
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: today);
      default:
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nav_profile),
        centerTitle: true,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('reading_stats').listenable(),
        builder: (context, box, _) {
          final stats = StatsService(box as dynamic);
          final range = _getRange();
          final totalSec = stats.getTotalSeconds(range.start, range.end);
          final weekAvgSec = stats.getWeeklyAverageSeconds();
          final allTimeSec = stats.getAllTimeSeconds();

          // Données du graphique
          final Map<String, int> chartData;
          if (_selectedPeriod <= 1) {
            chartData = stats.getDailyBreakdown(range.start, range.end);
          } else if (_selectedPeriod <= 2) {
            chartData = stats.getWeeklyBreakdown(range.start, range.end);
          } else {
            chartData = stats.getMonthlyBreakdown(range.start, range.end);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sélecteur de période ────────────────────────────────────
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _periodLabels(l10n).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ChoiceChip(
                      label: Text(_periodLabels(l10n)[i]),
                      selected: _selectedPeriod == i,
                      onSelected: (_) => setState(() => _selectedPeriod = i),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Carte principale : temps de la période ──────────────────
                StatTile(
                  icon: Icons.timer_outlined,
                  label: l10n.profileScreen_readingTimeForPeriod(
                      _periodLabels(l10n)[_selectedPeriod].toLowerCase()),
                  value: StatsService.formatSeconds(totalSec),
                  highlight: true,
                ),
                const SizedBox(height: 12),

                // ── Deux cartes secondaires ─────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.bar_chart_rounded,
                        label: l10n.profileScreen_avgPerWeek,
                        value: StatsService.formatSeconds(weekAvgSec),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.auto_stories_outlined,
                        label: l10n.profileScreen_totalReading,
                        value: StatsService.formatSeconds(allTimeSec),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Graphique en barres ─────────────────────────────────────
                if (chartData.isNotEmpty) ...[
                  Text(
                    l10n.profileScreen_breakdown,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  _BarChart(data: chartData, period: _selectedPeriod),
                ],

                // ── Message si aucune donnée ────────────────────────────────
                if (allTimeSec == 0) ...[
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.headphones_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          l10n.profileScreen_noReadingRecorded,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.profileScreen_startReadingHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Paramètres (relocalisés depuis l'onglet Paramètres) ──────
                const SizedBox(height: 16),
                const Divider(),
                _buildSettingsSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<int> _installedVoiceModels() async {
    var count = 0;
    for (final m in SherpaTtsService.models.where((m) => m.runsOnPhone)) {
      if (await SherpaTtsService.instance.isModelInstalled(m.id)) count++;
    }
    return count;
  }

  Widget _buildSettingsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Apparence ────────────────────────────────────────────────────
        SectionHeader(label: l10n.profileScreen_appearance),

        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, themeMode, _) => Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text(l10n.profileScreen_system),
                secondary: const Icon(Icons.brightness_auto_rounded),
                value: ThemeMode.system,
                groupValue: themeMode,
                onChanged: (v) => _setTheme(v!),
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.profileScreen_light),
                secondary: const Icon(Icons.light_mode_rounded),
                value: ThemeMode.light,
                groupValue: themeMode,
                onChanged: (v) => _setTheme(v!),
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.profileScreen_dark),
                secondary: const Icon(Icons.dark_mode_rounded),
                value: ThemeMode.dark,
                groupValue: themeMode,
                onChanged: (v) => _setTheme(v!),
              ),
            ],
          ),
        ),

        const Divider(),

        // ── Texte ────────────────────────────────────────────────────────
        SectionHeader(label: l10n.profileScreen_text),

        ValueListenableBuilder<double>(
          valueListenable: fontSizeNotifier,
          builder: (context, fontSize, _) => Column(
            children: [
              ListTile(
                leading: const Icon(Icons.format_size_rounded),
                title: Text(l10n.profileScreen_textSize),
                trailing: Text(
                  l10n.profileScreen_pt(fontSize.toInt()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 12,
                        max: 28,
                        divisions: 8,
                        onChanged: _setFontSize,
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
            ],
          ),
        ),

        ValueListenableBuilder<String?>(
          valueListenable: fontFamilyNotifier,
          builder: (context, fontFamily, _) => ListTile(
            leading: const Icon(Icons.font_download_rounded),
            title: Text(l10n.profileScreen_font),
            trailing: DropdownButton<String?>(
              value: fontFamily,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.profileScreen_default)),
                const DropdownMenuItem(value: 'Georgia', child: Text('Georgia')),
                DropdownMenuItem(value: 'serif', child: Text(l10n.profileScreen_serif)),
                DropdownMenuItem(value: 'monospace', child: Text(l10n.profileScreen_monospace)),
              ],
              onChanged: _setFontFamily,
            ),
          ),
        ),

        ValueListenableBuilder<String>(
          valueListenable: dictionaryLanguageNotifier,
          builder: (context, dictionaryLanguage, _) => ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(l10n.profileScreen_dictionaryLanguage),
            subtitle: Text(l10n.profileScreen_dictionaryLanguageHint),
            trailing: DropdownButton<String>(
              value: dictionaryLanguage,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'pt', child: Text('Português')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
              onChanged: (value) {
                if (value != null) _setDictionaryLanguage(value);
              },
            ),
          ),
        ),

        ValueListenableBuilder<String>(
          valueListenable: translationLanguageNotifier,
          builder: (context, translationLanguage, _) => ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(l10n.profileScreen_translationLanguage),
            subtitle: Text(l10n.profileScreen_translationLanguageHint),
            trailing: DropdownButton<String>(
              value: translationLanguage,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'pt', child: Text('Português')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
              onChanged: (value) {
                if (value != null) _setTranslationLanguage(value);
              },
            ),
          ),
        ),

        const Divider(),

        // ── Langue de l'application ─────────────────────────────────────
        SectionHeader(label: l10n.profileScreen_languageSection),

        ValueListenableBuilder<Locale?>(
          valueListenable: appLocaleNotifier,
          builder: (context, appLocale, _) => ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.profileScreen_appLanguageLabel),
            trailing: DropdownButton<String?>(
              value: appLocale?.languageCode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.profileScreen_system)),
                const DropdownMenuItem(value: 'fr', child: Text('Français')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: _setAppLanguage,
            ),
          ),
        ),

        const Divider(),

        // ── Voix IA (téléchargement des modèles) ───────────────────────
        SectionHeader(label: l10n.voiceDownloads_section),
        FutureBuilder<int>(
          future: _installedVoiceModels(),
          builder: (context, snap) => ListTile(
            leading: const Icon(Icons.record_voice_over_rounded),
            title: Text(l10n.voiceDownloads_title),
            subtitle: snap.hasData
                ? Text(l10n.voiceDownloads_tileSubtitle(
                    snap.data!,
                    SherpaTtsService.models.where((m) => m.runsOnPhone).length))
                : null,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const VoiceDownloadScreen(),
              ));
              if (mounted) setState(() {});
            },
          ),
        ),

        const Divider(),

        // ── Accélération par l'ordinateur (TalkTome Boost) ─────────────
        SectionHeader(label: l10n.profileScreen_boostSection),
        const PcBoostTile(),
      ],
    );
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final Map<String, int> data;
  final int period;

  const _BarChart({required this.data, required this.period});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    const maxHeight = 100.0;
    const minHeight = 4.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: maxHeight + 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.entries.map((entry) {
            final height = maxVal > 0
                ? (entry.value / maxVal * maxHeight).clamp(minHeight, maxHeight)
                : minHeight;
            final isToday = entry.key ==
                StatsService.dateKey(DateTime.now());
            final barColor = isToday ? color : color.withOpacity(0.5);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Valeur au survol (tooltip)
                    if (entry.value > 0)
                      Tooltip(
                        message: StatsService.formatSeconds(entry.value),
                        child: const SizedBox.shrink(),
                      ),
                    // Barre
                    Container(
                      height: height,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Étiquette de date
                    Text(
                      _shortLabel(context, entry.key),
                      style: TextStyle(
                        fontSize: 9,
                        color: isToday ? color : Colors.grey[500],
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Transforme une clé 'YYYY-MM-DD' en étiquette courte
  String _shortLabel(BuildContext context, String key) {
    final parts = key.split('-');
    if (parts.length < 3) return key;
    final month = int.tryParse(parts[1]) ?? 0;
    final day = int.tryParse(parts[2]) ?? 0;
    // Pour les périodes longues (mois, 6 mois, année), afficher mois abrégé
    // dans la langue de l'app (via intl, cohérent avec AppLocalizations).
    if (period >= 3) {
      final locale = Localizations.localeOf(context).toString();
      return intl.DateFormat.MMM(locale).format(DateTime(2000, month.clamp(1, 12)));
    }
    // Pour semaine/mois, afficher jour/mois
    return '$day/${month.toString().padLeft(2, '0')}';
  }
}
