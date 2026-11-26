import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/ebook.dart';
import '../models/annotation.dart';
import '../services/tts_service.dart' show Voice;
import '../services/sherpa_tts_service.dart';
import '../services/speech_expander.dart';
import '../services/dictionary_service.dart';
import '../services/translation_service.dart';
import '../services/local_llm_service.dart';
import '../services/pc_boost_service.dart';
import 'voice_download_screen.dart';
import '../main.dart'
    show themeModeNotifier, fontFamilyNotifier, fontSizeNotifier, readerMarginNotifier,
        dictionaryLanguageNotifier, translationLanguageNotifier,
        audioHandler, ensureAudioHandler;
import '../services/stats_service.dart';
import '../data/voice_characters.dart';
import '../widgets/voice_avatar.dart';
import '../widgets/translation_sheet.dart';
import '../widgets/dictionary_sheet.dart';
import 'annotations_screen.dart';
import '../widgets/page_turner.dart';
import '../services/reading_theme.dart';
import '../services/talktome_audio_handler.dart' show TalkTomeAudioHandler;

// ─── Modèles internes ────────────────────────────────────────────────────────

abstract class _BookItem {
  const _BookItem();
}

class _ChapterHeader extends _BookItem {
  final String title;
  final int chapterIndex;
  const _ChapterHeader(this.title, this.chapterIndex);
}

class _SentenceItem extends _BookItem {
  final int globalIndex;
  final int chapterIndex;
  final String text;
  const _SentenceItem(this.globalIndex, this.chapterIndex, this.text);
}

/// Groupe de phrases appartenant au même paragraphe — affiché comme un RichText continu.
class _ParagraphItem extends _BookItem {
  final List<int> sentenceIndices;
  final int chapterIndex;
  /// Index du paragraphe au sein de son chapitre (0, 1, 2...) — identifiant
  /// stable pour une annotation, contrairement aux index de phrase globaux
  /// qui dépendent de l'ensemble du livre.
  final int paragraphIndexInChapter;
  /// Mode livre : un paragraphe coupé entre deux pages est affiché en
  /// morceaux. [charOffset] = position du morceau dans le texte du
  /// paragraphe entier, pour que les surlignages enregistrés restent
  /// alignés quel que soit le mode.
  final int charOffset;
  const _ParagraphItem(
      this.sentenceIndices, this.chapterIndex, this.paragraphIndexInChapter,
      {this.charOffset = 0});
}

/// Contenu de la bulle « mot sous le doigt » (voir _showSelectionBubble) :
/// le mot courant et la position (globale, écran) du doigt à cet instant.
class _SelectionBubbleData {
  final String text;
  final Offset position;
  const _SelectionBubbleData(this.text, this.position);
}

/// Un paragraphe de texte avec un surlignage arrondi dessiné derrière —
/// contrairement à TextSpan.backgroundColor (rectangulaire, et qui fragmente
/// en plusieurs boîtes dès qu'on découpe le texte en plusieurs spans), ceci
/// mesure le texte une fois pour obtenir les rectangles exacts de chaque
/// ligne concernée (via TextPainter.getBoxesForSelection) et les dessine en
/// rectangles arrondis — un par ligne si la phrase surlignée s'étend sur
/// plusieurs lignes, ce qui reste visuellement continu.
class _HighlightedParagraph extends StatelessWidget {
  final TextSpan text;
  final TextRange? sentenceRange;
  final TextRange? wordRange;
  final Color sentenceColor;
  final Color wordColor;
  /// Nombre d'ancres WidgetSpan (une par phrase, voir _sentenceAnchorKeys)
  /// insérées dans [text] — un TextPainter autonome (contrairement à
  /// RichText, qui gère ça tout seul) a besoin qu'on lui indique leur
  /// taille avant layout(), sinon il plante.
  final int placeholderCount;

  /// Sélection tactile en cours (surlignage à sauvegarder) — distincte du
  /// surlignage de lecture.
  final TextRange? selectionRange;
  final Color selectionColor;

  /// Passages déjà sauvegardés dans ce paragraphe (persistants d'une
  /// ouverture à l'autre du livre).
  final List<TextRange> savedHighlights;
  final Color savedHighlightColor;

  /// Résout une position locale en un mot (via TextPainter.getWordBoundary)
  /// et le remonte à l'écran parent — null désactive le geste (paragraphes
  /// qui n'ont pas besoin d'être sélectionnables, aucun cas aujourd'hui mais
  /// garde la porte ouverte).
  /// [wordText] et [globalPosition] alimentent la bulle qui montre le mot
  /// sous le doigt pendant la sélection (voir _ReaderScreenState).
  final void Function(TextRange word, String wordText, Offset globalPosition)?
      onLongPressStart;
  final void Function(TextRange word, String wordText, Offset globalPosition)?
      onLongPressMoveUpdate;
  final VoidCallback? onLongPressEnd;

  /// Poignées de sélection : permettent d'ajuster le début/la fin d'une
  /// sélection déjà posée (même après avoir relâché le doigt initial), sans
  /// devoir tout recommencer si le premier appui a ciblé le mauvais mot.
  final void Function(TextRange word, String wordText, Offset globalPosition)?
      onStartHandleDrag;
  final void Function(TextRange word, String wordText, Offset globalPosition)?
      onEndHandleDrag;
  final VoidCallback? onHandleDragEnd;

  const _HighlightedParagraph({
    required this.text,
    required this.sentenceRange,
    required this.wordRange,
    required this.sentenceColor,
    required this.wordColor,
    required this.placeholderCount,
    this.selectionRange,
    this.selectionColor = Colors.transparent,
    this.savedHighlights = const [],
    this.savedHighlightColor = Colors.transparent,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onStartHandleDrag,
    this.onEndHandleDrag,
    this.onHandleDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Filet de sécurité : un pépin de layout transitoire ici (ex:
          // pendant un changement de taille de police, où plusieurs
          // paragraphes se remesurent en même temps) ne doit jamais faire
          // planter tout l'écran de lecture avec le rectangle d'erreur
          // rouge de Flutter — au pire, le texte s'affiche sans surlignage.
          return _CachedTextPainter(
            text: text,
            placeholderCount: placeholderCount,
            maxWidth: constraints.maxWidth,
            textDirection: Directionality.of(context),
            builder: (painter) {
          if (painter == null) {
            return RichText(text: text, textAlign: TextAlign.justify);
          }
          try {
            final paragraphSize = Size(constraints.maxWidth, painter.height);

            // Traduit une position locale en un mot, en la bornant d'abord
            // aux limites du paragraphe : un glissement qui sort visuellement
            // du paragraphe (au-dessus/en dessous) reste ainsi accroché à son
            // premier/dernier mot plutôt que de tenter de sélectionner un
            // autre paragraphe (portée v1 : sélection à un seul paragraphe).
            TextRange wordAt(Offset local) {
              final clamped = Offset(
                local.dx.clamp(0.0, paragraphSize.width),
                local.dy.clamp(0.0, paragraphSize.height),
              );
              final pos = painter.getPositionForOffset(clamped);
              return painter.getWordBoundary(pos);
            }

            // Convertit une position ÉCRAN (d.globalPosition) en coordonnées
            // du paragraphe, via son propre RenderBox — stable, contrairement
            // à la position d'une poignée qui, elle, se déplace à chaque
            // mise à jour de la sélection (voir _SelectionHandle : utiliser
            // sa position locale à elle créait un effet d'emballement, le
            // point de référence bougeant sous le doigt à chaque frame).
            Offset globalToLocal(Offset global) {
              final box = context.findRenderObject();
              if (box is RenderBox && box.attached) {
                return box.globalToLocal(global);
              }
              return global;
            }

            Widget content = CustomPaint(
              size: paragraphSize,
              painter: (sentenceRange != null ||
                      wordRange != null ||
                      selectionRange != null ||
                      savedHighlights.isNotEmpty)
                  ? _HighlightPainter(
                      textPainter: painter,
                      sentenceRange: sentenceRange,
                      wordRange: wordRange,
                      sentenceColor: sentenceColor,
                      wordColor: wordColor,
                      selectionRange: selectionRange,
                      selectionColor: selectionColor,
                      savedHighlights: savedHighlights,
                      savedHighlightColor: savedHighlightColor,
                    )
                  : null,
              child: RichText(text: text, textAlign: TextAlign.justify),
            );

            String textOf(TextRange r) {
              final s = r.start.clamp(0, painter.plainText.length);
              final e = r.end.clamp(0, painter.plainText.length);
              return s < e ? painter.plainText.substring(s, e) : '';
            }

            if (onLongPressStart != null) {
              content = GestureDetector(
                onLongPressStart: (d) {
                  final word = wordAt(d.localPosition);
                  onLongPressStart!(word, textOf(word), d.globalPosition);
                },
                onLongPressMoveUpdate: (d) {
                  final word = wordAt(d.localPosition);
                  onLongPressMoveUpdate?.call(word, textOf(word), d.globalPosition);
                },
                onLongPressEnd: (_) => onLongPressEnd?.call(),
                child: content,
              );
            }

            // Le Stack lui-même est TOUJOURS présent, que des poignées
            // soient affichées ou non — seuls ses enfants EN PLUS du contenu
            // principal varient. Le faire apparaître seulement une fois
            // `selectionRange` non nul (comme avant) changeait l'ANCÊTRE du
            // contenu principal exactement au moment du tout premier mot
            // sélectionné, en plein geste — cassant le suivi (seul le
            // premier mot restait sélectionné, un second essai fonctionnait
            // toujours puisque le Stack était alors déjà en place dès le
            // début). Même leçon que pour le ValueListenableBuilder de
            // sélection plus haut, appliquée cette fois à ce Stack.
            final handles = <Widget>[];
            final sel = selectionRange;
            if (sel != null && (onStartHandleDrag != null || onEndHandleDrag != null)) {
              final s = sel.start.clamp(0, painter.plainText.length);
              final e = sel.end.clamp(0, painter.plainText.length);
              if (s < e) {
                final boxes = painter.getBoxesForSelection(
                  TextSelection(baseOffset: s, extentOffset: e),
                );
                if (boxes.isNotEmpty) {
                  final startBox = boxes.first;
                  final endBox = boxes.last;
                  if (onStartHandleDrag != null) {
                    handles.add(_SelectionHandle(
                      position: Offset(startBox.left, (startBox.top + startBox.bottom) / 2),
                      wordAt: wordAt,
                      textOf: textOf,
                      globalToLocal: globalToLocal,
                      onDrag: onStartHandleDrag!,
                      onDragEnd: onHandleDragEnd,
                    ));
                  }
                  if (onEndHandleDrag != null) {
                    handles.add(_SelectionHandle(
                      position: Offset(endBox.right, (endBox.top + endBox.bottom) / 2),
                      wordAt: wordAt,
                      textOf: textOf,
                      globalToLocal: globalToLocal,
                      onDrag: onEndHandleDrag!,
                      onDragEnd: onHandleDragEnd,
                    ));
                  }
                }
              }
            }

            return Stack(clipBehavior: Clip.none, children: [content, ...handles]);
          } catch (_) {
            return RichText(text: text, textAlign: TextAlign.justify);
          }
            },
          );
        },
      ),
    );
  }
}

/// Garde UN TextPainter par paragraphe et ne le refait que si le texte, la
/// largeur ou le nombre d'ancres change. Avant, un TextPainter neuf était
/// créé (et jamais libéré) à chaque tick de mot (~25 ms) pendant la lecture :
/// des milliers de mises en page natives s'accumulaient en mémoire.
class _CachedTextPainter extends StatefulWidget {
  final InlineSpan text;
  final int placeholderCount;
  final double maxWidth;
  final TextDirection textDirection;
  final Widget Function(TextPainter? painter) builder;

  const _CachedTextPainter({
    required this.text,
    required this.placeholderCount,
    required this.maxWidth,
    required this.textDirection,
    required this.builder,
  });

  @override
  State<_CachedTextPainter> createState() => _CachedTextPainterState();
}

class _CachedTextPainterState extends State<_CachedTextPainter> {
  TextPainter? _painter;
  InlineSpan? _laidOutText;
  double? _laidOutWidth;
  int? _laidOutPlaceholders;
  TextDirection? _laidOutDirection;

  TextPainter _painterFor() {
    final cached = _painter;
    if (cached != null &&
        identical(_laidOutText, widget.text) &&
        _laidOutWidth == widget.maxWidth &&
        _laidOutPlaceholders == widget.placeholderCount &&
        _laidOutDirection == widget.textDirection) {
      return cached;
    }

    final painter = TextPainter(
      text: widget.text,
      textAlign: TextAlign.justify,
      textDirection: widget.textDirection,
    );
    if (widget.placeholderCount > 0) {
      painter.setPlaceholderDimensions(List.generate(
        widget.placeholderCount,
        (_) => const PlaceholderDimensions(
          size: Size.zero,
          alignment: PlaceholderAlignment.middle,
        ),
      ));
    }
    try {
      painter.layout(maxWidth: widget.maxWidth);
    } catch (_) {
      painter.dispose();
      rethrow;
    }

    cached?.dispose();
    _painter = painter;
    _laidOutText = widget.text;
    _laidOutWidth = widget.maxWidth;
    _laidOutPlaceholders = widget.placeholderCount;
    _laidOutDirection = widget.textDirection;
    return painter;
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextPainter? painter;
    try {
      painter = _painterFor();
    } catch (_) {
      painter = null;
    }
    return widget.builder(painter);
  }
}

/// Poignée ronde avec une petite queue, ancrée sur le bord d'un mot de
/// sélection (façon éditeurs de texte natifs) — se glisse pour ajuster le
/// début ou la fin d'une sélection déjà posée.
class _SelectionHandle extends StatelessWidget {
  /// Point d'ancrage (milieu vertical du glyphe visé), en coordonnées du
  /// paragraphe — pas de l'écran.
  final Offset position;
  final TextRange Function(Offset paragraphLocal) wordAt;
  final String Function(TextRange word) textOf;
  /// Convertit une position ÉCRAN en coordonnées du paragraphe — voir le
  /// commentaire sur globalToLocal dans _HighlightedParagraph.build().
  final Offset Function(Offset global) globalToLocal;
  final void Function(TextRange word, String wordText, Offset globalPosition) onDrag;
  final VoidCallback? onDragEnd;

  static const double _visualRadius = 7;
  static const double _hitRadius = 22;

  const _SelectionHandle({
    required this.position,
    required this.wordAt,
    required this.textOf,
    required this.globalToLocal,
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Positioned(
      left: position.dx - _hitRadius,
      top: position.dy - _hitRadius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          // d.globalPosition, PAS d.localPosition : cette poignée se déplace
          // à chaque mise à jour de la sélection (elle suit le mot visé), donc
          // une position relative à elle-même créerait un effet d'emballement
          // — le point de référence bouge sous le doigt à chaque frame.
          final paragraphLocal = globalToLocal(d.globalPosition);
          final word = wordAt(paragraphLocal);
          onDrag(word, textOf(word), d.globalPosition);
        },
        onPanEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: _hitRadius * 2,
          height: _hitRadius * 2,
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _visualRadius * 2,
                  height: _visualRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
                Container(width: 2, height: 10, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final TextPainter textPainter;
  final TextRange? sentenceRange;
  final TextRange? wordRange;
  final Color sentenceColor;
  final Color wordColor;
  final TextRange? selectionRange;
  final Color selectionColor;
  final List<TextRange> savedHighlights;
  final Color savedHighlightColor;

  _HighlightPainter({
    required this.textPainter,
    required this.sentenceRange,
    required this.wordRange,
    required this.sentenceColor,
    required this.wordColor,
    this.selectionRange,
    this.selectionColor = Colors.transparent,
    this.savedHighlights = const [],
    this.savedHighlightColor = Colors.transparent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Les surlignages sauvegardés se peignent en premier (dessous) : la
    // lecture en cours doit rester visible par-dessus si elle chevauche un
    // passage déjà surligné.
    for (final range in savedHighlights) {
      _paintRange(canvas, range, savedHighlightColor, 3);
    }
    if (sentenceRange != null) {
      _paintRange(canvas, sentenceRange!, sentenceColor, 3);
    }
    if (wordRange != null) {
      _paintRange(canvas, wordRange!, wordColor, 3);
    }
    if (selectionRange != null) {
      _paintRange(canvas, selectionRange!, selectionColor, 3);
    }
  }

  void _paintRange(Canvas canvas, TextRange range, Color color, double padH) {
    // Pendant un défilement rapide, le texte peut changer entre le moment où
    // sentenceRange/wordRange sont calculés et celui où ce painter dessine —
    // un TextSelection avec des offsets hors des bornes du texte actuel fait
    // planter getBoxesForSelection (et Flutter affiche alors un gros
    // rectangle d'erreur rouge à la place du paragraphe). On borne toujours
    // aux limites réelles du texte, peu importe la langue ou le contenu.
    final textLength = textPainter.plainText.length;
    final start = range.start.clamp(0, textLength);
    final end = range.end.clamp(0, textLength);
    if (start >= end) return;

    final boxes = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    final paint = Paint()..color = color;
    for (final box in boxes) {
      final rect = Rect.fromLTRB(box.left - padH, box.top, box.right + padH, box.bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.sentenceRange != sentenceRange ||
        oldDelegate.wordRange != wordRange ||
        oldDelegate.selectionRange != selectionRange ||
        !listEquals(oldDelegate.savedHighlights, savedHighlights) ||
        oldDelegate.textPainter.text != textPainter.text;
  }
}

// ─── Écran lecteur ───────────────────────────────────────────────────────────

class ReaderScreen extends StatefulWidget {
  final Ebook ebook;
  /// Si fourni, l'écran défile jusqu'à ce passage sauvegardé à l'ouverture
  /// (venant de l'onglet Annotations).
  final Annotation? jumpToAnnotation;
  /// Alternative à jumpToAnnotation pour sauter à un passage identifié par
  /// chapitre + paragraphe seulement (venant de l'onglet Traductions, qui
  /// n'a pas d'offsets de caractères comme une Annotation) — voir
  /// _findGlobalIndexForChapterParagraph.
  final String? jumpToChapterId;
  final int? jumpToParagraphIndexInChapter;
  const ReaderScreen({
    Key? key,
    required this.ebook,
    this.jumpToAnnotation,
    this.jumpToChapterId,
    this.jumpToParagraphIndexInChapter,
  }) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {

  // Abonnement à l'état de lecture du handler (playbackState)
  StreamSubscription<dynamic>? _playerStateSub;

  late Box<Ebook> ebookBox;

  final List<_BookItem> _displayItems = [];
  final List<_SentenceItem> _sentences = [];
  final Map<int, int> _chapterDisplayIndex = {};

  // ── Sélection tactile (surlignage à sauvegarder) ─────────────────────────
  // Identité du _ParagraphItem en cours de sélection (v1 : un seul
  // paragraphe à la fois — voir _HighlightedParagraph.wordAt).
  _ParagraphItem? _selectingParagraph;
  TextRange? _selectionAnchorWord;
  // Photo du texte aplati du paragraphe au moment du début de la sélection —
  // sert à extraire l'extrait sélectionné sans reconstruire tout le span.
  String? _selectionParagraphPlainText;
  // Index de phrase mis en attente si la lecture avance pendant une
  // sélection en cours — voir _onHandlerIndexChanged/_applyPendingIndexIfAny.
  int? _pendingIndexAfterSelection;
  final ValueNotifier<TextRange?> _selectionRangeNotifier = ValueNotifier(null);
  // Bulle flottante qui montre le mot sous le doigt pendant la sélection —
  // voir _showSelectionBubble.
  final ValueNotifier<_SelectionBubbleData?> _selectionBubbleNotifier = ValueNotifier(null);
  OverlayEntry? _selectionBubbleEntry;
  late Box<Annotation> _annotationBox;
  // ebook.id -> chapterId -> paragraphIndexInChapter -> annotations, pour un
  // lookup bon marché depuis _buildParagraphWidget (appelé à chaque frame
  // pour le paragraphe en cours de lecture).
  Map<String, Map<int, List<Annotation>>> _savedHighlightsByChapter = {};

  // Une GlobalKey par phrase pour ensureVisible précis
  final Map<int, GlobalKey> _sentenceKeys = {};

  /// Une GlobalKey par phrase, ancrée à l'endroit EXACT où elle commence
  /// dans le texte (via un WidgetSpan invisible inséré juste avant, voir
  /// _buildParagraphWidget). _sentenceKeys pointe vers le paragraphe entier
  /// (partagé par toutes ses phrases) — insuffisant pour un défilement
  /// automatique qui doit réagir à chaque phrase : deux phrases voisines du
  /// même paragraphe ont sinon la même position, donc aucun mouvement n'est
  /// détecté avant de changer de paragraphe (où le saut devient trop grand).
  final Map<int, GlobalKey> _sentenceAnchorKeys = {};

  // Défilement précis vers un index arbitraire (voir pubspec) — remplace
  // notre ancienne estimation "à la main" (taille de ligne/police devinée),
  // jamais fiable sur de longues distances : ce package mesure réellement
  // les items au fur et à mesure plutôt que de deviner leur hauteur.
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  int _currentGlobalIndex = 0;


  /// Position verticale cible pour la phrase en cours de lecture, en
  /// fraction de la hauteur visible (0.0 = haut, 0.5 = centre). La phrase
  /// est ré-ancrée à cette position à chaque changement, façon téléprompteur,
  /// plutôt que de simplement "rester visible" où qu'elle atterrisse.
  static const double _scrollAnchorFraction = 1 / 3;
  bool _showReturnButton = false;
  bool _autoScrollEnabled = true;  // défilement automatique pendant la lecture
  bool _readerVisible = true;       // afficher/masquer le texte pendant la lecture

  // ── Mode livre (pages à tourner, façon liseuse) ─────────────────────────
  bool _bookMode = Hive.box('settings').get('bookMode', defaultValue: false) as bool;
  PageTurnStyle _pageTurnStyle =
      Hive.box('settings').get('pageTurn', defaultValue: 'curl') == 'slide'
          ? PageTurnStyle.slide
          : PageTurnStyle.curl;
  final GlobalKey<PageTurnerState> _pageTurnerKey = GlobalKey();
  List<List<_BookItem>> _pages = const [];
  List<int> _pageOfSentence = const [];
  String _paginationKey = '';
  String _paginatingKey = '';
  int _paginationGen = 0;
  int _bookPage = 0;
  /// Phrase à garder à l'écran quand les pages sont recalculées (taille du
  /// texte, police, rotation) : la première de la page affichée.
  int _bookAnchorSentence = -1;

  // ── Traduction en direct (bulle au-dessus du texte pendant la lecture) ──
  // Volontairement NON persisté (comme _autoScrollEnabled) : se réactive à
  // chaque ouverture du lecteur plutôt que de rester allumé silencieusement
  // et de continuer à consommer le quota DeepL sans que l'utilisateur ne
  // s'en rende compte.
  bool _translationModeEnabled = false;
  final TranslationService _translationService = TranslationService();
  String? _currentTranslation;
  // Empêche d'afficher la traduction d'une phrase déjà dépassée si la
  // réponse DeepL d'un appel périmé arrive après celle d'un appel plus
  // récent (l'utilisateur peut avancer plus vite que la latence réseau).
  int _translationRequestId = 0;
  // Position glissée par l'utilisateur (appui prolongé + déplacement sur la
  // bulle) — null tant qu'il n'a pas encore bougé la bulle, auquel cas elle
  // reste à sa position par défaut sous l'AppBar. Non persisté (comme
  // _autoScrollEnabled) : repart de la position par défaut à chaque
  // ouverture du livre plutôt que de se souvenir d'un emplacement qui
  // pourrait ne plus convenir (taille de police différente, etc.).
  Offset? _translationBubbleOffset;
  // Position de la bulle au tout début du geste de déplacement en cours —
  // voir _buildTranslationBubble pour pourquoi c'est nécessaire.
  Offset? _dragStartBubbleOffset;

  /// Mode « lire la traduction » : la voix lit la traduction (dans la bulle,
  /// avec suivi des mots) au lieu du texte du livre, qui continue d'être
  /// suivi en parallèle. Voix choisie mémorisée par langue de traduction.
  bool _readTranslationAloud = false;

  List<Voice> availableVoices = [];
  String selectedVoice = "sherpa-kokoro-af_heart";
  String selectedLanguageCode = "en-US";

  bool _isSynthesizing = false;
  // Faux tant que la session audio n'a pas confirmé l'état réel (voir
  // _startHandlerSession) : rien ne joue encore au tout premier affichage,
  // le bouton doit donc montrer ▶, jamais ⏸.
  bool _wantsToPlay = false;

  // Chronomètre pour tracker le temps de lecture réel
  final Stopwatch _readingStopwatch = Stopwatch();

  double _playbackSpeed = 1.0;
  static const double _speedMin = 0.5;
  static const double _speedMax = 2.0;
  static const double _speedStep = 0.05;

  /// Valeur affichée pendant qu'on glisse la barre de navigation façon
  /// YouTube — null quand on ne glisse pas (on suit alors _currentGlobalIndex).
  double? _scrubberPreviewIndex;


  @override
  void initState() {
    super.initState();
    _buildFlatList();
    _annotationBox = Hive.box<Annotation>('annotations');
    _loadSavedHighlights();
    // Restaurer la position de lecture sauvegardée
    final saved = widget.ebook.lastReadPosition;
    if (saved > 0 && saved < _sentences.length) {
      _currentGlobalIndex = saved;
    }
    // Un saut vers une annotation ou une traduction prime sur la position
    // sauvegardée.
    final jump = widget.jumpToAnnotation;
    final jumpChapterId = widget.jumpToChapterId;
    final jumpParagraphIndex = widget.jumpToParagraphIndexInChapter;
    final int? jumpIndex;
    if (jump != null) {
      jumpIndex = _findGlobalIndexForChapterParagraph(jump.chapterId, jump.paragraphIndexInChapter);
    } else if (jumpChapterId != null && jumpParagraphIndex != null) {
      jumpIndex = _findGlobalIndexForChapterParagraph(jumpChapterId, jumpParagraphIndex);
    } else {
      jumpIndex = null;
    }
    if (jumpIndex != null) {
      _currentGlobalIndex = jumpIndex;
    }
    _configureAudioSession();
    _startHandlerSession(); // async, intentionnellement non-awaited
    _initializeScreen();
    fontSizeNotifier.addListener(_onFontChanged);
    fontFamilyNotifier.addListener(_onFontChanged);
    if (jumpIndex != null) {
      final targetIndex = jumpIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSentence(targetIndex, animate: false);
      });
    }
  }

  /// Regroupe les annotations sauvegardées de ce livre par chapitre +
  /// paragraphe, pour un lookup bon marché dans _buildParagraphWidget.
  void _loadSavedHighlights() {
    final map = <String, Map<int, List<Annotation>>>{};
    for (final a in _annotationBox.values) {
      if (a.ebookId != widget.ebook.id) continue;
      map
          .putIfAbsent(a.chapterId, () => {})
          .putIfAbsent(a.paragraphIndexInChapter, () => [])
          .add(a);
    }
    _savedHighlightsByChapter = map;
  }

  /// Retrouve la première phrase du paragraphe visé (identifié par chapitre
  /// + index de paragraphe — utilisé aussi bien par les annotations que les
  /// traductions enregistrées), pour pouvoir y défiler — null si le livre a
  /// changé de structure entre-temps (ré-import) et que le paragraphe
  /// n'existe plus tel quel.
  int? _findGlobalIndexForChapterParagraph(String chapterId, int paragraphIndexInChapter) {
    for (final item in _displayItems) {
      if (item is _ParagraphItem &&
          item.chapterIndex < widget.ebook.chapters.length &&
          widget.ebook.chapters[item.chapterIndex].id == chapterId &&
          item.paragraphIndexInChapter == paragraphIndexInChapter &&
          item.sentenceIndices.isNotEmpty) {
        return item.sentenceIndices.first;
      }
    }
    return null;
  }

  // ── Sélection tactile (surlignage) ────────────────────────────────────────

  void _onSelectionStart(_ParagraphItem para, TextRange word, String plainText,
      String wordText, Offset globalPosition) {
    setState(() {
      _selectingParagraph = para;
      _selectionAnchorWord = word;
      _selectionParagraphPlainText = plainText;
    });
    _selectionRangeNotifier.value = word;
    _showSelectionBubble(wordText, globalPosition);
    // Une sélection annonce souvent « Définir » ou « Traduire » : on charge
    // l'IA locale dès maintenant (sans effet si déjà chargée ou absente),
    // la réponse arrive ainsi bien plus vite après le tap.
    unawaited(LocalLlmService.instance.warmUp());
  }

  /// La phrase du paragraphe sélectionné qui contient la sélection — donnée
  /// au dictionnaire pour qu'il explique le sens du mot À CET ENDROIT.
  String? _selectionContextSentence() {
    final text = _selectionParagraphPlainText;
    final range = _selectionRangeNotifier.value;
    if (text == null || range == null || !range.isValid) return null;
    var start = range.start;
    while (start > 0 && !'.!?…\n'.contains(text[start - 1])) {
      start--;
    }
    var end = range.end;
    while (end < text.length && !'.!?…\n'.contains(text[end])) {
      end++;
    }
    if (end < text.length) end++; // garder la ponctuation finale
    final sentence = text.substring(start, end).trim();
    return sentence.length > 400 ? sentence.substring(0, 400) : sentence;
  }

  void _onSelectionUpdate(
      _ParagraphItem para, TextRange word, String wordText, Offset globalPosition) {
    if (!identical(_selectingParagraph, para)) return;
    final anchor = _selectionAnchorWord;
    if (anchor == null) return;
    final start = anchor.start < word.start ? anchor.start : word.start;
    final end = anchor.end > word.end ? anchor.end : word.end;
    _selectionRangeNotifier.value = TextRange(start: start, end: end);
    _showSelectionBubble(wordText, globalPosition);
  }

  void _onSelectionEnd(_ParagraphItem para) {
    // L'état (_selectingParagraph, _selectionRangeNotifier) est déjà à jour
    // à ce stade — la barre de confirmation les observe directement, rien à
    // faire de plus ici. La bulle, elle, ne sert que pendant le glissement.
    _hideSelectionBubble();
  }

  // ── Poignées d'ajustement (début/fin de la sélection déjà posée) ─────────
  // Permettent de corriger une sélection après avoir relâché le doigt
  // initial, sans devoir tout recommencer si le premier appui ciblait le
  // mauvais mot.

  void _onAdjustSelectionStart(
      _ParagraphItem para, TextRange word, String wordText, Offset globalPosition) {
    if (!identical(_selectingParagraph, para)) return;
    final current = _selectionRangeNotifier.value;
    if (current == null) return;
    // Le nouveau début ne dépasse jamais la fin actuelle de la sélection.
    final newStart = word.start < current.end ? word.start : current.end;
    _selectionRangeNotifier.value = TextRange(start: newStart, end: current.end);
    _showSelectionBubble(wordText, globalPosition);
  }

  void _onAdjustSelectionEnd(
      _ParagraphItem para, TextRange word, String wordText, Offset globalPosition) {
    if (!identical(_selectingParagraph, para)) return;
    final current = _selectionRangeNotifier.value;
    if (current == null) return;
    // La nouvelle fin ne remonte jamais avant le début actuel de la sélection.
    final newEnd = word.end > current.start ? word.end : current.start;
    _selectionRangeNotifier.value = TextRange(start: current.start, end: newEnd);
    _showSelectionBubble(wordText, globalPosition);
  }

  void _onHandleDragEnd() {
    _hideSelectionBubble();
  }

  void _cancelSelection() {
    setState(() {
      _selectingParagraph = null;
      _selectionAnchorWord = null;
      _selectionParagraphPlainText = null;
    });
    _selectionRangeNotifier.value = null;
    _hideSelectionBubble();
    _applyPendingIndexIfAny();
  }

  // ── Bulle « mot sous le doigt » ───────────────────────────────────────────
  // Le doigt masque exactement le mot qu'on essaie de viser pendant la
  // sélection — cette bulle, positionnée au-dessus du point de contact,
  // montre ce mot en clair pour compenser.

  static const _magnifierSize = Size(180, 76);
  static const _magnifierGapAboveFinger = 74.0;

  void _ensureSelectionBubbleOverlay() {
    if (_selectionBubbleEntry != null) return;
    _selectionBubbleEntry = OverlayEntry(
      builder: (context) => ValueListenableBuilder<_SelectionBubbleData?>(
        valueListenable: _selectionBubbleNotifier,
        builder: (context, data, _) {
          if (data == null) return const SizedBox.shrink();
          final screenSize = MediaQuery.of(context).size;

          var left = data.position.dx - _magnifierSize.width / 2;
          left = left.clamp(8.0, screenSize.width - _magnifierSize.width - 8);

          var top = data.position.dy - _magnifierGapAboveFinger - _magnifierSize.height;
          // Pas assez de place au-dessus (doigt proche du haut de l'écran) :
          // affiche la loupe sous le doigt plutôt qu'au-dessus.
          if (top < 40) {
            top = data.position.dy + 40;
          }

          // RawMagnifier échantillonne au point (position propre + décalage) —
          // la loupe étant décalée du doigt, il faut lui indiquer où viser.
          final magnifierCenter = Offset(
            left + _magnifierSize.width / 2,
            top + _magnifierSize.height / 2,
          );

          return Positioned(
            left: left,
            top: top,
            child: IgnorePointer(
              child: RawMagnifier(
                size: _magnifierSize,
                magnificationScale: 2.0,
                focalPointOffset: data.position - magnifierCenter,
                decoration: MagnifierDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.amber, width: 2),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    Overlay.of(context).insert(_selectionBubbleEntry!);
  }

  void _showSelectionBubble(String text, Offset globalPosition) {
    if (text.isEmpty) return;
    _ensureSelectionBubbleOverlay();
    _selectionBubbleNotifier.value = _SelectionBubbleData(text, globalPosition);
  }

  void _hideSelectionBubble() {
    _selectionBubbleNotifier.value = null;
  }

  /// Texte actuellement sélectionné (mot OU phrase entière, sans limite de
  /// longueur) pour le bouton "Traduire" — contrairement à "Définir",
  /// traduire une phrase entière a un sens, donc pas de restriction au mot
  /// unique ici. Même nettoyage que _saveSelectionAsAnnotation (retrait du
  /// caractère objet U+FFFC des ancres de phrase invisibles, espaces
  /// multiples).
  String? _selectedTextOrNull() {
    final range = _selectionRangeNotifier.value;
    final plainText = _selectionParagraphPlainText;
    if (range == null || plainText == null) return null;

    final start = range.start.clamp(0, plainText.length);
    final end = range.end.clamp(0, plainText.length);
    if (start >= end) return null;

    final text = plainText
        .substring(start, end)
        .replaceAll('￼', '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  /// Retourne le mot actuellement sélectionné si la sélection ne contient
  /// qu'UN seul mot, sinon null — le bouton "Définir" n'a de sens que dans
  /// ce cas (chercher une définition pour plusieurs mots à la fois n'aurait
  /// pas de réponse cohérente).
  ///
  /// Réutilise EXACTEMENT le même nettoyage que _saveSelectionAsAnnotation
  /// (retrait du caractère objet U+FFFC des ancres de phrase invisibles,
  /// espaces multiples) : sans ce retrait, un mot situé juste après une
  /// ancre de début de phrase contiendrait un caractère invisible qui le
  /// ferait compter comme "deux mots" et le bouton n'apparaîtrait jamais.
  String? _singleSelectedWordOrNull() {
    final range = _selectionRangeNotifier.value;
    final plainText = _selectionParagraphPlainText;
    if (range == null || plainText == null) return null;

    final start = range.start.clamp(0, plainText.length);
    final end = range.end.clamp(0, plainText.length);
    if (start >= end) return null;

    var word = plainText
        .substring(start, end)
        .replaceAll('￼', '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    // Ponctuation de BORD uniquement (« subtle, » → « subtle ») — on garde
    // les apostrophes et traits d'union internes pour ne pas casser "don't"
    // ou "well-known".
    word = word.replaceAll(RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true), '');

    if (word.isEmpty || word.length > 40) return null;
    if (RegExp(r'\s').hasMatch(word)) return null; // deux mots ou plus
    return word;
  }

  /// Ouvre la fiche dictionnaire pour [word]. Annule d'abord la sélection en
  /// cours : tant qu'une sélection vit, l'avancement de la lecture reste en
  /// attente (voir _pendingIndexAfterSelection / _onHandlerIndexChanged) —
  /// la laisser active derrière une feuille modale ouverte plusieurs
  /// secondes gèlerait le défilement automatique pendant tout ce temps.
  Future<void> _openDictionaryForWord(String word) async {
    final para = _selectingParagraph;
    final chapterId =
        para == null ? '' : widget.ebook.chapters[para.chapterIndex].id;
    final contextSentence = _selectionContextSentence();
    _cancelSelection();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // nécessaire pour dépasser 50% de hauteur
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: DictionarySheet(
          word: word,
          sourceLang: DictionaryService.langFromVoiceName(widget.ebook.selectedVoiceName),
          ebookId: widget.ebook.id,
          chapterId: chapterId,
          contextSentence: contextSentence,
        ),
      ),
    );
  }

  /// Ouvre la fiche de traduction pour [text] (mot ou phrase entière) — même
  /// logique que _openDictionaryForWord (annule la sélection d'abord pour ne
  /// pas geler le défilement automatique derrière la feuille modale).
  Future<void> _openTranslationForText(String text) async {
    final para = _selectingParagraph;
    final chapterId =
        para == null ? '' : widget.ebook.chapters[para.chapterIndex].id;
    _cancelSelection();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: TranslationSheet(
          text: text,
          sourceLang: DictionaryService.langFromVoiceName(widget.ebook.selectedVoiceName),
          ebookId: widget.ebook.id,
          chapterId: chapterId,
          paragraphIndexInChapter: para?.paragraphIndexInChapter ?? -1,
        ),
      ),
    );
  }

  Future<void> _saveSelectionAsAnnotation() async {
    final para = _selectingParagraph;
    final range = _selectionRangeNotifier.value;
    final plainText = _selectionParagraphPlainText;
    if (para == null || range == null || plainText == null) {
      _cancelSelection();
      return;
    }

    final start = range.start.clamp(0, plainText.length);
    final end = range.end.clamp(0, plainText.length);
    if (start >= end) {
      _cancelSelection();
      return;
    }
    // Le caractère objet (U+FFFC) des ancres invisibles (voir
    // _buildParagraphWidget) peut se retrouver n'importe où dans la
    // sélection, pas seulement en bord — une sélection sur plusieurs
    // phrases du même paragraphe traverse une ancre en plein milieu. Sans
    // ce retrait, ce caractère s'affiche comme un petit carré "obj" dans
    // le texte sauvegardé.
    final selectedText = plainText
        .substring(start, end)
        .replaceAll('￼', '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    if (selectedText.isEmpty) {
      _cancelSelection();
      return;
    }

    final chapter = widget.ebook.chapters[para.chapterIndex];
    final annotation = Annotation(
      id: 'anno_${DateTime.now().microsecondsSinceEpoch}',
      ebookId: widget.ebook.id,
      chapterId: chapter.id,
      paragraphIndexInChapter: para.paragraphIndexInChapter,
      startOffset: start + para.charOffset,
      endOffset: end + para.charOffset,
      selectedText: selectedText,
      createdAt: DateTime.now(),
    );
    await _annotationBox.put(annotation.id, annotation);
    if (!mounted) return;

    setState(() {
      _savedHighlightsByChapter
          .putIfAbsent(chapter.id, () => {})
          .putIfAbsent(para.paragraphIndexInChapter, () => [])
          .add(annotation);
      _selectingParagraph = null;
      _selectionAnchorWord = null;
      _selectionParagraphPlainText = null;
    });
    _selectionRangeNotifier.value = null;
    _applyPendingIndexIfAny();
  }

  /// Bulle de traduction en direct. Position par défaut FIXE juste sous
  /// l'AppBar plutôt que de suivre pixel par pixel la position réelle de la
  /// phrase en cours à l'écran — le défilement automatique la maintient de
  /// toute façon déjà autour du même tiers supérieur de l'écran (voir
  /// _scrollAnchorFraction), donc une position par défaut fixe reste
  /// visuellement juste "au-dessus du texte lu" sans réintroduire de calcul
  /// de position dépendant du scroll, une source récurrente de bugs sur cet
  /// écran. L'utilisateur peut néanmoins la faire glisser (appui prolongé +
  /// déplacement) à l'endroit de son choix — voir _translationBubbleOffset.
  Widget _buildTranslationBubble(BuildContext context) {
    final h = audioHandler;
    final readingAloud = h != null && h.isReadingTranslation;
    final fallback = _currentTranslation;
    if (!readingAloud && fallback == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    // Toute la largeur de l'écran (marge de 12 px) : le texte tient sur moins
    // de lignes, la bulle est moins haute. Seule la position verticale se
    // déplace (appui prolongé + glisser).
    final top = (_translationBubbleOffset?.dy ?? 8).clamp(0.0, screenSize.height - 160);
    final baseStyle = TextStyle(
      color: scheme.onPrimaryContainer,
      fontSize: 16,
      height: 1.4,
    );

    Widget content;
    if (readingAloud) {
      // Lecture de la traduction : la bulle affiche EXACTEMENT ce que la voix
      // prononce, avec le mot en cours surligné.
      content = ValueListenableBuilder<String?>(
        valueListenable: h.spokenTextNotifier,
        builder: (context, spoken, _) {
          final text = spoken ?? fallback ?? '';
          return ValueListenableBuilder<int>(
            valueListenable: h.spokenWordIndexNotifier,
            builder: (context, active, _) {
              final words = text.split(RegExp(r'(?<=\s)'));
              var wordIdx = -1;
              return Text.rich(
                TextSpan(style: baseStyle, children: [
                  for (final w in words)
                    TextSpan(
                      text: w,
                      style: (w.trim().isNotEmpty && ++wordIdx == active)
                          ? TextStyle(
                              fontWeight: FontWeight.w700,
                              backgroundColor: scheme.primary.withValues(alpha: 0.22),
                            )
                          : null,
                    ),
                ]),
              );
            },
          );
        },
      );
    } else {
      content = Text(fallback!, style: baseStyle);
    }

    return Positioned(
      left: 12,
      right: 12,
      top: top,
      child: GestureDetector(
        // offsetFromOrigin part du point de départ de l'appui prolongé : on
        // repart donc d'une position de référence fixée au début du geste.
        onLongPressStart: (_) => _dragStartBubbleOffset = Offset(0, top),
        onLongPressMoveUpdate: (details) {
          final start = _dragStartBubbleOffset;
          if (start == null) return;
          setState(() {
            _translationBubbleOffset = Offset(0, start.dy + details.offsetFromOrigin.dy);
          });
        },
        child: Material(
          color: scheme.primaryContainer,
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: content,
          ),
        ),
      ),
    );
  }

  /// Bulle flottante Annuler/Surligner, positionnée dans le même `Stack` que
  /// le texte plutôt que comme enfant du `Column` du corps de l'écran — pour
  /// ne jamais faire varier la hauteur de la zone de lecture. La faire
  /// apparaître comme un enfant de Column (comme avant) rétrécissait la
  /// zone défilable pile au moment où la sélection démarre, décalant le
  /// texte sous le doigt au tout premier appui : la loupe visait alors une
  /// géométrie déjà périmée. Un deuxième appui n'était jamais affecté
  /// puisque la bulle était déjà affichée avant que le geste ne commence.
  /// Pas d'aperçu du texte sélectionné ici non plus, pour la même raison :
  /// un texte de longueur variable changerait la taille de cette bulle.
  Widget _buildSelectionBar() {
    return ValueListenableBuilder<TextRange?>(
      valueListenable: _selectionRangeNotifier,
      builder: (context, range, _) {
        if (_selectingParagraph == null || range == null) {
          return const SizedBox.shrink();
        }
        // Le bouton « Retour au texte en cours » occupe déjà la même zone
        // en bas de l'écran (bottom: 12, centré) — s'il est visible en même
        // temps qu'une sélection, la bulle Annuler/Surligner se place plus
        // haut pour ne jamais le chevaucher, plutôt que de tomber pile
        // dessus (elle serait techniquement dessus au tri en Z, mais toutes
        // deux resteraient visibles seulement partiellement).
        final singleWord = _singleSelectedWordOrNull();
        final selectedText = _selectedTextOrNull();
        return Positioned(
          bottom: _showReturnButton ? 76 : 20,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              elevation: 6,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                // Largeur bornée : avec 3 boutons possibles (Annuler /
                // Définir / Surligner), un petit écran pourrait sinon
                // déborder horizontalement. La hauteur, elle, reste fixe
                // quel que soit le nombre de boutons visibles — voir le
                // commentaire de la fonction : c'est ça qui compte pour ne
                // jamais décaler la zone de lecture.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                  ),
                  // Boutons compacts + réduction automatique si la place
                  // manque encore (4 boutons sur un écran étroit) : jamais
                  // de débordement à droite.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TextButtonTheme(
                    data: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    child: FilledButtonTheme(
                    data: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _cancelSelection,
                        child: Text(AppLocalizations.of(context)!.common_cancel),
                      ),
                      const SizedBox(width: 4),
                      if (singleWord != null) ...[
                        TextButton.icon(
                          onPressed: () => _openDictionaryForWord(singleWord),
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          // Libellé FIXE (jamais le mot sélectionné) : un
                          // texte de longueur variable changerait la taille
                          // de cette bulle — voir le commentaire de la
                          // fonction, c'est l'interdiction documentée qui a
                          // motivé le fait que la bulle n'affiche déjà pas
                          // d'aperçu du texte sélectionné.
                          label: Text(AppLocalizations.of(context)!.reader_define),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (selectedText != null) ...[
                        TextButton.icon(
                          onPressed: () => _openTranslationForText(selectedText),
                          icon: const Icon(Icons.g_translate_rounded, size: 18),
                          // Libellé FIXE, même raison que "Définir" ci-dessus.
                          label: Text(AppLocalizations.of(context)!.reader_translate),
                        ),
                        const SizedBox(width: 4),
                      ],
                      FilledButton.icon(
                        onPressed: _saveSelectionAsAnnotation,
                        icon: const Icon(Icons.border_color_rounded, size: 18),
                        label: Text(AppLocalizations.of(context)!.reader_highlight),
                      ),
                    ],
                  ),
                  ),
                  ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Un changement de taille/police reconstruit entièrement la liste (voir
  /// la clé sur ScrollablePositionedList) — elle se repositionne alors par
  /// défaut au HAUT du paragraphe courant plutôt qu'à l'ancrage habituel à
  /// 1/3. On refait donc le réglage fin juste après, une fois la nouvelle
  /// mise en page mesurée.
  void _onFontChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSentence(_currentGlobalIndex, animate: false);
    });
  }

  // ─── Initialisation du handler audio ─────────────────────────────────────

  Future<void> _startHandlerSession() async {
    await ensureAudioHandler();
    if (!mounted) return;
    final h = audioHandler;
    if (h == null) return;

    // Démarrer la session dans le handler (foreground service)
    h.startSession(
      sentences: _sentences.map((s) => s.text).toList(),
      bookTitle: widget.ebook.title,
      ebookId: widget.ebook.id,
      voiceName: selectedVoice,
      languageCode: selectedLanguageCode,
      speed: _playbackSpeed,
      startIndex: _currentGlobalIndex,
    );

    // Écouter l'index courant pour scroll automatique et surlignage
    h.currentIndexNotifier.addListener(_onHandlerIndexChanged);

    // Écouter l'état de synthèse pour le spinner du bouton play
    h.isSynthesizingNotifier.addListener(_onHandlerSynthesizingChanged);

    // Écouter l'intention play/pause — source de vérité pour le bouton,
    // fiable même pendant un chargement (contrairement à _isPlaying)
    h.shouldBePlayingNotifier.addListener(_onHandlerWantsToPlayChanged);
    // setState nécessaire : ce point est atteint après un `await`, donc le
    // premier build a déjà eu lieu avec la valeur par défaut du champ
    // (`true` → icône pause). Sans ça, le bouton affichait ⏸ à l'ouverture
    // même une fois la valeur corrigée, jusqu'à ce qu'une interaction
    // ultérieure force un rebuild.
    if (mounted) {
      setState(() => _wantsToPlay = h.shouldBePlayingNotifier.value);
    }

    // Écouter l'état lecture/pause pour le chronomètre de temps de lecture
    _playerStateSub = h.playbackState.listen((state) {
      if (!mounted) return;
      if (state.playing && !_readingStopwatch.isRunning) {
        _readingStopwatch.start();
      } else if (!state.playing && _readingStopwatch.isRunning) {
        _readingStopwatch.stop();
        _flushReadingTime();
      }
    });
  }

  void _onHandlerIndexChanged() {
    final idx = audioHandler?.currentIndexNotifier.value ?? 0;
    if (!mounted) return;

    // Pendant une sélection tactile en cours, on gèle l'indicateur de
    // lecture entièrement (pas seulement le gras) : chaque changement de
    // phrase reconstruit tous les paragraphes visibles via ce setState, y
    // compris celui qu'on est en train de sélectionner. Après quelques
    // reconstructions d'affilée (constaté : ~3 phrases), le geste de
    // glissement finissait par se figer — trop de reconstructions
    // successives de son propre GestureDetector, même sans changement de
    // mise en page. On mémorise juste l'index visé, rattrapé d'un coup à
    // la fin du geste : le surlignage doit rester fiable en toutes
    // circonstances, quitte à perdre le suivi visuel en direct ailleurs
    // pendant les quelques secondes d'une sélection.
    if (_selectingParagraph != null) {
      _pendingIndexAfterSelection = idx;
      return;
    }

    setState(() => _currentGlobalIndex = idx);
    _saveProgress();
    if (_autoScrollEnabled && !_showReturnButton) {
      _autoScrollToCurrentSentence(idx);
    }
    if (_translationModeEnabled) _loadTranslationForCurrentSentence();
  }

  /// Rattrape en un coup le changement de phrase en cours qui a été gelé
  /// pendant une sélection tactile (voir _onHandlerIndexChanged).
  void _applyPendingIndexIfAny() {
    final pending = _pendingIndexAfterSelection;
    if (pending == null) return;
    _pendingIndexAfterSelection = null;
    setState(() => _currentGlobalIndex = pending);
    _saveProgress();
    if (_autoScrollEnabled && !_showReturnButton) {
      _autoScrollToCurrentSentence(pending);
    }
    if (_translationModeEnabled) _loadTranslationForCurrentSentence();
  }

  /// Traduit la phrase actuellement lue et met à jour la bulle en haut de
  /// l'écran (voir _translationModeEnabled). Aucune erreur affichée en cas
  /// d'échec réseau/quota : contrairement à une recherche de dictionnaire
  /// (geste volontaire de l'utilisateur), c'est une fonctionnalité ambiante
  /// qui se déclenche à chaque phrase — un message d'erreur toutes les
  /// quelques secondes serait bien plus gênant qu'une bulle qui manque une
  /// mise à jour de temps en temps.
  Future<void> _loadTranslationForCurrentSentence() async {
    final index = _currentGlobalIndex;
    if (index < 0 || index >= _sentences.length) return;
    final requestId = ++_translationRequestId;
    try {
      // ML Kit (traducteur neuronal sur le téléphone) : instantané, il suit
      // le rythme de la lecture sans rien coûter.
      final translated = await _translationService.translateLive(
        text: _sentences[index].text,
        sourceLang: DictionaryService.langFromVoiceName(widget.ebook.selectedVoiceName),
        targetLang: translationLanguageNotifier.value,
      );
      if (!mounted || requestId != _translationRequestId) return;
      setState(() => _currentTranslation = translated);
      // Phrase suivante traduite d'avance : elle s'affichera sans délai.
      if (index + 1 < _sentences.length) {
        unawaited(_translationService
            .translateLive(
              text: _sentences[index + 1].text,
              sourceLang: DictionaryService.langFromVoiceName(widget.ebook.selectedVoiceName),
              targetLang: translationLanguageNotifier.value,
            )
            .then<void>((_) {}, onError: (_) {}));
      }
    } catch (_) {
      // Bulle laissée telle quelle (garde la dernière traduction valide)
      // plutôt que d'afficher une erreur pour une seule phrase manquée.
    }
  }

  void _setTranslationModeEnabled(bool enabled) {
    setState(() {
      _translationModeEnabled = enabled;
      if (!_translationModeEnabled) _currentTranslation = null;
    });
    if (_translationModeEnabled) {
      final src = DictionaryService.langFromVoiceName(widget.ebook.selectedVoiceName);
      // Télécharge les modèles ML Kit (une fois) puis traduit la phrase.
      TranslationService.prepareLive(src, translationLanguageNotifier.value).then((_) {
        _loadTranslationForCurrentSentence();
        _applyTranslationReading();
      });
    } else {
      _applyTranslationReading();
    }
  }

  /// Voix installées pour la langue de traduction [lang] (« fr », « pt »…).
  List<Voice> _voicesForLanguage(String lang) => availableVoices
      .where((v) => v.languageCode.toLowerCase().startsWith('${lang.toLowerCase()}-'))
      .toList();

  /// Voix choisie pour lire la traduction dans [lang] (mémorisée), sinon la
  /// première voix installée de cette langue.
  String? _translationVoiceFor(String lang) {
    final voices = _voicesForLanguage(lang);
    if (voices.isEmpty) return null;
    final saved = Hive.box('settings').get('translationVoice_$lang') as String?;
    return voices.any((v) => v.name == saved) ? saved : voices.first.name;
  }

  /// Synchronise le lecteur audio avec le mode « lire la traduction ».
  void _applyTranslationReading() {
    final h = audioHandler;
    if (h == null) return;
    final target = translationLanguageNotifier.value;
    final src = DictionaryService.langFromVoiceName(widget.ebook.selectedVoiceName);
    final voice = _translationVoiceFor(target);
    final active = _translationModeEnabled && _readTranslationAloud && voice != null && src != target;
    if (!active) {
      if (h.isReadingTranslation) h.setTranslationReading();
      return;
    }
    h.setTranslationReading(
      voiceName: voice,
      textProvider: (i) => _translationService.translateLive(
        text: _sentences[i].text,
        sourceLang: src,
        targetLang: target,
      ),
    );
  }

  /// Panneau ouvert en tapant sur l'icône de dictionnaire de l'AppBar : ne
  /// gère QUE la langue des définitions (voir DictionarySheet) — pas
  /// d'interrupteur marche/arrêt ici, le dictionnaire n'a pas de "mode", il
  /// se déclenche ponctuellement via le bouton "Définir" de la sélection.
  /// Réglage volontairement séparé de la langue de traduction en direct
  /// (translationLanguageNotifier) : rien n'oblige à vouloir les deux dans
  /// la même langue.
  void _showDictionaryLanguagePanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final bottomPad = MediaQuery.of(context).padding.bottom + 24;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(l10n.annotations_tabDictionary,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: dictionaryLanguageNotifier,
                builder: (context, lang, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.reader_definitionsLanguage),
                  trailing: DropdownButton<String>(
                    value: lang,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'pt', child: Text('Português')),
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      dictionaryLanguageNotifier.value = value;
                      Hive.box('settings').put('dictionaryLanguage', value);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Panneau ouvert en tapant sur l'icône de traduction de l'AppBar :
  /// interrupteur marche/arrêt ET choix de la langue au même endroit,
  /// plutôt qu'un simple bouton bascule qui obligerait à aller dans Profil
  /// pour changer de langue. Même structure que _showAppearancePanel
  /// (StatefulBuilder + showModalBottomSheet) pour rester cohérent avec le
  /// reste du lecteur.
  void _showTranslationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          final bottomPad = MediaQuery.of(context).padding.bottom + 24;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(l10n.reader_liveTranslationTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.reader_enabled),
                  subtitle: Text(l10n.reader_translationBubbleHint),
                  value: _translationModeEnabled,
                  onChanged: (value) {
                    _setTranslationModeEnabled(value);
                    setModalState(() {});
                  },
                ),
                ValueListenableBuilder<String>(
                  valueListenable: translationLanguageNotifier,
                  builder: (context, lang, _) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language_rounded),
                    title: Text(l10n.profileScreen_translationLanguage),
                    trailing: DropdownButton<String>(
                      value: lang,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'pt', child: Text('Português')),
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        translationLanguageNotifier.value = value;
                        Hive.box('settings').put('translationLanguage', value);
                        // Redemande la traduction de la phrase courante tout
                        // de suite dans la nouvelle langue, plutôt que
                        // d'attendre le prochain changement de phrase.
                        if (_translationModeEnabled) {
                          final src = DictionaryService.langFromVoiceName(
                              widget.ebook.selectedVoiceName);
                          TranslationService.prepareLive(src, value).then((_) {
                            _loadTranslationForCurrentSentence();
                            _applyTranslationReading();
                          });
                        }
                        setModalState(() {});
                      },
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.record_voice_over_rounded),
                  title: Text(l10n.reader_readTranslationAloud),
                  subtitle: Text(l10n.reader_readTranslationAloudHint),
                  value: _readTranslationAloud,
                  onChanged: !_translationModeEnabled
                      ? null
                      : (value) {
                          setState(() => _readTranslationAloud = value);
                          setModalState(() {});
                          _applyTranslationReading();
                        },
                ),
                if (_readTranslationAloud && _translationModeEnabled)
                  Builder(builder: (context) {
                    final lang = translationLanguageNotifier.value;
                    final voices = _voicesForLanguage(lang);
                    if (voices.isEmpty) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline_rounded),
                        title: Text(l10n.reader_noVoiceForLanguage),
                      );
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mic_rounded),
                      title: Text(l10n.reader_translationVoice),
                      trailing: DropdownButton<String>(
                        value: _translationVoiceFor(lang),
                        underline: const SizedBox(),
                        items: [
                          for (final v in voices)
                            DropdownMenuItem(
                              value: v.name,
                              child: Text('${v.displayName} (${v.languageCode})'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          Hive.box('settings').put('translationVoice_$lang', value);
                          setModalState(() {});
                          _applyTranslationReading();
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Défilement automatique pendant la lecture. Contrairement à
  /// _scrollToSentence (qui re-centre systématiquement la phrase à
  /// _scrollAnchorFraction — utile pour un saut volontaire précis), celui-ci
  /// ne bouge la page QUE si la phrase courante sort d'une zone confortable
  /// au milieu de l'écran, et l'anime plus lentement quand il le fait. Sans
  /// ça, chaque changement de phrase re-déclenchait un ajustement — souvent
  /// minime, mais parfois un grand saut brusque (paragraphe long, dialogue
  /// court...) — ce qui donnait un défilement saccadé et étourdissant.
  Future<void> _autoScrollToCurrentSentence(int globalIndex) async {
    if (_bookMode) {
      // La page tourne toute seule quand la voix arrive en bas.
      await _bookGoToSentence(globalIndex);
      return;
    }
    try {
      // L'ancre précise de la phrase (voir _sentenceAnchorKeys) en priorité
      // — sans elle, deux phrases voisines du même paragraphe pointeraient
      // vers le même repère (celui du paragraphe entier) et aucun mouvement
      // ne serait jamais détecté avant de changer de paragraphe.
      final anchorContext = _sentenceAnchorKeys[globalIndex]?.currentContext ??
          _sentenceKeys[globalIndex]?.currentContext;
      final renderObject = anchorContext?.findRenderObject();
      if (anchorContext == null || renderObject == null) {
        // Pas encore construit (saut plus large que d'habitude, ex: après une
        // synthèse très rapide) — retombe sur le comportement habituel.
        await _scrollToSentence(globalIndex);
        return;
      }

      final scrollable = Scrollable.of(anchorContext);
      final viewportBox = RenderAbstractViewport.of(renderObject) as RenderBox;
      final currentY = _paintedY(renderObject, viewportBox);
      final viewportHeight = _viewportHeight(viewportBox);
      // Zone confortable très resserrée (30%-36%, autour de l'ancrage à
      // 1/3) : un petit ajustement se déclenche à presque chaque phrase au
      // lieu d'attendre plusieurs phrases — beaucoup de petits pas plutôt
      // que peu de grands, pour une impression de défilement continu.
      final lower = viewportHeight * 0.30;
      final upper = viewportHeight * 0.36;
      if (currentY >= lower && currentY <= upper) return;

      final desiredY = viewportHeight * _scrollAnchorFraction;
      final target = scrollable.position.pixels + (currentY - desiredY);
      // Voir le commentaire équivalent dans _animateToAnchor : offset 0 n'est
      // pas le haut du livre ici, donc le minimum valide est minScrollExtent
      // (souvent négatif), pas 0.0.
      await scrollable.position.animateTo(
        target.clamp(scrollable.position.minScrollExtent, scrollable.position.maxScrollExtent),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
      );
    } catch (_) {
      // Purement un confort visuel — jamais laisser un pépin de layout
      // transitoire (ex: pendant un changement de taille de police) casser
      // le rendu de la page avec l'écran d'erreur rouge de Flutter.
    }
  }

  void _onHandlerSynthesizingChanged() {
    if (!mounted) return;
    setState(() => _isSynthesizing = audioHandler?.isSynthesizingNotifier.value ?? false);
  }

  void _onHandlerWantsToPlayChanged() {
    if (!mounted) return;
    setState(() => _wantsToPlay = audioHandler?.shouldBePlayingNotifier.value ?? false);
  }

  // ─── Session audio (lecture en arrière-plan) ──────────────────────────────

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  // ─── Rendu d'un paragraphe ────────────────────────────────────────────────

  Widget _buildParagraphWidget(
      _ParagraphItem para, GlobalKey? paraKey, BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final baseColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final containsCurrent = para.sentenceIndices.contains(_currentGlobalIndex);
    final wordNotifier = audioHandler?.currentWordIndexNotifier;
    final chapterId = widget.ebook.chapters[para.chapterIndex].id;
    final savedRanges = (_savedHighlightsByChapter[chapterId]?[para.paragraphIndexInChapter] ?? const [])
        .map((a) => TextRange(
            start: (a.startOffset - para.charOffset).clamp(0, 1 << 30),
            end: a.endOffset - para.charOffset))
        .where((r) => r.end > 0)
        .toList();
    final isSelectingThis = identical(_selectingParagraph, para);

    return KeyedSubtree(
      key: paraKey,
      child: ValueListenableBuilder<double>(
        valueListenable: fontSizeNotifier,
        builder: (context, fontSize, _) => ValueListenableBuilder<String?>(
          valueListenable: fontFamilyNotifier,
          builder: (context, fontFamily, _) {
            final baseStyle = TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: 1.6,
              color: baseColor,
            );

            // Construit le texte du paragraphe une seule fois, en notant les
            // offsets de caractères de la phrase courante — nécessaires pour
            // mesurer ensuite où dessiner le surlignage.
            final spans = <InlineSpan>[];
            int cursor = 0;
            int? sentenceStart;
            int? sentenceEnd;
            String currentSentenceText = '';
            for (final idx in para.sentenceIndices) {
              final s = _sentences[idx];
              final isCurrent = idx == _currentGlobalIndex;
              final tap = TapGestureRecognizer()..onTap = () => audioHandler?.playSentenceAt(idx);

              // Ancre invisible (largeur nulle) juste avant la phrase — donne
              // au défilement automatique un point de repère précis pour
              // CHAQUE phrase, plutôt qu'un seul partagé par tout le
              // paragraphe (voir _sentenceAnchorKeys). Chaque WidgetSpan
              // occupe UNE position dans le texte "plat" utilisé pour les
              // offsets de sélection — il faut donc avancer cursor en
              // conséquence, sinon le surlignage se décale.
              final anchorKey = _sentenceAnchorKeys[idx];
              if (anchorKey != null) {
                spans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: KeyedSubtree(key: anchorKey, child: const SizedBox.shrink()),
                ));
                cursor += 1;
              }

              spans.add(TextSpan(
                text: s.text,
                recognizer: tap,
                // Le gras est désactivé pendant toute sélection tactile en
                // cours (n'importe où sur la page) : c'est la seule chose
                // que change `isCurrent` qui affecte la largeur du texte —
                // et donc la seule chose capable de reformer la mise en
                // page sous le doigt. Le surlignage (peint par-dessus, pas
                // dans le texte) n'a lui aucun impact sur la mise en page,
                // donc pas besoin de le geler : le suivi de lecture peut
                // continuer en temps réel partout pendant qu'on sélectionne.
                style: (isCurrent && _selectingParagraph == null)
                    ? TextStyle(fontWeight: FontWeight.w600, color: baseColor)
                    : null,
              ));
              if (isCurrent) {
                sentenceStart = cursor;
                sentenceEnd = cursor + s.text.length;
                currentSentenceText = s.text;
              }
              cursor += s.text.length;

              spans.add(TextSpan(text: ' ', recognizer: tap));
              cursor += 1;
            }

            final fullSpan = TextSpan(style: baseStyle, children: spans);

            Widget buildParagraph(int activeWordIndex, TextRange? selection) {
              TextRange? wordRange;
              final sStart = sentenceStart;
              if (sStart != null && activeWordIndex >= 0) {
                final words = currentSentenceText.split(' ');
                var offset = sStart;
                for (var i = 0; i < words.length && i <= activeWordIndex; i++) {
                  if (i == activeWordIndex) {
                    wordRange = TextRange(start: offset, end: offset + words[i].length);
                    break;
                  }
                  offset += words[i].length + 1;
                }
              }

              final sEnd = sentenceEnd;
              return _HighlightedParagraph(
                text: fullSpan,
                sentenceRange: (sStart != null && sEnd != null)
                    ? TextRange(start: sStart, end: sEnd)
                    : null,
                wordRange: wordRange,
                sentenceColor: primary.withOpacity(0.18),
                wordColor: primary.withOpacity(0.45),
                placeholderCount: para.sentenceIndices.length,
                selectionRange: selection,
                selectionColor: Colors.amber.withOpacity(0.45),
                savedHighlights: savedRanges,
                savedHighlightColor: Colors.amber.withOpacity(0.28),
                onLongPressStart: (word, wordText, globalPos) => _onSelectionStart(
                    para, word, fullSpan.toPlainText(), wordText, globalPos),
                onLongPressMoveUpdate: (word, wordText, globalPos) =>
                    _onSelectionUpdate(para, word, wordText, globalPos),
                onLongPressEnd: () => _onSelectionEnd(para),
                onStartHandleDrag: (word, wordText, globalPos) =>
                    _onAdjustSelectionStart(para, word, wordText, globalPos),
                onEndHandleDrag: (word, wordText, globalPos) =>
                    _onAdjustSelectionEnd(para, word, wordText, globalPos),
                onHandleDragEnd: _onHandleDragEnd,
              );
            }

            Widget withWordTracking(TextRange? selection) {
              // Seul le paragraphe contenant la phrase en cours a besoin de se
              // reconstruire à chaque changement de mot (~25ms) — les autres
              // restent statiques, pour ne pas ralentir tout le reste de la page.
              //
              // Toujours envelopper dans ce ValueListenableBuilder quand
              // `containsCurrent` est vrai, même pendant une sélection — la
              // forme de l'arbre ne doit jamais changer selon l'état de
              // sélection (même raisonnement que pour le ValueListenableBuilder
              // de sélection plus bas) : si ce paragraphe est AUSSI celui
              // qu'on sélectionne, faire apparaître/disparaître cette couche
              // casserait son GestureDetector en plein geste.
              if (!containsCurrent || wordNotifier == null) {
                return buildParagraph(-1, selection);
              }
              return ValueListenableBuilder<int>(
                valueListenable: wordNotifier,
                builder: (context, wordIdx, _) {
                  // Le minuteur mot par mot continue de tourner pendant une
                  // sélection, mais suit la VRAIE phrase en cours de lecture
                  // (potentiellement déjà avancée ailleurs, voir
                  // _onHandlerIndexChanged) — l'appliquer quand même à cette
                  // phrase gelée donnait l'impression qu'il bouclait sans fin
                  // dessus. On l'ignore simplement pendant la sélection ; il
                  // rattrape la bonne phrase dès qu'elle se termine.
                  final effectiveWordIdx = _selectingParagraph == null ? wordIdx : -1;
                  return buildParagraph(effectiveWordIdx, selection);
                },
              );
            }

            // Toujours envelopper dans le ValueListenableBuilder, que ce
            // paragraphe soit celui en cours de sélection ou non — la forme
            // de l'arbre de widgets doit rester IDENTIQUE d'une frame à
            // l'autre. La brancher seulement pour `isSelectingThis` (comme
            // avant) faisait apparaître/disparaître cette couche exactement
            // au moment où l'appui long démarre, ce qui recréait le
            // GestureDetector en plein milieu du geste et le cassait : seul
            // le premier mot restait sélectionné, glisser n'étendait plus
            // rien tant qu'on ne réessayait pas une seconde fois (où la
            // couche était déjà en place dès le départ).
            return ValueListenableBuilder<TextRange?>(
              valueListenable: _selectionRangeNotifier,
              builder: (context, selection, _) =>
                  withWordTracking(isSelectingThis ? selection : null),
            );
          },
        ),
      ),
    );
  }

  // ─── Mode livre ───────────────────────────────────────────────────────────

  Widget _buildChapterHeader(BuildContext context, _ChapterHeader item) {
    return Padding(
      key: ValueKey('h_${item.chapterIndex}'),
      padding: EdgeInsets.only(
        top: item.chapterIndex == 0 || _bookMode ? 0 : 32,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.chapterIndex > 0 && !_bookMode)
            Divider(color: Colors.grey[300], height: 1),
          if (!_bookMode) const SizedBox(height: 12),
          Text(item.title, style: _chapterTitleStyle(context)),
        ],
      ),
    );
  }

  TextStyle? _chapterTitleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);

  void _setBookMode(bool on) {
    Hive.box('settings').put('bookMode', on);
    setState(() {
      _bookMode = on;
      _showReturnButton = false;
      _bookAnchorSentence = _currentGlobalIndex;
      _paginationKey = '';
      _paginatingKey = '';
    });
    if (!on) {
      // Retour au défilement : la liste se recrée à la phrase en cours.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToSentence(_currentGlobalIndex, animate: false));
    }
  }

  void _setPageTurnStyle(PageTurnStyle style) {
    Hive.box('settings').put('pageTurn', style == PageTurnStyle.slide ? 'slide' : 'curl');
    setState(() => _pageTurnStyle = style);
  }

  int? _pageForSentence(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _pageOfSentence.length) return null;
    final p = _pageOfSentence[globalIndex];
    return p < 0 ? null : p;
  }

  Future<bool> _bookGoToSentence(int globalIndex, {bool animate = true}) async {
    final p = _pageForSentence(globalIndex);
    final turner = _pageTurnerKey.currentState;
    if (p == null || turner == null) {
      // Pages pas encore calculées : on s'y placera dès qu'elles le seront.
      _bookAnchorSentence = globalIndex;
      return true;
    }
    await turner.goTo(p, animate: animate);
    return true;
  }

  void _onBookPageChanged(int page) {
    final first = _firstSentenceOfPage(page);
    final onCurrent = _pageForSentence(_currentGlobalIndex) == page;
    setState(() {
      _bookPage = page;
      if (first != null) _bookAnchorSentence = first;
      _showReturnButton = !onCurrent;
    });
  }

  int? _firstSentenceOfPage(int page) {
    if (page < 0 || page >= _pages.length) return null;
    for (final item in _pages[page]) {
      if (item is _ParagraphItem) return item.sentenceIndices.first;
    }
    return null;
  }

  /// Découpe le livre en pages qui tiennent exactement à l'écran, avec la
  /// même police, taille et interligne que l'affichage. Un paragraphe trop
  /// long continue sur la page suivante (coupé entre deux phrases) ; chaque
  /// chapitre commence sur une nouvelle page. Fait par petits lots pour ne
  /// jamais figer l'écran sur un long livre.
  Future<void> _paginate(String key, Size area, double fontSize, String? fontFamily,
      TextScaler scaler, TextStyle? titleStyle) async {
    final gen = ++_paginationGen;
    _paginatingKey = key;
    final width = area.width - 32;
    final lineH = scaler.scale(fontSize) * 1.6;
    // Une ligne de marge : la phrase lue passe en gras et peut s'allonger.
    final height = area.height - 16 - lineH;
    final style = TextStyle(fontFamily: fontFamily, fontSize: fontSize, height: 1.6);
    const paraGap = 10.0;

    final pages = <List<_BookItem>>[];
    final pageOf = List<int>.filled(_sentences.length, -1);
    var page = <_BookItem>[];
    var used = 0.0;

    void closePage() {
      if (page.isEmpty) return;
      pages.add(page);
      page = <_BookItem>[];
      used = 0;
    }

    void addItem(_BookItem item, double h) {
      page.add(item);
      used += h;
      if (item is _ParagraphItem) {
        for (final i in item.sentenceIndices) {
          pageOf[i] = pages.length;
        }
      }
    }

    double measureTitle(String t) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: titleStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final h = tp.height + 12;
      tp.dispose();
      return h;
    }

    var processed = 0;
    for (final item in _displayItems) {
      if (++processed % 120 == 0) {
        await Future<void>.delayed(Duration.zero);
        if (gen != _paginationGen || !mounted) return;
      }
      if (item is _ChapterHeader) {
        closePage();
        addItem(item, measureTitle(item.title));
        continue;
      }
      final para = item as _ParagraphItem;
      var remaining = List<int>.of(para.sentenceIndices);
      var charOffset = 0;
      while (remaining.isNotEmpty) {
        // Texte tel qu'affiché : chaque phrase suivie d'une espace (les
        // ancres invisibles devant chaque phrase n'ont pas de largeur).
        final buf = StringBuffer();
        final ends = <int>[];
        for (final idx in remaining) {
          buf.write(_sentences[idx].text);
          ends.add(buf.length);
          buf.write(' ');
        }
        final tp = TextPainter(
          text: TextSpan(text: buf.toString(), style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout(maxWidth: width);
        final free = height - used;
        if (tp.height + paraGap <= free) {
          addItem(
              remaining.length == para.sentenceIndices.length
                  ? para
                  : _ParagraphItem(remaining, para.chapterIndex,
                      para.paragraphIndexInChapter, charOffset: charOffset),
              tp.height + paraGap);
          tp.dispose();
          break;
        }
        // Combien de phrases entières tiennent dans la place restante ?
        var fit = 0;
        for (var k = 0; k < ends.length; k++) {
          final boxes = tp.getBoxesForSelection(
              TextSelection(baseOffset: ends[k] - 1, extentOffset: ends[k]));
          final bottom = boxes.isEmpty ? double.infinity : boxes.last.bottom;
          if (bottom + paraGap <= free) {
            fit = k + 1;
          } else {
            break;
          }
        }
        tp.dispose();
        if (fit == 0) {
          if (page.isNotEmpty) {
            closePage();
            continue; // réessayer sur une page vide
          }
          fit = 1; // phrase plus haute qu'une page entière : tant pis
        }
        final part = remaining.sublist(0, fit);
        addItem(
            _ParagraphItem(part, para.chapterIndex, para.paragraphIndexInChapter,
                charOffset: charOffset),
            height); // page pleine
        for (final idx in part) {
          charOffset += 1 + _sentences[idx].text.length + 1;
        }
        remaining = remaining.sublist(fit);
        closePage();
      }
    }
    closePage();
    if (gen != _paginationGen || !mounted) return;
    setState(() {
      _pages = pages;
      _pageOfSentence = pageOf;
      _paginationKey = key;
      final anchor = _bookAnchorSentence >= 0 ? _bookAnchorSentence : _currentGlobalIndex;
      _bookPage = (_pageForSentence(anchor) ?? 0).clamp(0, pages.isEmpty ? 0 : pages.length - 1);
      _showReturnButton = false;
    });
  }

  Widget _buildBookView(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: fontSizeNotifier,
      builder: (context, fontSize, _) => ValueListenableBuilder<String?>(
        valueListenable: fontFamilyNotifier,
        builder: (context, fontFamily, _) => ValueListenableBuilder<double>(
          valueListenable: readerMarginNotifier,
          builder: (context, readerMargin, _) => LayoutBuilder(builder: (context, c) {
          const footer = 28.0;
          final usable = c.maxHeight - footer;
          // Marge réglable (Profil > Texte) en haut et en bas de chaque page,
          // plafonnée pour laisser au moins la moitié de la page au texte
          // (paysage). Sans AppBar, on évite aussi la barre d'état.
          final margin = readerMargin.clamp(0.0, usable / 4).toDouble();
          final marginTop = margin + (_readerVisible ? 0.0 : MediaQuery.of(context).padding.top);
          final marginBottom = margin;
          // La pagination mesure dans `area` : y retirer les marges garde le
          // découpage des pages exact, et un changement de marge change la
          // clé ci-dessous, donc relance la pagination.
          final area = Size(c.maxWidth, usable - marginTop - marginBottom);
          final scaler = MediaQuery.textScalerOf(context);
          final key =
              '${area.width.round()}x${area.height.round()}|$fontSize|$fontFamily|${scaler.scale(10)}';
          if (key != _paginationKey) {
            if (key != _paginatingKey) {
              _paginatingKey = key;
              final titleStyle = _chapterTitleStyle(context);
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _paginate(key, area, fontSize, fontFamily, scaler, titleStyle));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final scheme = Theme.of(context).colorScheme;
          final grey = Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.5));
          return Stack(children: [
            Positioned.fill(
              child: Column(children: [
                Expanded(
                  child: PageTurner(
                    key: _pageTurnerKey,
                    itemCount: _pages.length,
                    initialIndex: _bookPage,
                    style: _pageTurnStyle,
                    pageColor: Theme.of(context).scaffoldBackgroundColor,
                    onPageChanged: _onBookPageChanged,
                    itemBuilder: (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(16, 16 + marginTop, 16, marginBottom),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in _pages[i])
                              if (item is _ChapterHeader)
                                _buildChapterHeader(context, item)
                              else
                                _buildParagraphWidget(item as _ParagraphItem, null, context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: footer,
                  child: Center(
                    child: Text(
                        AppLocalizations.of(context)!
                            .reader_pageOf(_bookPage + 1, _pages.length),
                        style: grey),
                  ),
                ),
              ]),
            ),
            // Toucher le bord droit / gauche : page suivante / précédente.
            // Un appui long y sélectionne toujours le texte normalement.
            Positioned(
              left: 0,
              top: 0,
              bottom: footer,
              width: c.maxWidth * 0.22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _pageTurnerKey.currentState?.previous(),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: footer,
              width: c.maxWidth * 0.22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _pageTurnerKey.currentState?.next(),
              ),
            ),
          ]);
        }),
        ),
      ),
    );
  }

  // ─── Construction de la liste ─────────────────────────────────────────────

  void _buildFlatList() {
    int globalIndex = 0;

    for (int ci = 0; ci < widget.ebook.chapters.length; ci++) {
      final chapter = widget.ebook.chapters[ci];
      _chapterDisplayIndex[ci] = _displayItems.length;
      _displayItems.add(_ChapterHeader(chapter.title, ci));
      var paraIndexInChapter = 0;

      // Séparer en paragraphes (double saut de ligne ou saut simple)
      final rawParagraphs = chapter.textContent
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.replaceAll('\n', ' ').trim())
          .where((p) => p.isNotEmpty)
          .toList();

      // Fallback : si pas de paragraphes détectés, traiter tout le texte comme un seul
      final paragraphTexts = rawParagraphs.isEmpty
          ? [chapter.textContent.replaceAll('\n', ' ').trim()]
          : rawParagraphs;

      for (final paraText in paragraphTexts) {
        final sentences = _splitIntoSentences(paraText);
        if (sentences.isEmpty) continue;

        final paraIndices = <int>[];
        final paraKey = GlobalKey();

        for (final text in sentences) {
          _sentences.add(_SentenceItem(globalIndex, ci, text));
          _sentenceKeys[globalIndex] = paraKey; // toutes les phrases du para partagent la même clé
          _sentenceAnchorKeys[globalIndex] = GlobalKey();
          paraIndices.add(globalIndex);
          globalIndex++;
        }

        _displayItems.add(_ParagraphItem(paraIndices, ci, paraIndexInChapter));
        paraIndexInChapter++;
      }
    }
  }

  int _findDisplayIndex(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _sentences.length) return -1;
    final ci = _sentences[globalIndex].chapterIndex;
    final start = _chapterDisplayIndex[ci] ?? 0;
    for (int di = start; di < _displayItems.length; di++) {
      final item = _displayItems[di];
      if (item is _ParagraphItem && item.sentenceIndices.contains(globalIndex)) return di;
      if (item is _ChapterHeader && item.chapterIndex > ci) break;
    }
    return -1;
  }

  // ─── Scroll ───────────────────────────────────────────────────────────────

  /// N'affiche "Retour au texte en cours" que sur un vrai glissement tactile
  /// (dragDetails non nul) — jamais sur un mouvement programmatique (nos
  /// propres jumpTo/animateTo, le placement initial de
  /// scrollable_positioned_list, ou même un simple changement d'état comme
  /// pause/lecture qui redéclenche parfois un evenement de position sans
  /// qu'aucun doigt ne touche l'écran). Contrairement à écouter
  /// itemPositions (qui réagit à N'IMPORTE QUEL changement de position, peu
  /// importe sa cause), dragDetails distingue fiablement un geste utilisateur
  /// de tout le reste, sans avoir besoin de délais de grâce fragiles.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
      if (!_showReturnButton) {
        setState(() => _showReturnButton = true);
      }
    }
    return false;
  }

  /// Position Y actuelle de [renderObject] dans le viewport (0 = haut du
  /// viewport, [_viewportHeight] = bas), mesurée directement sur l'arbre de
  /// rendu déjà peint plutôt que via getOffsetToReveal — dont le calcul de
  /// fraction ne correspond PAS au viewport visuel réel avec ce package
  /// (UnboundedRenderViewport, utilisé pour permettre un scroll bidirectionnel
  /// à partir d'un index arbitraire, rapporte une géométrie différente d'un
  /// Viewport classique). Mesurer la position peinte réelle est fiable quel
  /// que soit ce détail interne.
  double _paintedY(RenderObject renderObject, RenderBox viewportBox) {
    return (renderObject as RenderBox).localToGlobal(Offset.zero, ancestor: viewportBox).dy;
  }

  double _viewportHeight(RenderBox viewportBox) => viewportBox.size.height;

  /// Anime le scroll pour amener [renderObject] (via son [anchorContext],
  /// nécessaire pour retrouver le Scrollable qui le contient) exactement à
  /// [_scrollAnchorFraction] de la hauteur du viewport, qu'il soit déjà
  /// visible ou non — contrairement à ensureVisible, qui ne bouge que si
  /// l'item est hors champ et ne garantit aucune position précise. Réservé
  /// à l'ajustement FIN une fois le bon paragraphe déjà à l'écran — le gros
  /// du trajet (potentiellement très loin) est fait par
  /// _itemScrollController.scrollTo, voir _scrollToSentence.
  Future<void> _animateToAnchor(
    BuildContext anchorContext,
    RenderObject renderObject,
    Duration duration,
    Curve curve, {
    bool animate = true,
  }) async {
    final scrollable = Scrollable.of(anchorContext);
    final viewportBox = RenderAbstractViewport.of(renderObject) as RenderBox;
    final currentY = _paintedY(renderObject, viewportBox);
    final desiredY = _viewportHeight(viewportBox) * _scrollAnchorFraction;
    final target = scrollable.position.pixels + (currentY - desiredY);
    // scrollable_positioned_list ancre son offset 0 sur le paragraphe visé par
    // le saut grossier (étape 1), pas sur le haut du livre : les phrases qui
    // précèdent cette ancre dans le viewport ont un offset NÉGATIF. Borner à
    // 0.0 comme minimum (au lieu de minScrollExtent, qui peut être très
    // négatif ici) écrasait systématiquement ces corrections vers le bas —
    // exactement le bug "ça ramène vers le bas" signalé par l'utilisateur.
    final clamped = target.clamp(
      scrollable.position.minScrollExtent,
      scrollable.position.maxScrollExtent,
    );
    if (!animate) {
      scrollable.position.jumpTo(clamped);
      return;
    }
    await scrollable.position.animateTo(
      clamped,
      duration: duration,
      curve: curve,
    );
  }

  /// Retourne true si la phrase [globalIndex] a bien été atteinte.
  /// [animate] à false pour un saut instantané, sans les allers-retours
  /// visibles habituels — utilisé pour restaurer la position à l'ouverture
  /// d'un livre, où une longue animation étape par étape est juste
  /// étourdissante plutôt qu'utile (contrairement à la navigation en cours
  /// de lecture, où voir le défilement aide à se repérer).
  Future<bool> _scrollToSentence(int globalIndex, {bool animate = true}) async {
    if (globalIndex < 0 || globalIndex >= _sentences.length) return false;
    if (_bookMode) return _bookGoToSentence(globalIndex, animate: animate);
    if (!_itemScrollController.isAttached) return false;
    bool success = false;

    try {
      final di = _findDisplayIndex(globalIndex);
      if (di < 0) return false;

      // Étape 1 : saut vers le bon PARAGRAPHE, fiable même à grande
      // distance — scrollable_positioned_list mesure réellement les items
      // déjà construits et affine son estimation au fur et à mesure, au
      // lieu de deviner leur hauteur comme le faisait notre ancien code
      // (jamais fiable sur un livre long : l'erreur s'accumulait à chaque
      // paragraphe et empirait avec une taille de police différente de 16).
      if (animate) {
        await _itemScrollController.scrollTo(
          index: di,
          alignment: _scrollAnchorFraction,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        _itemScrollController.jumpTo(index: di, alignment: _scrollAnchorFraction);
      }
      if (!mounted) return false;

      // Étape 2 : ajustement fin vers la PHRASE exacte dans ce paragraphe —
      // un paragraphe peut contenir plusieurs phrases sur plusieurs lignes,
      // et l'alignement ci-dessus ne cible que le paragraphe dans son
      // ensemble. Deux passes : scrollable_positioned_list continue de
      // s'auto-corriger sur plusieurs frames après un jumpTo/scrollTo —
      // mesurer et corriger une seule fois immédiatement après l'étape 1 lit
      // une géométrie pas encore à jour et vise donc une cible fausse. La
      // deuxième passe rattrape ce décalage une fois la mise en page
      // stabilisée.
      for (var pass = 0; pass < 2; pass++) {
        await Future.delayed(const Duration(milliseconds: 80));
        if (!mounted) break;
        final anchorContext = _sentenceAnchorKeys[globalIndex]?.currentContext ??
            _sentenceKeys[globalIndex]?.currentContext;
        final renderObject = anchorContext?.findRenderObject();
        if (anchorContext != null && renderObject != null) {
          await _animateToAnchor(
            anchorContext,
            renderObject,
            const Duration(milliseconds: 200),
            Curves.easeOut,
            animate: animate,
          );
          success = true;
        }
      }
    } catch (_) {
      // Confort visuel seulement — jamais casser l'écran de lecture.
    }
    return success;
  }

  Future<void> _returnToCurrent() async {
    final found = await _scrollToSentence(_currentGlobalIndex);
    // Le bouton ne se cache que si on a vraiment atteint la phrase — sinon
    // il reste affiché pour permettre de réessayer, au lieu de disparaître
    // silencieusement en laissant l'utilisateur sans repère.
    if (mounted) setState(() => _showReturnButton = !found);
  }

  // Direction du bouton de retour : ↑ si la phrase est plus haut (on a
  // scrollé vers le bas, au-delà de la position de lecture), ↓ sinon (on a
  // scrollé vers le haut, avant la position de lecture). S'appuie sur les
  // items RÉELLEMENT visibles (fournis par le package) plutôt que sur une
  // estimation de position — fiable même très loin dans un livre long.
  bool get _isCurrentAbove {
    if (_bookMode) {
      final p = _pageForSentence(_currentGlobalIndex);
      return p != null && p < _bookPage;
    }
    final di = _findDisplayIndex(_currentGlobalIndex);
    if (di < 0) return false;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return false;

    var minVisible = positions.first.index;
    var maxVisible = positions.first.index;
    for (final p in positions) {
      if (p.index < minVisible) minVisible = p.index;
      if (p.index > maxVisible) maxVisible = p.index;
    }
    if (di < minVisible) return true; // la lecture est plus haut que ce qui est visible
    if (di > maxVisible) return false; // plus bas

    for (final p in positions) {
      if (p.index == di) return p.itemLeadingEdge < 0;
    }
    return false;
  }

  // ─── Utilitaires ─────────────────────────────────────────────────────────

  /// Rythme de lecture moyen à voix haute, à vitesse 1x (mots/minute) —
  /// utilisé pour estimer le temps déjà écouté et le temps total du livre.
  static const double _baseWordsPerMinute = 150.0;

  int? _totalWordCountCache;

  int get _totalWordCount {
    final cached = _totalWordCountCache;
    if (cached != null) return cached;
    final total = _sentences.fold<int>(0, (sum, s) => sum + s.text.split(' ').length);
    _totalWordCountCache = total;
    return total;
  }

  int get _wordsReadSoFar {
    final upTo = (_scrubberPreviewIndex?.round() ?? _currentGlobalIndex);
    var count = 0;
    for (var i = 0; i <= upTo && i < _sentences.length; i++) {
      count += _sentences[i].text.split(' ').length;
    }
    return count;
  }

  Duration get _elapsedReadingEstimate {
    final wpm = _baseWordsPerMinute * _playbackSpeed;
    return Duration(seconds: (_wordsReadSoFar / wpm * 60).round());
  }

  Duration get _totalReadingEstimate {
    final wpm = _baseWordsPerMinute * _playbackSpeed;
    return Duration(seconds: (_totalWordCount / wpm * 60).round());
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Sauvegarde le temps de lecture accumulé dans les stats Hive
  void _flushReadingTime() {
    final seconds = _readingStopwatch.elapsed.inSeconds;
    if (seconds < 2) return;
    StatsService.instance.addSeconds(seconds);
    _readingStopwatch.reset();
  }

  Future<void> _togglePlayPause() async {
    if (_wantsToPlay) {
      await audioHandler?.pause();
    } else {
      await audioHandler?.play();
    }
  }

  // ─── Voix ─────────────────────────────────────────────────────────────────

  Future<void> _initializeScreen() async {
    ebookBox = Hive.box<Ebook>('ebooks');
    widget.ebook.lastOpenedAt = DateTime.now();
    await ebookBox.put(widget.ebook.id, widget.ebook);
    if (widget.ebook.selectedVoiceName.isNotEmpty) {
      setState(() => selectedVoice = widget.ebook.selectedVoiceName);
    }

    // Mettre à jour totalSentences si pas encore calculé (livres existants)
    if (widget.ebook.totalSentences == 0 && _sentences.isNotEmpty) {
      widget.ebook.totalSentences = _sentences.length;
      await ebookBox.put(widget.ebook.id, widget.ebook);
    }

    // Scroller jusqu'à la position restaurée après le premier frame
    if (_currentGlobalIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSentence(_currentGlobalIndex, animate: false);
      });
    }

    await _refreshVoices();

    // Précharge l'IA locale en arrière-plan (sans gêner la voix) : elle sera
    // prête quand l'utilisateur touchera « Définir ».
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) unawaited(LocalLlmService.instance.warmUp(pauseAudio: false));
    });

    // Demander les permissions requises pour la lecture en arrière-plan
    await _requestBackgroundPermissions();
  }

  /// Recharge la liste des voix disponibles (à l'ouverture, et au retour
  /// de l'écran de téléchargement des voix IA).
  Future<void> _refreshVoices() async {
    // 100 % gratuit : uniquement les voix IA locales installées sur le
    // téléphone, dans l'ordre anglais → français → portugais.
    // Ordinateur joignable (TalkTome Boost) : il a toutes les voix, même
    // celles qui ne sont pas installées sur ce téléphone (iPhone…).
    final boostReady = await PcBoostService.instance.base() != null;
    // Les voix réservées à l'ordinateur (Qwen3-TTS) restent toujours
    // visibles, signalées comme telles : on sait ainsi lesquelles ne
    // marchent pas avec le téléphone seul.
    final installed = (await SherpaTtsService.instance.installedVoices())
        .map((v) => v.name)
        .toSet();
    final aiVoices = boostReady
        ? SherpaTtsService.voices
        : SherpaTtsService.voices
            .where((v) =>
                installed.contains(v.name) ||
                !SherpaTtsService.modelById(v.modelId).runsOnPhone)
            .toList();
    final voices = <Voice>[
      ...aiVoices.map((v) => Voice(
            name: v.name,
            displayName: v.displayName,
            languageCode: v.languageCode,
          )),
    ];

    if (!mounted) return;
    setState(() => availableVoices = voices);
    final savedVoice = voices.where((v) => v.name == selectedVoice).firstOrNull;
    if (savedVoice != null) {
      setState(() => selectedLanguageCode = savedVoice.languageCode);
      // Mettre à jour la voix dans le handler maintenant qu'on a le bon languageCode
      audioHandler?.updateVoice(savedVoice.name, savedVoice.languageCode);
    } else if (voices.isNotEmpty) {
      // La voix sauvegardée n'existe plus (ancienne voix cloud Google,
      // retirée car payante) — on bascule sur une voix gratuite DE LA MÊME
      // LANGUE que l'ancienne : d'abord la même variante (fr-FR), sinon la
      // même langue (fr-CA → fr-FR), les voix IA locales passant en premier.
      final oldLocale =
          RegExp(r'([a-z]{2})-([A-Z]{2})').firstMatch(selectedVoice)?.group(0) ??
              selectedLanguageCode;
      final oldLang = oldLocale.split('-').first;
      final fallback = voices.where((v) => v.languageCode == oldLocale).firstOrNull ??
          voices.where((v) => v.languageCode.startsWith('$oldLang-')).firstOrNull ??
          voices.first;
      setState(() {
        selectedVoice = fallback.name;
        selectedLanguageCode = fallback.languageCode;
      });
      audioHandler?.updateVoice(fallback.name, fallback.languageCode);
      widget.ebook.selectedVoiceName = fallback.name;
      await ebookBox.put(widget.ebook.id, widget.ebook);
    }
  }

  /// Écran de téléchargement des voix IA, puis mise à jour de la liste.
  Future<void> _openVoiceDownloads() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const VoiceDownloadScreen(),
    ));
    if (mounted) await _refreshVoices();
  }

  /// Demande la permission notification (Android 13+) et l'exemption batterie (Samsung One UI)
  Future<void> _requestBackgroundPermissions() async {
    // Permission notification — obligatoire sur Android 13+ pour afficher la notification
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    // Exemption batterie — Samsung One UI tue les services en arrière-plan sans ça
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  void _saveProgress() {
    widget.ebook.lastReadPosition = _currentGlobalIndex;
    ebookBox.put(widget.ebook.id, widget.ebook);
  }

  // Pas des boutons +/- — plus grossier que celui du slider (0.05) pour
  // permettre d'atteindre rapidement une vitesse éloignée sans multiplier
  // les appuis.
  static const double _speedButtonStep = 0.1;

  // Vitesses courantes proposées en accès rapide, en plus du slider et des
  // boutons +/- — pour aller directement à une valeur usuelle sans tâtonner.
  static const List<double> _speedPresets = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  String _formatSpeed(double speed) =>
      '${speed % 1 == 0 ? speed.toInt() : speed}x';

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void changeSpeed(double newSpeed) {
            final clamped = double.parse(
              newSpeed.clamp(_speedMin, _speedMax).toStringAsFixed(2),
            );
            setDialogState(() => _playbackSpeed = clamped);
            setState(() {});
            audioHandler?.updateSpeed(clamped);
          }

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.reader_readingSpeed),
            content: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatSpeed(_playbackSpeed),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: AppLocalizations.of(context)!.reader_slower,
                      onPressed: _playbackSpeed <= _speedMin
                          ? null
                          : () => changeSpeed(_playbackSpeed - _speedButtonStep),
                    ),
                    Expanded(
                      child: Slider(
                        value: _playbackSpeed,
                        min: _speedMin,
                        max: _speedMax,
                        divisions: ((_speedMax - _speedMin) / _speedStep).round(),
                        label: _formatSpeed(_playbackSpeed),
                        onChanged: changeSpeed,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: AppLocalizations.of(context)!.reader_faster,
                      onPressed: _playbackSpeed >= _speedMax
                          ? null
                          : () => changeSpeed(_playbackSpeed + _speedButtonStep),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatSpeed(_speedMin), style: const TextStyle(color: Colors.grey)),
                      Text(_formatSpeed(_speedMax), style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final preset in _speedPresets)
                      ChoiceChip(
                        label: Text(_formatSpeed(preset)),
                        selected: (_playbackSpeed - preset).abs() < 0.001,
                        onSelected: (_) => changeSpeed(preset),
                      ),
                  ],
                ),
              ],
            ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.common_close),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeVoice(String? newVoiceName) async {
    if (newVoiceName == null) return;
    final voice = availableVoices.firstWhere((v) => v.name == newVoiceName);
    // Voix de l'ordinateur alors que TalkTome Boost ne répond pas : on le
    // dit plutôt que de laisser la lecture échouer.
    final ai = SherpaTtsService.voiceByName(voice.name);
    if (ai != null &&
        !SherpaTtsService.modelById(ai.modelId).runsOnPhone &&
        await PcBoostService.instance.base() == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.voice_pcRequiredTitle),
          content: Text(l10n.voice_pcRequiredBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.common_close),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      selectedVoice = voice.name;
      selectedLanguageCode = voice.languageCode;
    });
    audioHandler?.updateVoice(voice.name, voice.languageCode);
    widget.ebook.selectedVoiceName = voice.name;
    ebookBox.put(widget.ebook.id, widget.ebook);
  }

  /// Extrait la "famille" de langue d'un libellé précis (ex: "Anglais (US)"
  /// -> "Anglais", "Français (Canada) · hors ligne" -> "Français") — sert
  /// aux boutons de raccourci en haut du panneau de voix.
  String _languageFamily(String language) {
    final idx = language.indexOf('(');
    final base = idx > 0 ? language.substring(0, idx).trim() : language.trim();
    return base.replaceAll('· hors ligne', '').trim();
  }

  /// Grille de voix pour une langue — la taille des pastilles s'adapte à la
  /// largeur réellement disponible (via LayoutBuilder) pour bien remplir
  /// chaque cellule, au lieu d'une taille fixe qui laissait de l'espace
  /// mort tout autour sur les écrans larges (ce qui donnait l'impression
  /// de gros espaces entre les images).
  Widget _buildVoiceGrid(List<Voice> voices, {VoidCallback? onSelected}) {
    const crossAxisCount = 3;
    const spacing = 4.0;
    const nameLineHeight = 16.0; // hauteur de ligne fixe et déterministe du nom (voir style ci-dessous)
    // La bordure de sélection (largeur 3) s'ajoute à la taille du cercle
    // plutôt que d'être peinte à l'intérieur — donc réservée en permanence
    // (transparente si non sélectionné) pour que la hauteur de cellule ne
    // change jamais selon la sélection, sinon la pastille sélectionnée
    // débordait de la grille.
    const circleExtra = 2 * (2.0 + 3.0); // padding (2) + bordure (3), des deux côtés
    const textAndPaddingHeight = circleExtra + 3.0 + nameLineHeight; // cercle + espacement + nom

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
        final avatarSize = cellWidth * 0.76;
        final cellHeight = avatarSize + textAndPaddingHeight;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: cellWidth / cellHeight,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: voices.map((v) {
            final character = characterForVoice(v.name);
            final isSelected = v.name == selectedVoice;
            return GestureDetector(
              onTap: () async {
                await _changeVoice(v.name);
                // Le panneau reste ouvert (pas de Navigator.pop) pour
                // pouvoir essayer plusieurs voix d'affilée rapidement.
                onSelected?.call();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Toujours une bordure de largeur 3 (transparente si
                      // non sélectionné) — la taille du cercle ne change
                      // jamais selon l'état, seule la couleur change.
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: VoiceAvatar(character: character, size: avatarSize),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: nameLineHeight,
                    child: Text(
                      character.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3, // hauteur de ligne fixe : ni le gras ni la police ne peuvent la faire déborder
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Panneau de choix de voix — 3/4 de l'écran, voix groupées par langue
  /// précise (avec région : US, UK, Canada...) sous un titre, avec des
  /// boutons de raccourci par famille de langue en haut. N'interrompt pas
  /// la lecture (showModalBottomSheet ne touche pas à audioHandler).
  /// Timbre (plus grave ↔ plus aigu) de la voix actuelle, mémorisé pour
  /// chaque voix et appliqué tout de suite, même en pleine phrase.
  Widget _buildPitchSlider(BuildContext context, VoidCallback refresh) {
    final l10n = AppLocalizations.of(context)!;
    final voice = audioHandler?.voiceName ?? widget.ebook.selectedVoiceName;
    final pitch = TalkTomeAudioHandler.pitchFor(voice);
    final name = characterForVoice(voice).name;
    final grey = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${l10n.reader_voicePitch} — $name',
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis),
            ),
            if ((pitch - 1.0).abs() > 0.005)
              TextButton(
                onPressed: () async {
                  await audioHandler?.setVoicePitch(voice, 1.0);
                  refresh();
                },
                child: Text(l10n.reader_pitchNormal),
              ),
          ],
        ),
        Row(
          children: [
            Text(l10n.reader_pitchDeeper, style: grey),
            Expanded(
              child: Slider(
                value: pitch,
                min: TalkTomeAudioHandler.pitchMin,
                max: TalkTomeAudioHandler.pitchMax,
                divisions: 12,
                onChanged: (v) async {
                  await audioHandler?.setVoicePitch(voice, v);
                  refresh();
                },
              ),
            ),
            Text(l10n.reader_pitchLighter, style: grey),
          ],
        ),
      ],
    );
  }

  void _showVoicePicker() {
    // Groupe les voix par langue précise, en conservant l'ordre d'origine.
    final groups = <String, List<Voice>>{};
    for (final v in availableVoices) {
      final lang = characterForVoice(v.name).language;
      groups.putIfAbsent(lang, () => []).add(v);
    }

    // Familles de langue pour les raccourcis (dédupliquées, ordre de
    // première apparition), + un raccourci "Hors ligne" séparé si des voix
    // locales existent — utile pour aller directement aux voix gratuites
    // sans passer par les voix cloud premium.
    final families = <String>[];
    for (final lang in groups.keys) {
      final f = _languageFamily(lang);
      if (!families.contains(f)) families.add(f);
    }
    final hasLocalVoices = groups.keys.any((lang) => lang.contains('hors ligne'));
    final hasAiVoices = groups.keys.any((lang) => lang.contains('IA locale'));
    final chips = [
      if (hasAiVoices) 'IA locale',
      ...families,
      if (hasLocalVoices) 'Hors ligne',
    ];

    final sectionKeys = {for (final lang in groups.keys) lang: GlobalKey()};
    final panelScrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // StatefulBuilder pour rafraîchir localement la pastille
        // sélectionnée (bordure + gras) à chaque tap, sans fermer le
        // panneau — permet d'essayer plusieurs voix d'affilée rapidement.
        return StatefulBuilder(builder: (context, setModalState) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.reader_chooseVoice,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openVoiceDownloads();
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(AppLocalizations.of(context)!.voiceDownloads_manage),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildPitchSlider(context, () => setModalState(() {})),
                const SizedBox(height: 8),
                // Raccourcis par famille de langue (+ "Hors ligne")
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = chips[i];
                      return ActionChip(
                        label: Text(f),
                        onPressed: () {
                          final targetLang = f == 'Hors ligne'
                              ? groups.keys.firstWhere((lang) => lang.contains('hors ligne'))
                              : f == 'IA locale'
                                  ? groups.keys.firstWhere((lang) => lang.contains('IA locale'))
                                  : groups.keys.firstWhere((lang) => _languageFamily(lang) == f);
                          final renderObject =
                              sectionKeys[targetLang]?.currentContext?.findRenderObject();
                          // Calcul direct de l'offset cible (au lieu de
                          // Scrollable.ensureVisible) : marche de façon fiable
                          // dans les deux sens, vers le haut comme vers le bas.
                          if (renderObject != null) {
                            final viewport = RenderAbstractViewport.of(renderObject);
                            final target = viewport.getOffsetToReveal(renderObject, 0.0).offset;
                            panelScrollController.animateTo(
                              target.clamp(
                                0.0, panelScrollController.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  // SingleChildScrollView + Column plutôt que ListView : la
                  // liste virtualisée démontait les sections déjà visitées
                  // dès qu'elles sortaient de l'écran, donc les raccourcis
                  // ne les retrouvaient plus pour y remonter. Le contenu ici
                  // reste modeste (quelques dizaines de pastilles au total),
                  // donc tout garder construit n'a aucun coût perceptible.
                  child: SingleChildScrollView(
                    controller: panelScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            key: sectionKeys[entry.key],
                            padding: const EdgeInsets.only(top: 2, bottom: 8),
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          // Les voix Chirp3-HD n'offrent pas le surlignage mot
                          // par mot (Google ne renvoie pas les timepoints des
                          // marqueurs SSML pour ce tier) — séparées des voix
                          // Neural2 avec un sous-titre pour ne pas les mélanger.
                          _buildVoiceGrid(
                            entry.value.where((v) => v.hasWordTiming).toList(),
                            onSelected: () => setModalState(() {}),
                          ),
                          if (entry.value.any((v) => !v.hasWordTiming)) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.hd_rounded, size: 15, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.of(context)!.reader_highQualityNoWordHighlight,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            _buildVoiceGrid(
                              entry.value.where((v) => !v.hasWordTiming).toList(),
                              onSelected: () => setModalState(() {}),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        });
      },
    );
  }

  List<String> _splitIntoSentences(String text) {
    // Découpe après la ponctuation de fin de phrase, avec ou sans guillemet
    // fermant juste après (ex: Il dit : "Bonjour."  Puis il partit.) — sans
    // ça, tout ce qui suit un dialogue reste collé au paragraphe entier et
    // devient un seul énorme bloc envoyé à l'API TTS en un coup.
    final rawSentences = text
        .split(RegExp(
            r'(?<=[.!?…])\s+|(?<=[.!?…]["\x27’”»)\]])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Recolle ce qui a été coupé après une abréviation ou une initiale
    // (« Mr. Jones », « M. Dupont », « J. K. Rowling », « e.g. ») : sinon la
    // voix s'arrête net au milieu de la phrase.
    final joined = <String>[];
    for (final s in rawSentences) {
      if (joined.isNotEmpty && SpeechExpander.continuesAfter(joined.last, s)) {
        joined[joined.length - 1] = '${joined.last} $s';
      } else {
        joined.add(s);
      }
    }

    // Filet de sécurité : si un morceau reste quand même très long (texte
    // sans ponctuation de fin détectée), le redécouper pour éviter un appel
    // TTS unique portant sur un pavé de texte — source de longues pauses.
    const maxChunkLength = 220;
    final result = <String>[];
    for (final sentence in joined) {
      result.addAll(_splitLongChunk(sentence, maxChunkLength));
    }
    return _mergeContentlessFragments(result);
  }

  /// Recolle au fragment voisin toute "phrase" sans la moindre lettre ni
  /// chiffre (ex: un tiret cadratin isolé, laissé par une extraction PDF
  /// bancale — vu sur un livre où « —John Miller, CEO... » se retrouvait
  /// coupé en un fragment "—" tout seul). Un texte purement ponctuation
  /// envoyé seul à l'API Google TTS fait échouer les voix Neural2 avec une
  /// erreur "Invalid SSML" — et comme la lecture ne peut pas avancer tant
  /// que la phrase courante n'a pas fini de se synthétiser, ça bloquait la
  /// lecture indéfiniment sur ce fragment (l'app retentait la même phrase
  /// en boucle sans jamais progresser).
  List<String> _mergeContentlessFragments(List<String> sentences) {
    final hasContent = RegExp(r'[\p{L}\p{N}]', unicode: true);
    final merged = <String>[];
    var pendingPrefix = '';
    for (final s in sentences) {
      if (!hasContent.hasMatch(s)) {
        pendingPrefix = pendingPrefix.isEmpty ? s : '$pendingPrefix $s';
        continue;
      }
      merged.add(pendingPrefix.isEmpty ? s : '$pendingPrefix $s');
      pendingPrefix = '';
    }
    if (pendingPrefix.isNotEmpty) {
      if (merged.isNotEmpty) {
        merged[merged.length - 1] = '${merged.last} $pendingPrefix';
      } else {
        // Tout le paragraphe ne contient aucune lettre ni chiffre (cas
        // extrême) — on le garde tel quel plutôt que de le faire
        // disparaître silencieusement du texte affiché.
        merged.add(pendingPrefix);
      }
    }
    return merged;
  }

  /// Redécoupe un morceau de texte trop long sur une ponctuation "douce"
  /// (virgule, point-virgule, deux-points, tiret), ou à défaut sur un espace.
  List<String> _splitLongChunk(String text, int maxLength) {
    if (text.length <= maxLength) return [text];

    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > maxLength) {
      final window = remaining.substring(0, maxLength);
      var cut = -1;
      for (final sep in [', ', '; ', ': ', ' — ', ' - ']) {
        final idx = window.lastIndexOf(sep);
        if (idx > cut) cut = idx + sep.length;
      }
      if (cut <= 0) {
        final spaceIdx = window.lastIndexOf(' ');
        cut = spaceIdx > 0 ? spaceIdx + 1 : maxLength;
      }
      chunks.add(remaining.substring(0, cut).trim());
      remaining = remaining.substring(cut).trim();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  // ─── Panneau d'apparence (police + thème) ─────────────────────────────────

  void _showAppearancePanel() {
    final settings = Hive.box('settings');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          // Polices système Android disponibles sans package externe
          final fonts = [
            (label: 'Roboto',            value: null,                   preview: 'Aa'),
            (label: 'Serif',             value: 'serif',                preview: 'Aa'),
            (label: l10n.reader_fontCondensed, value: 'sans-serif-condensed', preview: 'Aa'),
            (label: 'Light',             value: 'sans-serif-light',     preview: 'Aa'),
            (label: 'Medium',            value: 'sans-serif-medium',    preview: 'Aa'),
            (label: 'Mono',              value: 'monospace',            preview: 'Aa'),
            (label: l10n.reader_fontCursive,   value: 'cursive',              preview: 'Aa'),
          ];
          // Padding pour la barre Samsung
          final bottomPad = MediaQuery.of(context).padding.bottom + 24;
          // Défilable : avec la couleur de page et le mode livre, le panneau
          // peut dépasser la hauteur de l'écran (petit écran, grand texte).
          return SingleChildScrollView(
            child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poignée
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(l10n.profileScreen_appearance,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // ── Fond ──────────────────────────────────────────────────
                Text(l10n.reader_background, style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, themeMode, _) => Row(
                    children: [
                      _themeChip(context: context, label: l10n.profileScreen_light,
                          icon: Icons.light_mode,
                          selected: themeMode == ThemeMode.light,
                          onTap: () {
                            themeModeNotifier.value = ThemeMode.light;
                            settings.put('themeMode', 'light');
                            setModalState(() {});
                          }),
                      const SizedBox(width: 10),
                      _themeChip(context: context, label: l10n.profileScreen_dark,
                          icon: Icons.dark_mode,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () {
                            themeModeNotifier.value = ThemeMode.dark;
                            settings.put('themeMode', 'dark');
                            setModalState(() {});
                          }),
                      const SizedBox(width: 10),
                      _themeChip(context: context, label: l10n.profileScreen_system,
                          icon: Icons.brightness_auto,
                          selected: themeMode == ThemeMode.system,
                          onTap: () {
                            themeModeNotifier.value = ThemeMode.system;
                            settings.put('themeMode', 'system');
                            setModalState(() {});
                          }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Couleur de page, filtre chaud, assombrissement ────────
                Text(l10n.reader_pageColor, style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ValueListenableBuilder<String>(
                  valueListenable: pageThemeNotifier,
                  builder: (context, current, _) => _pageColorPicker(context, current, (id) {
                    pageThemeNotifier.value = id;
                    settings.put('pageTheme', id);
                    setModalState(() {});
                  }),
                ),
                const SizedBox(height: 16),
                _comfortSlider(context, Icons.wb_twilight_rounded, l10n.reader_warmth,
                    warmthNotifier, 'warmth'),
                _comfortSlider(context, Icons.brightness_low_rounded, l10n.reader_dim,
                    dimNotifier, 'dim'),
                const SizedBox(height: 16),

                // ── Mode livre et animation de page ───────────────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.auto_stories_rounded),
                  title: Text(l10n.reader_bookMode),
                  value: _bookMode,
                  onChanged: (v) {
                    _setBookMode(v);
                    setModalState(() {});
                  },
                ),
                if (_bookMode) ...[
                  Text(l10n.reader_pageTurn, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<PageTurnStyle>(
                      segments: [
                        ButtonSegment(value: PageTurnStyle.curl, label: Text(l10n.reader_pageTurnCurl)),
                        ButtonSegment(value: PageTurnStyle.slide, label: Text(l10n.reader_pageTurnSlide)),
                      ],
                      selected: {_pageTurnStyle},
                      showSelectedIcon: false,
                      onSelectionChanged: (sel) {
                        _setPageTurnStyle(sel.first);
                        setModalState(() {});
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Taille du texte ───────────────────────────────────────
                Text(l10n.reader_textSizeSection, style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ValueListenableBuilder<double>(
                  valueListenable: fontSizeNotifier,
                  builder: (context, fontSize, _) => Row(
                    children: [
                      // Bouton diminuer
                      IconButton.outlined(
                        icon: const Text('A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: fontSize > 10
                            ? () {
                                final newSize = fontSize - 1;
                                fontSizeNotifier.value = newSize;
                                settings.put('fontSize', newSize);
                                setModalState(() {});
                              }
                            : null,
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      // Aperçu de la taille
                      Expanded(
                        child: Center(
                          child: Text(
                            l10n.profileScreen_pt(fontSize.toInt()),
                            style: TextStyle(fontSize: fontSize.clamp(12, 22), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      // Bouton augmenter
                      IconButton.outlined(
                        icon: const Text('A', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        onPressed: fontSize < 32
                            ? () {
                                final newSize = fontSize + 1;
                                fontSizeNotifier.value = newSize;
                                settings.put('fontSize', newSize);
                                setModalState(() {});
                              }
                            : null,
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Police ────────────────────────────────────────────────
                Text(l10n.reader_fontSection, style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ValueListenableBuilder<String?>(
                  valueListenable: fontFamilyNotifier,
                  builder: (context, currentFont, _) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: fonts.map((f) {
                      final selected = currentFont == f.value;
                      final color = Theme.of(context).colorScheme.primary;
                      return GestureDetector(
                        onTap: () {
                          fontFamilyNotifier.value = f.value;
                          settings.put('fontFamily', f.value);
                          setModalState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.12)
                                : Colors.transparent,
                            border: Border.all(
                                color: selected
                                    ? color
                                    : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(f.preview,
                                  style: TextStyle(
                                      fontFamily: f.value,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? color
                                          : null)),
                              const SizedBox(height: 4),
                              Text(f.label,
                                  style: TextStyle(
                                      fontFamily: f.value,
                                      fontSize: 11,
                                      color: selected
                                          ? color
                                          : Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  /// Pastilles de couleur de page (Auto, Blanc, Papier, Vert, Gris, Nuit).
  Widget _pageColorPicker(BuildContext context, String current, ValueChanged<String> onPick) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      'auto': l10n.reader_pageAuto,
      'white': l10n.reader_pageWhite,
      'paper': l10n.reader_pagePaper,
      'green': l10n.reader_pageGreen,
      'gray': l10n.reader_pageGray,
      'night': l10n.reader_pageNight,
    };
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(String id, Color bg, Color fg) {
      final selected = id == current;
      return Expanded(
        child: GestureDetector(
          onTap: () => onPick(id),
          child: Column(
            children: [
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  gradient: id == 'auto'
                      ? const LinearGradient(
                          colors: [Colors.white, Colors.white, Colors.black, Colors.black],
                          stops: [0, 0.5, 0.5, 1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.grey.withValues(alpha: 0.4),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: id == 'auto'
                    ? null
                    : Text('Aa', style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(labels[id]!, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Row(children: [
      swatch('auto', Colors.white, Colors.black),
      for (final t in pageThemes) swatch(t.id, t.background, t.text),
    ]);
  }

  Widget _comfortSlider(BuildContext context, IconData icon, String label,
      ValueNotifier<double> notifier, String key) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, v, _) => Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Slider(
              value: v,
              onChanged: (x) => notifier.value = x,
              onChangeEnd: (x) => Hive.box('settings').put(key, x),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: selected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? color : Colors.grey.shade600,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  // ─── Table des matières ───────────────────────────────────────────────────

  Future<void> _renameFile() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: widget.ebook.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reader_renameFileTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.reader_documentNameHint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.home_rename),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != widget.ebook.title) {
      widget.ebook.title = result;
      await Hive.box<Ebook>('ebooks').put(widget.ebook.id, widget.ebook);
      if (mounted) setState(() {});
    }
  }

  void _showSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(builder: (context, setModal) {
          final l10n = AppLocalizations.of(context)!;
          final results = query.isEmpty
              ? <_SentenceItem>[]
              : _sentences
                  .where((s) =>
                      s.text.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.reader_searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setModal(() => query = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (v) => setModal(() => query = v),
                  ),
                ),
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l10n.reader_resultCount(results.length),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.45),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final s = results[i];
                      final lower = s.text.toLowerCase();
                      final qLower = query.toLowerCase();
                      final matchStart = lower.indexOf(qLower);

                      return ListTile(
                        dense: true,
                        title: matchStart < 0
                            ? Text(s.text, maxLines: 2, overflow: TextOverflow.ellipsis)
                            : RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(text: s.text.substring(0, matchStart)),
                                    TextSpan(
                                      text: s.text.substring(matchStart, matchStart + query.length),
                                      style: TextStyle(
                                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: s.text.substring(matchStart + query.length)),
                                  ],
                                ),
                              ),
                        subtitle: Text(
                          l10n.reader_chapterSentence(s.chapterIndex + 1, s.globalIndex + 1),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentGlobalIndex = s.globalIndex);
                          _scrollToSentence(s.globalIndex);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );
  }

  void _showChapterList() {
    final currentChapterIndex = _sentences.isNotEmpty
        ? _sentences[_currentGlobalIndex].chapterIndex
        : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, sc) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(AppLocalizations.of(context)!.reader_tableOfContents,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: widget.ebook.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = widget.ebook.chapters[index];
                  final isCurrent = index == currentChapterIndex;
                  return ListTile(
                    selected: isCurrent,
                    leading: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[500],
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    title: Text(chapter.title,
                        style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text(AppLocalizations.of(context)!.reader_wordCount(chapter.wordCount)),
                    trailing: isCurrent
                        ? Icon(Icons.volume_up,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      final firstSentence = _sentences.firstWhere(
                        (s) => s.chapterIndex == index,
                        orElse: () => _sentences.first,
                      );
                      audioHandler?.stopAndSeekTo(firstSentence.globalIndex);
                      setState(() {
                        _currentGlobalIndex = firstSentence.globalIndex;
                        _isSynthesizing = false;
                        _showReturnButton = false;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToSentence(firstSentence.globalIndex);
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Couleur de page (Papier, Nuit…) : tout le lecteur — texte, barres,
    // lecteur audio — prend les couleurs de la page choisie.
    return ValueListenableBuilder<String>(
      valueListenable: pageThemeNotifier,
      builder: (context, pageTheme, _) => Theme(
        data: readerThemeData(Theme.of(context), pageTheme),
        child: Builder(builder: _buildReader),
      ),
    );
  }

  Widget _buildReader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: _readerVisible
          ? AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: l10n.profileScreen_dictionaryLanguage,
            onPressed: _showDictionaryLanguagePanel,
          ),
          IconButton(
            icon: Icon(
              Icons.translate_rounded,
              color: _translationModeEnabled ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: l10n.reader_liveTranslationTitle,
            onPressed: _showTranslationPanel,
          ),
          IconButton(
            icon: const Icon(Icons.format_size_rounded),
            tooltip: l10n.profileScreen_appearance,
            onPressed: _showAppearancePanel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: l10n.reader_options,
            onSelected: (value) {
              switch (value) {
                case 'toc':
                  _showChapterList();
                case 'rename':
                  _renameFile();
                case 'search':
                  _showSearch();
                case 'reader':
                  setState(() => _readerVisible = !_readerVisible);
                case 'autoscroll':
                  setState(() => _autoScrollEnabled = !_autoScrollEnabled);
                case 'bookmode':
                  _setBookMode(!_bookMode);
                case 'annotations':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnnotationsScreen(filterEbookId: widget.ebook.id),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toc',
                child: ListTile(
                  leading: const Icon(Icons.list_alt_rounded),
                  title: Text(l10n.reader_tableOfContents),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'annotations',
                child: ListTile(
                  leading: const Icon(Icons.border_color_rounded),
                  title: Text(l10n.reader_annotationsOfThisBook),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'search',
                child: ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: Text(l10n.reader_search),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline_rounded),
                  title: Text(l10n.reader_renameFileTitle),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'reader',
                child: ListTile(
                  leading: Icon(_readerVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  title: Text(
                      _readerVisible ? l10n.reader_hideReader : l10n.reader_showReader),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'bookmode',
                child: ListTile(
                  leading: Icon(_bookMode
                      ? Icons.view_day_rounded
                      : Icons.auto_stories_rounded),
                  title: Text(_bookMode ? l10n.reader_scrollMode : l10n.reader_bookMode),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'autoscroll',
                child: ListTile(
                  leading: Icon(_autoScrollEnabled
                      ? Icons.sync_disabled_rounded
                      : Icons.sync_rounded),
                  title: Text(_autoScrollEnabled
                      ? l10n.reader_disableAutoScroll
                      : l10n.reader_enableAutoScroll),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
          )
          : null,
      floatingActionButton: _readerVisible
          ? null
          // Lecteur masqué : œil ouvert en bas à droite pour le réafficher.
          : FloatingActionButton.small(
              onPressed: () => setState(() => _readerVisible = true),
              tooltip: l10n.reader_showReader,
              backgroundColor: Colors.black54,
              child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 20),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      body: Column(
        children: [
          // ── Texte + bouton de retour ─────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                if (_bookMode) _buildBookView(context) else
                ValueListenableBuilder<double>(
                  valueListenable: fontSizeNotifier,
                  builder: (context, fontSize, _) => ValueListenableBuilder<String?>(
                    valueListenable: fontFamilyNotifier,
                    builder: (context, fontFamily, _) => ValueListenableBuilder<double>(
                    valueListenable: readerMarginNotifier,
                    builder: (context, readerMargin, _) => NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: ScrollablePositionedList.builder(
                  // scrollable_positioned_list mesure et met en cache la
                  // hauteur de chaque item au fur et à mesure qu'il est
                  // construit. Un changement de taille/police de texte
                  // modifie la hauteur de TOUS les paragraphes d'un coup,
                  // mais les items déjà mis en cache (visibles ou non)
                  // gardent leur ancienne hauteur tant qu'ils ne sont pas
                  // reconstruits — le calcul de position du package devient
                  // incohérent entre items "neuve taille" et "vieille
                  // taille", ce qui faisait se chevaucher des paragraphes
                  // voisins à l'écran (les fameuses lignes qui traversaient
                  // les phrases). Une clé qui change avec la taille/police
                  // force Flutter à détruire et reconstruire tout le widget
                  // — donc tout le cache d'extents — plutôt que d'essayer de
                  // réconcilier un mélange d'anciennes et de nouvelles
                  // mesures.
                  key: ValueKey('list_${fontSize}_$fontFamily'),
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  // En mode "texte seul" (contrôles masqués via l'œil), on
                  // laisse plus d'air en haut (zone de sécurité, pas
                  // d'AppBar, + la marge réglable ci-dessous) et en bas
                  // (au-dessus de la barre de progression réduite), pour
                  // que le texte ne colle pas aux bords de l'écran. Réglage
                  // dans Profil > Texte > "Marge en mode texte seul" —
                  // toujours peint dans la couleur de fond du thème actuel
                  // puisque c'est juste du padding sur le Scaffold.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    _readerVisible ? 16 : MediaQuery.of(context).padding.top + readerMargin,
                    16,
                    _readerVisible ? 24 : readerMargin,
                  ),
                  initialScrollIndex: _findDisplayIndex(_currentGlobalIndex).clamp(0, _displayItems.length - 1),
                  itemCount: _displayItems.length,
                  itemBuilder: (context, index) {
                    final item = _displayItems[index];

                    if (item is _ChapterHeader) {
                      return _buildChapterHeader(context, item);
                    }

                    final para = item as _ParagraphItem;
                    final paraKey = _sentenceKeys[para.sentenceIndices.first];
                    return _buildParagraphWidget(para, paraKey, context);
                  },
                  ),
                    ),
                  ),
                  ),
                ),

                // ── Bulle de traduction en direct ─────────────────────────
                if (_translationModeEnabled) _buildTranslationBubble(context),

                // ── Bouton "Retour au texte en cours" ─────────────────────
                if (_showReturnButton)
                  Positioned(
                    // La barre de progression reste toujours affichée en bas
                    // (voir plus bas), donc le texte est toujours contraint
                    // au-dessus d'elle : plus besoin de compenser la zone de
                    // sécurité ici, que les contrôles soient visibles ou non.
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _returnToCurrent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder(
                                valueListenable: _itemPositionsListener.itemPositions,
                                builder: (context, _, __) => Icon(
                                  _isCurrentAbove
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Retour au texte en cours',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // ── Barre de confirmation de sélection ───────────────────
                // Dans le même Stack que le texte (pas le Column parent) :
                // voir le commentaire sur _buildSelectionBar.
                _buildSelectionBar(),
              ],
            ),
          ),

          // ── Contrôles fixes en bas ───────────────────────────────────────
          // Toujours affiché, au moins pour la barre de progression + le
          // chrono : même en mode "texte seul" (œil désactivé), on garde la
          // progression du livre visible. Seuls les contrôles de lecture
          // complets (voix, précédent/lecture/suivant, vitesse) se masquent
          // avec _readerVisible, un peu plus bas.
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barre de navigation façon YouTube : glisser pour parcourir
                // rapidement tout le livre. onChanged met juste à jour
                // l'affichage (curseur + chrono) ; le vrai saut de lecture
                // n'a lieu qu'au relâchement (onChangeEnd), pour ne pas
                // spammer playSentenceAt pendant le glissement.
                if (_sentences.length > 1)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: (_scrubberPreviewIndex ?? _currentGlobalIndex.toDouble())
                          .clamp(0.0, (_sentences.length - 1).toDouble()),
                      min: 0,
                      max: (_sentences.length - 1).toDouble(),
                      onChanged: (v) => setState(() => _scrubberPreviewIndex = v),
                      onChangeEnd: (v) {
                        final idx = v.round();
                        setState(() => _scrubberPreviewIndex = null);
                        // Navigue seulement jusqu'au texte visé, sans lancer
                        // la lecture — pour parcourir le livre sans
                        // interrompre ce qui est en train d'être lu. La
                        // lecture démarre en tapant directement une phrase
                        // dans le texte (déjà possible).
                        final wasElsewhere = idx != _currentGlobalIndex;
                        _scrollToSentence(idx).then((_) {
                          if (mounted && wasElsewhere) {
                            setState(() => _showReturnButton = true);
                          }
                        });
                      },
                    ),
                  ),
                // Chronomètre : temps déjà écouté / temps total estimé du
                // livre (estimation basée sur un rythme de lecture moyen,
                // ajusté à la vitesse de lecture choisie). Suit le curseur
                // de navigation pendant qu'on glisse.
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_formatDuration(_elapsedReadingEstimate)} / ${_formatDuration(_totalReadingEstimate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
                if (_readerVisible) Row(
                  children: [
                    // Sélecteur de voix : pastille circulaire, en bas à
                    // gauche, qui ouvre un panneau complet (la lecture
                    // continue pendant qu'on choisit). Légèrement décalée
                    // vers la droite et le haut.
                    Transform.translate(
                      offset: const Offset(10, -8),
                      child: GestureDetector(
                      onTap: availableVoices.isEmpty ? _openVoiceDownloads : _showVoicePicker,
                      child: ClipOval(
                        child: availableVoices.any((v) => v.name == selectedVoice)
                            ? VoiceAvatar(
                                character: characterForVoice(selectedVoice),
                                size: 56,
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[300],
                                child: const Icon(Icons.record_voice_over_rounded),
                              ),
                      ),
                      ),
                    ),
                    // Contrôles centrés
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Espace symétrique de celui de l'œil à droite :
                          // les contrôles restent centrés.
                          const Expanded(child: SizedBox()),
                          IconButton(
                            onPressed: _currentGlobalIndex > 0 && !_isSynthesizing
                                ? () => audioHandler?.playSentenceAt(_currentGlobalIndex - 1)
                                : null,
                            icon: const Icon(Icons.skip_previous_rounded),
                            iconSize: 36,
                            tooltip: AppLocalizations.of(context)!.reader_previousSentence,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                                    onPressed: _togglePlayPause,
                                    icon: _isSynthesizing && _wantsToPlay
                                        // Chargement en cours (et on veut jouer) : spinner
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                            ),
                                          )
                                        : Icon(
                                            _wantsToPlay
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                          ),
                                    iconSize: 36,
                                    tooltip: _wantsToPlay
                                        ? AppLocalizations.of(context)!.reader_pause
                                        : AppLocalizations.of(context)!.reader_play,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _currentGlobalIndex < _sentences.length - 1 &&
                                    !_isSynthesizing
                                ? () => audioHandler?.playSentenceAt(_currentGlobalIndex + 1)
                                : null,
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: 36,
                            tooltip: AppLocalizations.of(context)!.reader_nextSentence,
                          ),
                          // Masquer le lecteur : centré entre « phrase
                          // suivante » et le bouton de vitesse.
                          Expanded(
                            child: Center(
                              child: IconButton(
                                onPressed: () => setState(() => _readerVisible = false),
                                icon: const Icon(Icons.visibility_off_rounded),
                                iconSize: 24,
                                visualDensity: VisualDensity.compact,
                                color: Theme.of(context).colorScheme.primary,
                                tooltip: AppLocalizations.of(context)!.reader_hideReader,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bouton vitesse à droite
                    GestureDetector(
                      onTap: _showSpeedDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_playbackSpeed % 1 == 0 ? _playbackSpeed.toInt() : _playbackSpeed}x',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _saveProgress(); // sauvegarder en quittant l'écran
    // Sauvegarder le temps de lecture si l'utilisateur ferme sans pauser
    if (_readingStopwatch.isRunning) {
      _readingStopwatch.stop();
      _flushReadingTime();
    }
    audioHandler?.currentIndexNotifier.removeListener(_onHandlerIndexChanged);
    audioHandler?.isSynthesizingNotifier.removeListener(_onHandlerSynthesizingChanged);
    audioHandler?.shouldBePlayingNotifier.removeListener(_onHandlerWantsToPlayChanged);
    fontSizeNotifier.removeListener(_onFontChanged);
    fontFamilyNotifier.removeListener(_onFontChanged);
    _playerStateSub?.cancel();
    _selectionRangeNotifier.dispose();
    _selectionBubbleEntry?.remove();
    _selectionBubbleNotifier.dispose();
    // On ne reset plus jamais ici, même en pause — sinon la session (et donc
    // le mini-lecteur affiché sur les autres onglets) disparaît dès qu'on
    // quitte le livre sans être en train de lire. La session est de toute
    // façon remplacée proprement au prochain startSession() (même livre ou
    // un autre).
    super.dispose();
  }
}
