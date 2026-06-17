import 'package:flutter/material.dart';

/// A virtual thumbstick widget for touch-based ship control.
/// Exposes [direction] as a normalised offset in the range -1..1 on each axis.
/// When the user lifts their finger the notifier resets to [Offset.zero].
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.direction,
    this.size = 120.0,
  });

  final ValueNotifier<Offset> direction;
  final double size;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knob = Offset.zero;

  static const double _knobRadius = 24.0;
  double get _maxRadius => widget.size / 2 - _knobRadius - 4;

  void _move(Offset local) {
    final Offset rel = local - Offset(widget.size / 2, widget.size / 2);
    final double mag = rel.distance;
    final Offset clamped =
        mag > _maxRadius ? rel / mag * _maxRadius : rel;
    setState(() => _knob = clamped);
    widget.direction.value =
        mag > 6 ? Offset(clamped.dx / _maxRadius, clamped.dy / _maxRadius) : Offset.zero;
  }

  void _reset() {
    setState(() => _knob = Offset.zero);
    widget.direction.value = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _move(d.localPosition),
      onPanUpdate: (d) => _move(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _JoystickPainter(_knob, widget.size, _knobRadius),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter(this.knob, this.size, this.knobRadius);

  final Offset knob;
  final double size;
  final double knobRadius;

  @override
  void paint(Canvas canvas, Size _) {
    final Offset c = Offset(size / 2, size / 2);
    final double baseR = size / 2 - 4;

    // Base fill
    canvas.drawCircle(c, baseR,
        Paint()..color = Colors.white.withOpacity(0.10));

    // Base ring
    canvas.drawCircle(
        c,
        baseR,
        Paint()
          ..color = Colors.white.withOpacity(0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // Cross-hair guides
    final Paint guide = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(c.dx, c.dy - baseR + 4),
        Offset(c.dx, c.dy + baseR - 4), guide);
    canvas.drawLine(Offset(c.dx - baseR + 4, c.dy),
        Offset(c.dx + baseR - 4, c.dy), guide);

    // Knob fill
    final Offset kc = c + knob;
    canvas.drawCircle(kc, knobRadius,
        Paint()..color = Colors.white.withOpacity(0.30));

    // Knob ring
    canvas.drawCircle(
        kc,
        knobRadius,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.knob != knob;
}
