import 'package:flutter/material.dart';

import '../theme/talktome_theme.dart';

/// Tomy, la mascotte TalkTome : un grimoire violet qui porte son signet rouge
/// comme une cape. Flotte doucement (désactivable avec [floating]).
class Tomy extends StatefulWidget {
  final double size;
  final bool floating;
  const Tomy({super.key, this.size = 120, this.floating = true});

  static const asset = 'assets/branding/tomy.png';

  @override
  State<Tomy> createState() => _TomyState();
}

class _TomyState extends State<Tomy> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.floating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      Tomy.asset,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    if (!widget.floating) return image;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -widget.size * 0.04 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.05, child: child),
        );
      },
      child: image,
    );
  }
}

/// Tomy avec une bulle de dialogue à sa droite.
class TomySays extends StatelessWidget {
  final String title;
  final String message;
  final double tomySize;
  const TomySays({
    super.key,
    required this.title,
    required this.message,
    this.tomySize = 96,
  });

  @override
  Widget build(BuildContext context) {
    final dark = TT.isDark(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = TT.accent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tomy(size: tomySize),
          const SizedBox(width: 4),
          Expanded(
            child: CustomPaint(
              painter: _BubbleTailPainter(
                color: dark ? TT.surfaceHigh : Colors.white,
                border: accent.withOpacity(0.45),
              ),
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: dark ? TT.surfaceHigh : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: (dark ? TT.purple : TT.goldDeep).withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: scheme.onSurface.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color border;
  _BubbleTailPainter({required this.color, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()
      ..moveTo(11, y - 9)
      ..lineTo(0, y)
      ..lineTo(11, y + 9)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(11, y - 9)
        ..lineTo(0, y)
        ..lineTo(11, y + 9),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.color != color || old.border != border;
}

/// État vide avec Tomy à la place d'une icône grise.
class TomyEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final double size;
  const TomyEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Tomy(size: size),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: TT.accent(context),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
