import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/melody.dart';
import '../utils/guitar_fingering.dart';

class TablatureScreen extends StatefulWidget {
  final Melody melody;
  final String hymnTitle;
  final int initialCapo;
  final int transpose;

  const TablatureScreen({
    super.key,
    required this.melody,
    required this.hymnTitle,
    this.initialCapo = 0,
    this.transpose = 0,
  });

  @override
  State<TablatureScreen> createState() => _TablatureScreenState();
}

class _TablatureScreenState extends State<TablatureScreen> {
  late int _capo;

  @override
  void initState() {
    super.initState();
    _capo = widget.initialCapo.clamp(0, 12);
  }

  @override
  Widget build(BuildContext context) {
    final notes = GuitarFingering.arrange(
      widget.melody.notes,
      capo: _capo,
      transpose: widget.transpose,
    );
    final ticksPerMeasure = _ticksPerMeasure(widget.melody);
    final lastTick = widget.melody.notes.isEmpty
        ? 0
        : widget.melody.notes
              .map((note) => note.start + note.duration)
              .reduce(math.max);
    final rowCount = math.max(1, (lastTick / (ticksPerMeasure * 2)).ceil());

    return Scaffold(
      appBar: AppBar(title: Text('${widget.hymnTitle} · Tab')),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Capo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: _capo > 0 ? () => setState(() => _capo--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_capo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _capo < 12
                        ? () => setState(() => _capo++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  if (widget.transpose != 0) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Transpose ${widget.transpose > 0 ? '+' : ''}${widget.transpose}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rowCount,
              itemBuilder: (context, row) {
                final start = row * ticksPerMeasure * 2;
                final end = start + ticksPerMeasure * 2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 150,
                    child: CustomPaint(
                      painter: _TabPainter(
                        notes: notes,
                        startTick: start,
                        endTick: end,
                        measureTicks: ticksPerMeasure,
                        color: Theme.of(context).colorScheme.onSurface,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _ticksPerMeasure(Melody melody) {
    final numerator = melody.timeSignature.isNotEmpty
        ? melody.timeSignature[0]
        : 4;
    final denominator = melody.timeSignature.length > 1
        ? melody.timeSignature[1]
        : 4;
    return (melody.ticksPerBeat * numerator * 4 / denominator).round();
  }
}

class _TabPainter extends CustomPainter {
  final List<FingeredNote> notes;
  final int startTick;
  final int endTick;
  final int measureTicks;
  final Color color;
  final Color backgroundColor;

  const _TabPainter({
    required this.notes,
    required this.startTick,
    required this.endTick,
    required this.measureTicks,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelWidth = 22.0;
    const top = 16.0;
    const spacing = 22.0;
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
      color: color,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    for (var string = 1; string <= 6; string++) {
      final y = top + (string - 1) * spacing;
      canvas.drawLine(Offset(labelWidth, y), Offset(size.width, y), linePaint);
      _paintText(
        canvas,
        string == 1 || string == 6
            ? 'E'
            : ['', 'E', 'B', 'G', 'D', 'A', 'E'][string],
        0,
        y - 8,
        TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
      );
    }

    final tickSpan = endTick - startTick;
    for (var tick = startTick; tick <= endTick; tick += measureTicks) {
      final x =
          labelWidth +
          (tick - startTick) / tickSpan * (size.width - labelWidth);
      canvas.drawLine(Offset(x, top), Offset(x, top + spacing * 5), linePaint);
    }

    for (final fingered in notes) {
      if (fingered.note.start < startTick || fingered.note.start >= endTick)
        continue;
      final position = fingered.position;
      if (position == null) continue;
      final x =
          labelWidth +
          5 +
          (fingered.note.start - startTick) /
              tickSpan *
              (size.width - labelWidth - 10);
      final y = top + (position.stringNumber - 1) * spacing;
      final label = position.fret.toString();
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final background = Rect.fromCenter(
        center: Offset(x, y),
        width: painter.width + 5,
        height: painter.height,
      );
      canvas.drawRect(background, Paint()..color = backgroundColor);
      painter.paint(
        canvas,
        Offset(x - painter.width / 2, y - painter.height / 2),
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    double x,
    double y,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _TabPainter oldDelegate) =>
      oldDelegate.notes != notes ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}
