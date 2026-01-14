import 'package:flutter/material.dart';
import '../models/hymn_song.dart';
import '../models/verse.dart';
import '../models/line.dart';
import '../models/segment.dart';
import '../utils/chord_transposer.dart';
import '../utils/lyricist_formatter.dart';

/// Widget to display a full hymn with chords and lyrics
class HymnDisplay extends StatelessWidget {
  final HymnSong hymn;
  final int transposeOffset;
  final bool showChords;
  final String? hymnIdTag;
  final Function(String category)? onCategoryTap;
  final Function(String lyricist)? onLyricistTap;

  const HymnDisplay({
    super.key,
    required this.hymn,
    this.transposeOffset = 0,
    this.showChords = true,
    this.hymnIdTag,
    this.onCategoryTap,
    this.onLyricistTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth < 632 ? screenWidth : 600.0;

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      boundaryMargin: const EdgeInsets.all(100.0),
      constrained: false,
      panAxis: PanAxis.vertical,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: contentWidth,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              // Hymn ID tag and lyricist
              if (hymnIdTag != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0), // Dark blue background
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        hymnIdTag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hymn.metadata?['lyrics'] != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final lyricist = hymn.metadata!['lyrics'] as String;
                          if (onLyricistTap != null) {
                            onLyricistTap!(lyricist);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                LyricistFormatter.format(hymn.metadata!['lyrics'] as String?),
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: Colors.grey[800],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Metadata
              if (hymn.metadata != null) ...[
                Row(
                  children: [
                    // Capo (only if not 0)
                    if (hymn.metadata!['capo'] != null &&
                        hymn.metadata!['capo'] != 0) ...[
                      Text(
                        'Capo: ${hymn.metadata!['capo']}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const Text(' | ', style: TextStyle(color: Colors.grey)),
                    ],
                    // Time
                    Text(
                      'Time: ${hymn.metadata!['time'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const Text(' | ', style: TextStyle(color: Colors.grey)),
                    // Category
                    if (hymn.metadata!['category'] != null &&
                        hymn.metadata!['category'].toString().isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          final category = hymn.metadata!['category'] as String;
                          if (onCategoryTap != null) {
                            onCategoryTap!(category);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Category: ${hymn.metadata!['category']}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Category: ${hymn.metadata!['category'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Verses
              ...hymn.verses.asMap().entries.expand((entry) {
                final verseIndex = entry.key;
                final verse = entry.value;
                final List<Widget> widgets = [];

                // Add verse display
                widgets.add(VerseDisplay(
                  verse: verse,
                  transposeOffset: transposeOffset,
                  showChords: showChords,
                ));

                // Add spacing between verses (except after the last one)
                if (verseIndex < hymn.verses.length - 1) {
                  widgets.add(const SizedBox(height: 16));
                }

                return widgets;
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to display a single verse
class VerseDisplay extends StatelessWidget {
  final Verse verse;
  final int transposeOffset;
  final bool showChords;

  const VerseDisplay({
    super.key,
    required this.verse,
    this.transposeOffset = 0,
    this.showChords = true,
  });

  @override
  Widget build(BuildContext context) {
    // Check if this verse has any chords
    final hasAnyChords = verse.lines.any((line) =>
      line.segments.any((segment) => segment.chord.isNotEmpty)
    );

    // Determine what label to show
    String? label;
    TextStyle? labelStyle;

    if (verse.type == 'verse' && verse.number != null) {
      // Show verse number
      label = '${verse.number}.';
      labelStyle = const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      );
    } else if (verse.type == 'chorus') {
      // Show 'C.' in italics
      label = 'C.';
      labelStyle = const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.italic,
        color: Colors.black54,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verse number or chorus indicator
        if (label != null)
          Padding(
            padding: EdgeInsets.only(
              right: 12.0,
              top: (hasAnyChords && showChords) ? 20.0 : 0.0,
            ),
            child: SizedBox(
              width: 24,
              child: Text(
                label,
                style: labelStyle,
              ),
            ),
          ),

        // Lines
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: verse.lines
                .map((line) => LineDisplay(
                      line: line,
                      transposeOffset: transposeOffset,
                      showChords: showChords,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Widget to display a single line with its segments
class LineDisplay extends StatelessWidget {
  final Line line;
  final int transposeOffset;
  final bool showChords;

  const LineDisplay({
    super.key,
    required this.line,
    this.transposeOffset = 0,
    this.showChords = true,
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
            showChordSpace: hasAnyChords && showChords,
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
