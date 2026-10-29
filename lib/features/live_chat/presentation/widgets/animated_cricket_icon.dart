import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class AnimatedCricketIcon extends StatefulWidget {
  const AnimatedCricketIcon({
    super.key,
    this.size = 30,
  });

  final double size;

  @override
  State<AnimatedCricketIcon> createState() => _AnimatedCricketIconState();
}

class _AnimatedCricketIconState extends State<AnimatedCricketIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _CricketIconPainter(_controller)),
      ),
    );
  }
}

class _CricketIconPainter extends CustomPainter {
  _CricketIconPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  // Timeline (0..1 of one loop).
  static const double _bounceAt = 0.26;
  static const double _contact = 0.50;
  static const double _flightEnd = 0.82;

  // Geometry in a 32x32 drawing space (y grows downward).
  static const double _groundY = 28.2;
  static const Offset _pivot = Offset(16, 11); // the batter's hands
  static const Offset _ballStart = Offset(36, 4);
  static const Offset _bounce = Offset(27.5, 25.9);
  static const Offset _contactPoint = Offset(21.5, 21.1);
  static const double _ballRadius = 2.1;

  // Bat angle in radians. 0 = hanging straight down.
  // Positive = tip swings back toward the stumps (left),
  // negative = tip swings forward (right) and up.
  static const double _stance = 0.05;
  static const double _backlift = 0.95;
  static const double _atContact = -0.5;
  static const double _followThrough = -2.1;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _batAngle(double t) {
    if (t < 0) t = 0;
    if (t < 0.12) return _stance;
    if (t < 0.34) {
      // Lift the bat back.
      return _lerp(
        _stance,
        _backlift,
        Curves.easeInOut.transform((t - 0.12) / 0.22),
      );
    }
    if (t < _contact) {
      // Fast downswing into the ball.
      return _lerp(
        _backlift,
        _atContact,
        Curves.easeInCubic.transform((t - 0.34) / (_contact - 0.34)),
      );
    }
    if (t < 0.68) {
      // Follow-through over the front shoulder.
      return _lerp(
        _atContact,
        _followThrough,
        Curves.easeOutCubic.transform((t - _contact) / 0.18),
      );
    }
    if (t < 0.74) return _followThrough;
    if (t < 0.95) {
      // Return to the stance.
      return _lerp(
        _followThrough,
        _stance,
        Curves.easeInOutCubic.transform((t - 0.74) / 0.21),
      );
    }
    return _stance;
  }

  static Offset? _ballPos(double t) {
    if (t < _bounceAt) {
      // Bowled from the right, dropping onto the pitch.
      final p = Curves.easeIn.transform(t / _bounceAt);
      return Offset.lerp(_ballStart, _bounce, p);
    }
    if (t < _contact) {
      // Bounces up toward the bat.
      final p = (t - _bounceAt) / (_contact - _bounceAt);
      return Offset(
        _lerp(_bounce.dx, _contactPoint.dx, p),
        _lerp(_bounce.dy, _contactPoint.dy, Curves.easeOut.transform(p)),
      );
    }
    if (t < _flightEnd) {
      // Lofted drive.
      final p = (t - _contact) / (_flightEnd - _contact);
      final x = _contactPoint.dx + 14 * Curves.easeOut.transform(p);
      final y = _contactPoint.dy - 22 * p + 6 * p * p;
      return Offset(x, y);
    }
    return null;
  }

  static double _ballOpacity(double t) {
    if (t < _contact) return 1;
    if (t < _flightEnd) {
      final p = (t - _contact) / (_flightEnd - _contact);
      return 1 - ((p - 0.45) / 0.55).clamp(0.0, 1.0).toDouble();
    }
    return 0;
  }

  static double _ballScale(double t) {
    if (t < _contact || t >= _flightEnd) return 1;
    final p = (t - _contact) / (_flightEnd - _contact);
    return _lerp(1, 0.55, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;

    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);

    _drawGround(canvas);
    _drawStumps(canvas);

    final angle = _batAngle(t);

    // Motion-blur ghosts while the bat is moving fast.
    if (t > 0.34 && t < 0.62) {
      for (var k = 3; k >= 1; k--) {
        final ghost = _batAngle(t - k * 0.012);
        if ((ghost - angle).abs() > 0.08) {
          _drawBat(canvas, ghost, ghostAlpha: 0.20 / k);
        }
      }
    }

    _drawBat(canvas, angle);
    _drawImpact(canvas, t);

    final opacity = _ballOpacity(t);
    final scale = _ballScale(t);

    // Trail behind the struck ball.
    if (t >= _contact && t < _flightEnd) {
      for (var k = 4; k >= 1; k--) {
        final tt = t - k * 0.02;
        if (tt < _contact) continue;
        final pos = _ballPos(tt);
        if (pos == null) continue;
        _drawBall(
          canvas,
          pos,
          _ballRadius * scale * (1 - k * 0.12),
          opacity * (0.34 - k * 0.07),
          0,
        );
      }
    }

    final ball = _ballPos(t);
    if (ball != null) {
      _drawBall(canvas, ball, _ballRadius * scale, opacity, t * 16);
    }

    canvas.restore();
  }

  void _drawGround(Canvas canvas) {
    canvas.drawLine(
      const Offset(1, _groundY),
      const Offset(31, _groundY),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawStumps(Canvas canvas) {
    final stump = Paint()
      ..color = const Color(0xFFC79B5A)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (final x in const [2.6, 4.4, 6.2]) {
      canvas.drawLine(Offset(x, 18.8), Offset(x, _groundY), stump);
    }

    // Bails.
    canvas.drawLine(
      const Offset(2.1, 18.2),
      const Offset(6.7, 18.2),
      Paint()
        ..color = const Color(0xFFF1D9A8)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBat(Canvas canvas, double angle, {double? ghostAlpha}) {
    canvas.save();
    canvas.translate(_pivot.dx, _pivot.dy);
    canvas.rotate(angle);

    // Blade points down from the hands.
    final blade = Path()
      ..moveTo(-1.1, 5)
      ..lineTo(-2.3, 7.2)
      ..lineTo(-2.4, 14)
      ..quadraticBezierTo(-2.4, 15.6, 0, 15.6)
      ..quadraticBezierTo(2.4, 15.6, 2.4, 14)
      ..lineTo(2.3, 7.2)
      ..lineTo(1.1, 5)
      ..close();

    if (ghostAlpha != null) {
      canvas.drawPath(
        blade,
        Paint()..color = const Color(0xFFD9A85F).withValues(alpha: ghostAlpha),
      );
      canvas.restore();
      return;
    }

    // Handle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-0.9, -3.4, 0.9, 5.4),
        const Radius.circular(0.8),
      ),
      Paint()..color = const Color(0xFF74543D),
    );

    // Blade.
    canvas.drawPath(blade, Paint()..color = const Color(0xFFD9A85F));
    canvas.drawPath(
      blade,
      Paint()
        ..color = const Color(0xFF8B642F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..strokeJoin = StrokeJoin.round,
    );

    // Ridge highlight.
    canvas.drawLine(
      const Offset(0, 8),
      const Offset(0, 14.4),
      Paint()
        ..color = const Color(0xFFFFEBC2).withValues(alpha: 0.85)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );

    // Gloved hands on the handle.
    canvas.drawCircle(
      const Offset(0, 0.3),
      1.9,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      const Offset(-0.5, -0.3),
      0.6,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    canvas.restore();
  }

  void _drawBall(
      Canvas canvas,
      Offset center,
      double radius,
      double alpha,
      double spin,
      ) {
    if (alpha <= 0 || radius <= 0) return;
    final a = alpha.clamp(0.0, 1.0).toDouble();

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.accent.withValues(alpha: a),
    );

    // Spinning seam.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * 0.68),
      -0.9,
      1.8,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: a * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.24
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// Spark burst at the moment the bat meets the ball.
  void _drawImpact(Canvas canvas, double t) {
    if (t < _contact || t > 0.62) return;
    final p = (t - _contact) / 0.12;

    final paint = Paint()
      ..color = const Color(0xFFFFB300)
          .withValues(alpha: (1 - p).clamp(0.0, 1.0).toDouble())
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 7; i++) {
      final a = -2.2 + i * 0.45; // fans up and to the right
      final dir = Offset(math.cos(a), math.sin(a));
      final r0 = 2.6 + 2.8 * p;
      final r1 = r0 + 1.1 + 2.0 * (1 - p);
      canvas.drawLine(
        _contactPoint + dir * r0,
        _contactPoint + dir * r1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CricketIconPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}