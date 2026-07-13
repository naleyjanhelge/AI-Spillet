import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'prompt_heist_theme.dart';

class AnimatedGameBackground extends StatefulWidget {
  const AnimatedGameBackground({
    super.key,
    required this.child,
    this.accent,
    this.artOpacity = .58,
  });

  final Widget child;
  final Color? accent;
  final double artOpacity;

  @override
  State<AnimatedGameBackground> createState() => _AnimatedGameBackgroundState();
}

class _AnimatedGameBackgroundState extends State<AnimatedGameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.voidBlack,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final wave = math.sin(_controller.value * math.pi * 2);
                return Transform.scale(
                  scale: 1.07 + wave * .018,
                  alignment: Alignment(wave * .08, -.25),
                  child: child,
                );
              },
              child: Opacity(
                opacity: widget.artOpacity,
                child: Image.asset(
                  'assets/images/nox_vault_environment.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.voidBlack.withValues(alpha: .18),
                    AppColors.deepSpace.withValues(alpha: .52),
                    AppColors.voidBlack.withValues(alpha: .95),
                  ],
                  stops: const [0, .48, 1],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(
                painter: _VaultFxPainter(
                  _controller.value,
                  widget.accent ?? AppColors.ultraviolet,
                ),
                child: child,
              ),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultFxPainter extends CustomPainter {
  const _VaultFxPainter(this.progress, this.accent);
  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final scanline = Paint()
      ..color = Colors.white.withValues(alpha: .012)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        scanline,
      );
    }
    final beamY = (progress * (size.height + 180)) - 90;
    final beam = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          accent.withValues(alpha: .055),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, beamY - 70, size.width, 140));
    canvas.drawRect(Rect.fromLTWH(0, beamY - 70, size.width, 140), beam);
    _NetworkPainter(progress, accent).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _VaultFxPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter(this.progress, this.accent);
  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = accent.withValues(alpha: .055)
      ..strokeWidth = 1;
    final glow = Paint()
      ..color = accent.withValues(alpha: .3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    const count = 18;
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final seed = i * 2.417;
      final x =
          ((math.sin(seed + progress * math.pi * 2) + 1) / 2) * size.width;
      final y = ((i * 83.0 + progress * 64) % (size.height + 100)) - 50;
      points.add(Offset(x, y));
    }
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        if ((points[i] - points[j]).distance < 130) {
          canvas.drawLine(points[i], points[j], line);
        }
      }
      canvas.drawCircle(points[i], i.isEven ? 1.5 : 1, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = ClipPath(
      clipper: const AngularClipper(cut: 14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: CustomPaint(
          foregroundPainter: _AngularBorderPainter(
            color:
                borderColor?.withValues(alpha: .58) ??
                Colors.white.withValues(alpha: .1),
            cut: 14,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .78),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .045),
                  AppColors.surface.withValues(alpha: .76),
                  (borderColor ?? AppColors.ultraviolet).withValues(
                    alpha: .055,
                  ),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (onTap == null) return panel;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: panel),
    );
  }
}

class AngularClipper extends CustomClipper<Path> {
  const AngularClipper({required this.cut});
  final double cut;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(cut, 0)
    ..lineTo(size.width - cut, 0)
    ..lineTo(size.width, cut)
    ..lineTo(size.width, size.height - cut)
    ..lineTo(size.width - cut, size.height)
    ..lineTo(cut, size.height)
    ..lineTo(0, size.height - cut)
    ..lineTo(0, cut)
    ..close();

  @override
  bool shouldReclip(covariant AngularClipper oldClipper) =>
      oldClipper.cut != cut;
}

class _AngularBorderPainter extends CustomPainter {
  const _AngularBorderPainter({required this.color, required this.cut});
  final Color color;
  final double cut;

  @override
  void paint(Canvas canvas, Size size) {
    final path = AngularClipper(cut: cut).getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
    final corner = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.square
      ..color = color.withValues(alpha: .9);
    canvas.drawLine(Offset(cut, 0), Offset(cut + 28, 0), corner);
    canvas.drawLine(
      Offset(size.width - cut - 28, size.height),
      Offset(size.width - cut, size.height),
      corner,
    );
  }

  @override
  bool shouldRepaint(covariant _AngularBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cut != cut;
}

class NoxAvatar extends StatefulWidget {
  const NoxAvatar({super.key, this.size = 72, this.active = true});
  final double size;
  final bool active;

  @override
  State<NoxAvatar> createState() => _NoxAvatarState();
}

class _NoxAvatarState extends State<NoxAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = widget.active ? .22 + _controller.value * .25 : .08;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _controller.value * math.pi * 2,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _NoxRingPainter(
                    AppColors.cyan.withValues(alpha: .55),
                  ),
                ),
              ),
              Container(
                width: widget.size * .84,
                height: widget.size * .84,
                padding: EdgeInsets.all(widget.size * .024),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.ultraviolet, AppColors.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ultraviolet.withValues(alpha: pulse),
                      blurRadius: widget.size * .34,
                      spreadRadius: widget.size * .03,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/nox_guardian.png',
                    fit: BoxFit.cover,
                    color: widget.active
                        ? null
                        : Colors.black.withValues(alpha: .5),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoxRingPainter extends CustomPainter {
  const _NoxRingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .47;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius),
      2.2,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius),
      1.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _NoxRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: onPressed == null ? .45 : 1,
      duration: const Duration(milliseconds: 200),
      child:
          DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ultraviolet.withValues(alpha: .24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipPath(
                  clipper: const AngularClipper(cut: 10),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.ultraviolet,
                          Color(0xFF5530D2),
                          AppColors.cyan,
                        ],
                      ),
                    ),
                    child: FilledButton.icon(
                      onPressed: onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 22,
                          vertical: compact ? 12 : 17,
                        ),
                        shape: const RoundedRectangleBorder(),
                      ),
                      icon: Icon(icon, size: 20),
                      label: Text(label.toUpperCase()),
                    ),
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shimmer(
                duration: 2200.ms,
                color: Colors.white.withValues(alpha: .18),
              ),
    );
  }
}
