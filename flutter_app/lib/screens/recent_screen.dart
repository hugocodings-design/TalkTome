import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/ebook.dart';
import '../services/stats_service.dart';
import '../theme/talktome_theme.dart';
import '../widgets/stat_tile.dart';
import '../widgets/tomy.dart';
import 'home_screen.dart' show BookCover;
import 'reader_screen.dart';

class RecentScreen extends StatelessWidget {
  const RecentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const _TalkTomeTitle(),
        centerTitle: true,
        elevation: 0,
      ),
      body: ValueListenableBuilder<Box<Ebook>>(
        valueListenable: Hive.box<Ebook>('ebooks').listenable(),
        builder: (context, box, _) {
          final l10n = AppLocalizations.of(context)!;
          final allBooks = box.values.toList()
            ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

          // Livres en cours : commencés mais pas terminés, du plus
          // récemment ouvert au plus anciennement ouvert
          final inProgress = allBooks
              .where((e) => e.lastReadPosition > 0 && !e.isFinished)
              .toList()
            ..sort((a, b) => (b.lastOpenedAt ?? b.uploadedAt)
                .compareTo(a.lastOpenedAt ?? a.uploadedAt));

          if (allBooks.isEmpty) {
            return TomyEmptyState(
              title: l10n.recentScreen_noBooks,
              message: l10n.recentScreen_addPrompt,
            );
          }

          final stats = StatsService.instance;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todaySec = stats.getTotalSeconds(today, today);
          final weekSec = stats.getTotalSeconds(
              today.subtract(const Duration(days: 6)), today);
          final streak = stats.getCurrentStreakDays();
          final finishedCount = allBooks.where((e) => e.isFinished).length;

          final hour = now.hour;
          final greeting = hour < 5
              ? l10n.tomy_greetNight
              : hour < 12
                  ? l10n.tomy_greetMorning
                  : hour < 18
                      ? l10n.tomy_greetAfternoon
                      : hour < 23
                          ? l10n.tomy_greetEvening
                          : l10n.tomy_greetNight;
          var message = inProgress.isNotEmpty
              ? l10n.tomy_continue(inProgress.first.title)
              : l10n.tomy_idle;
          if (streak >= 2) message = '$message\n${l10n.tomy_streak(streak)}';

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // ── Tomy ────────────────────────────────────────────────────
              GestureDetector(
                onTap: inProgress.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ReaderScreen(ebook: inProgress.first)),
                        ),
                child: TomySays(title: greeting, message: message),
              ),

              // ── En cours ────────────────────────────────────────────────
              if (inProgress.isNotEmpty) ...[
                MysticSectionHeader(label: l10n.recentScreen_inProgress),
                SizedBox(
                  height: 252,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: inProgress.length,
                    itemBuilder: (context, i) =>
                        _InProgressCard(ebook: inProgress[i]),
                  ),
                ),
              ],

              // ── Statistiques ────────────────────────────────────────────
              MysticSectionHeader(label: l10n.recentScreen_statistics),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.wb_twilight_rounded,
                            label: l10n.recentScreen_today,
                            value: StatsService.formatSeconds(todaySec),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            icon: Icons.nights_stay_rounded,
                            label: l10n.recentScreen_thisWeek,
                            value: StatsService.formatSeconds(weekSec),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.local_fire_department_rounded,
                            label: l10n.recentScreen_streak,
                            value: l10n.recentScreen_streakDays(streak),
                            highlight: streak > 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            icon: Icons.auto_stories_rounded,
                            label: l10n.recentScreen_inProgressAndFinished,
                            value: l10n.recentScreen_countRatio(inProgress.length, finishedCount),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

/// Titre "TalkTome" : "Talk" + "Tome" en or, avec une petite étincelle.
class _TalkTomeTitle extends StatelessWidget {
  const _TalkTomeTitle();

  @override
  Widget build(BuildContext context) {
    final accent = TT.accent(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 18, color: accent),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.4),
            children: [
              TextSpan(text: 'Talk', style: TextStyle(color: onSurface)),
              TextSpan(text: 'Tome', style: TextStyle(color: accent)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte horizontale pour un livre en cours
class _InProgressCard extends StatelessWidget {
  final Ebook ebook;
  const _InProgressCard({required this.ebook});

  @override
  Widget build(BuildContext context) {
    final progress = ebook.totalSentences > 0
        ? (ebook.lastReadPosition / ebook.totalSentences).clamp(0.0, 1.0)
        : 0.0;
    final accent = TT.accent(context);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderScreen(ebook: ebook)),
      ),
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withOpacity(0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Couverture ────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 132,
                height: 132,
                child: BookCover(
                  title: ebook.title,
                  isPdf: ebook.fileFormat == 'pdf',
                  coverImagePath: ebook.coverImagePath,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ebook.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            const Spacer(),
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.recentScreen_percentRead((progress * 100).round()),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
