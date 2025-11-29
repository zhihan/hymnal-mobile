import 'package:flutter/material.dart';
import '../models/hymn_song.dart';
import '../models/line.dart';
import '../models/segment.dart';
import '../utils/chord_transposer.dart';

/// Widget to display a full hymn with chords and lyrics
class HymnDisplay extends StatelessWidget {
  final HymnSong hymn;
  final int transposeOffset;

  const HymnDisplay({
    super.key,
    required this.hymn,
    this.transposeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Title
          Text(
            hymn.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          // Metadata
          if (hymn.metadata != null) ...[
            Text(
              'Time: ${hymn.metadata!['time'] ?? ''} | Category: ${hymn.metadata!['category'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
          ],

          // Lines with segments
          ...hymn.lines.map((line) => LineDisplay(
                line: line,
                transposeOffset: transposeOffset,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to display a single line with its segments
class LineDisplay extends StatelessWidget {
  final Line line;
  final int transposeOffset;

  const LineDisplay({
    super.key,
    required this.line,
    this.transposeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Check if this line has any chords
    final hasAnyChords = line.segments.any((segment) => segment.chord.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: line.segments.map((segment) {
          return SegmentDisplay(
            segment: segment,
            showChordSpace: hasAnyChords,
            transposeOffset: transposeOffset,
          );
        }).toList(),
      ),
    );
  }
}

/// Widget to display a single segment (chord above text)
class SegmentDisplay extends StatelessWidget {
  final Segment segment;
  final bool showChordSpace;
  final int transposeOffset;

  const SegmentDisplay({
    super.key,
    required this.segment,
    required this.showChordSpace,
    this.transposeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasChord = segment.chord.isNotEmpty;

    // Apply transpose to chord if necessary
    final displayChord = hasChord && transposeOffset != 0
        ? ChordTransposer.transposeSegmentChord(segment.chord, transposeOffset)
        : segment.chord;

    return Padding(
      padding: const EdgeInsets.only(right: 2.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chord (or empty space to maintain alignment) - only show if line has chords
          if (showChordSpace)
            SizedBox(
              height: 18,
              child: hasChord
                  ? Text(
                      displayChord,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2), // Blue color for chords
                        height: 1.0,
                      ),
                    )
                  : null,
            ),
          // Lyrics text
          Text(
            segment.text,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
