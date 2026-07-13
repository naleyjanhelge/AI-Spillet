import 'package:flutter/material.dart';

import 'prompt_heist_theme.dart';

/// Spoiler-free data shown on a completed-room share card.
///
/// There is deliberately no solution, clue, protocol, or secret field here.
/// [spoilerTerms] is a final safety net for player-facing text such as the
/// NOX quote. Matching terms are replaced before anything is painted.
@immutable
class CompletionShareCardData {
  const CompletionShareCardData({
    required this.chapterNumber,
    required this.chapterTitle,
    required this.roomNumber,
    required this.roomTitle,
    required this.stars,
    required this.prompts,
    required this.hintsUsed,
    required this.noxQuote,
    this.achievement = 'ROOM BREACHED',
    this.rank,
    this.roomArt = const AssetImage('assets/images/nox_vault_environment.png'),
    this.accent = AppColors.cyan,
    this.spoilerTerms = const <String>[],
  }) : assert(chapterNumber > 0),
       assert(roomNumber > 0),
       assert(stars >= 1 && stars <= 3),
       assert(prompts >= 0),
       assert(hintsUsed >= 0);

  final int chapterNumber;
  final String chapterTitle;
  final int roomNumber;
  final String roomTitle;
  final int stars;
  final int prompts;
  final int hintsUsed;
  final String noxQuote;
  final String achievement;
  final String? rank;
  final ImageProvider<Object> roomArt;
  final Color accent;
  final List<String> spoilerTerms;

  int get hintPenalty => hintsUsed * 2;
  int get effectiveStrokes => prompts + hintPenalty;

  String spoilerSafe(String value) {
    var safeValue = value;
    for (final term in spoilerTerms) {
      final trimmed = term.trim();
      if (trimmed.isEmpty) continue;
      safeValue = safeValue.replaceAll(
        RegExp(RegExp.escape(trimmed), caseSensitive: false),
        List.filled(trimmed.length.clamp(4, 12), '█').join(),
      );
    }
    return safeValue;
  }
}

/// A fixed-resolution 9:16 completion card suitable for [RepaintBoundary].
///
/// Render this widget at its natural 1080 x 1920 logical-pixel size with a
/// pixel ratio of 1.0 to produce an exact 1080 x 1920 PNG.
class CompletionShareCard extends StatelessWidget {
  const CompletionShareCard({super.key, required this.data});

  static const Size canvasSize = Size(1080, 1920);

  final CompletionShareCardData data;

  @override
  Widget build(BuildContext context) {
    final safeChapter = data.spoilerSafe(data.chapterTitle);
    final safeRoom = data.spoilerSafe(data.roomTitle);
    final safeAchievement = data.spoilerSafe(data.achievement);
    final safeQuote = data.spoilerSafe(data.noxQuote);
    final safeRank = data.rank == null ? null : data.spoilerSafe(data.rank!);

    return RepaintBoundary(
      child: SizedBox.fromSize(
        size: canvasSize,
        child: Material(
          color: AppColors.voidBlack,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _RoomArtwork(image: data.roomArt, accent: data.accent),
              const _ScanLines(),
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 76, 72, 70),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(accent: data.accent),
                    const Spacer(),
                    _AchievementBadge(
                      label: safeAchievement,
                      accent: data.accent,
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'CHAPTER ${data.chapterNumber}  /  $safeChapter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: data.accent,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.2,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      safeRoom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 76,
                        height: .96,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.8,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ROOM ${data.roomNumber.toString().padLeft(2, '0')} CLEARED',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 46),
                    _ScorePanel(data: data, rank: safeRank),
                    const SizedBox(height: 30),
                    _NoxQuote(quote: safeQuote, accent: data.accent),
                    const SizedBox(height: 42),
                    const _Footer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomArtwork extends StatelessWidget {
  const _RoomArtwork({required this.image, required this.accent});

  final ImageProvider<Object> image;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: image, fit: BoxFit.cover, alignment: Alignment.topCenter),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.voidBlack.withValues(alpha: .18),
                AppColors.deepSpace.withValues(alpha: .35),
                AppColors.voidBlack.withValues(alpha: .88),
                AppColors.voidBlack,
              ],
              stops: const [0, .31, .59, .78],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.72, -.72),
              radius: 1.05,
              colors: [accent.withValues(alpha: .3), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 66,
          height: 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 2),
            borderRadius: BorderRadius.circular(14),
            color: AppColors.voidBlack.withValues(alpha: .72),
          ),
          child: Text(
            'N',
            style: TextStyle(
              color: accent,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 22),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROMPT HEIST',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.8,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'HELIX-9 // INCIDENT RECORD',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.7,
                ),
              ),
            ],
          ),
        ),
        Container(width: 170, height: 2, color: accent.withValues(alpha: .65)),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .14),
          border: Border.all(color: accent.withValues(alpha: .85), width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .2),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.1,
          ),
        ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.data, required this.rank});

  final CompletionShareCardData data;
  final String? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .9),
        border: Border.all(color: Colors.white.withValues(alpha: .13)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Stars(count: data.stars, accent: data.accent),
              ),
              if (rank != null && rank!.trim().isNotEmpty)
                _Stat(label: 'GAME CENTER', value: rank!),
            ],
          ),
          const SizedBox(height: 28),
          Divider(color: Colors.white.withValues(alpha: .12), height: 1),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'PROMPTS',
                  value: data.prompts.toString(),
                  alignStart: true,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'HINT PENALTY',
                  value: '+${data.hintPenalty}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'STROKES',
                  value: data.effectiveStrokes.toString(),
                  emphasized: true,
                  accent: data.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(
            index < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 56,
            color: index < count
                ? accent
                : AppColors.textMuted.withValues(alpha: .46),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.alignStart = false,
    this.emphasized = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool alignStart;
  final bool emphasized;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: emphasized ? accent : AppColors.text,
            fontSize: emphasized ? 48 : 37,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
      ],
    );
  }
}

class _NoxQuote extends StatelessWidget {
  const _NoxQuote({required this.quote, required this.accent});

  final String quote;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
      decoration: BoxDecoration(
        color: AppColors.deepSpace.withValues(alpha: .86),
        border: Border(left: BorderSide(color: accent, width: 5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOX',
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Text(
              '“$quote”',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 29,
                height: 1.26,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'ESCAPE RECORD VERIFIED',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.7,
          ),
        ),
        const Spacer(),
        const Text(
          'OUTSMART NOX.',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.8,
          ),
        ),
      ],
    );
  }
}

class _ScanLines extends StatelessWidget {
  const _ScanLines();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _ScanLinePainter(), size: Size.infinite),
  );
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .018)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) => false;
}
