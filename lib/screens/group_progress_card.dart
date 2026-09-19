import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';

class GroupProgressCard extends StatelessWidget {
  final int streak;
  final int memberCount;
  final List<bool>? week; // Mon..Sun, null while loading
  final VoidCallback? onTap;

  const GroupProgressCard({
    super.key,
    required this.streak,
    required this.memberCount,
    this.week,
    this.onTap,
  });

  static const _tint = Color(0xFFEDEBFB);

  Widget _pill(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(20)),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayIdx = DateTime.now().weekday - 1;
    final w = week;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: softCard(radius: 22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Group Progress',
                      style: GoogleFonts.schoolbell(
                          fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                ),
                _pill(Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.purple),
                  const SizedBox(width: 6),
                  Text('$memberCount ${memberCount == 1 ? 'Member' : 'Members'}',
                      style: GoogleFonts.nunito(
                          fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.purple)),
                ])),
              ],
            ),
            const SizedBox(height: 8),
            FlameStreak(streak: streak),
            const SizedBox(height: 4),
            _pill(Text('day streak',
                style: GoogleFonts.schoolbell(fontSize: 16, color: AppColors.purple))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final done = w != null && i < w.length && w[i];
                return Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.purple : Colors.transparent,
                        border: Border.all(
                            color: done ? AppColors.purple : const Color(0xFFD9D6F5), width: 2),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i],
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: i == todayIdx ? FontWeight.w900 : FontWeight.w700,
                          color: i == todayIdx ? AppColors.purple : AppColors.sub,
                        )),
                  ],
                );
              }),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("See today's progress",
                      style: GoogleFonts.nunito(
                          fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.purple)),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.purple),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class FlameStreak extends StatelessWidget {
  final int streak;
  final double width;

  const FlameStreak({super.key, required this.streak, this.width = 150});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.2;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _FlamePainter())),
          Align(
            alignment: const Alignment(0, 0.53),
            child: SizedBox(
              width: width * 0.4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$streak',
                    style: GoogleFonts.nunito(
                        fontSize: width * 0.24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  static const _segs = <List<double>>[
    [50, 236, 12, 202, 12, 152],
    [12, 128, 24, 112, 36, 98],
    [38, 108, 44, 116, 54, 120],
    [52, 96, 66, 76, 84, 62],
    [98, 50, 108, 32, 100, 6],
    [124, 24, 148, 50, 150, 96],
    [158, 94, 166, 88, 172, 76],
    [184, 96, 190, 124, 190, 152],
    [190, 202, 150, 236, 100, 236],
  ];

  Path _flame(double scale, double anchorY) {
    Offset tf(double x, double y) =>
        Offset(100 + (x - 100) * scale, anchorY + (y - anchorY) * scale);

    final start = tf(100, 236);
    final p = Path()..moveTo(start.dx, start.dy);
    for (final s in _segs) {
      final a = tf(s[0], s[1]);
      final b = tf(s[2], s[3]);
      final c = tf(s[4], s[5]);
      p.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
    return p..close();
  }

  Paint _grad(Color top, Color bottom) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ).createShader(const Rect.fromLTWH(0, 0, 200, 240));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 240);

    final outer = _flame(1.0, 236);
    canvas.drawPath(outer, _grad(const Color(0xFFFF5A36), const Color(0xFFFF9A3C)));
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF8E1B12),
    );
    canvas.drawPath(_flame(0.80, 230), _grad(const Color(0xFFFFB02E), const Color(0xFFFFD36B)));
    canvas.drawPath(_flame(0.60, 226), Paint()..color = const Color(0xFFFFF3C9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
