/// Utility class for transposing musical chords
class ChordTransposer {
  // Note order in chromatic scale
  static const List<String> _notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  // Alternative flat notations
  static const Map<String, String> _flatToSharp = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
  };

  /// Transpose a single chord by the given number of semitones
  /// Positive semitones transpose up, negative transpose down
  static String transposeChord(String chord, int semitones) {
    if (chord.isEmpty) return chord;

    // Normalize semitones to range [0, 11]
    semitones = semitones % 12;
    if (semitones < 0) semitones += 12;

    // Extract the root note and the rest of the chord (e.g., "Cm7" -> "C" + "m7")
    String rootNote = '';
    String suffix = '';

    // Check for two-character root notes (sharps and flats)
    if (chord.length >= 2 && (chord[1] == '#' || chord[1] == 'b')) {
      rootNote = chord.substring(0, 2);
      suffix = chord.substring(2);
    } else if (chord.isNotEmpty) {
      rootNote = chord.substring(0, 1);
      suffix = chord.substring(1);
    }

    // Convert flats to sharps for easier calculation
    if (_flatToSharp.containsKey(rootNote)) {
      rootNote = _flatToSharp[rootNote]!;
    }

    // Find the index of the root note
    int noteIndex = _notes.indexOf(rootNote);
    if (noteIndex == -1) {
      // If we can't parse the chord, return it unchanged
      return chord;
    }

    // Transpose by adding semitones and wrapping around
    int newIndex = (noteIndex + semitones) % 12;
    String newRootNote = _notes[newIndex];

    return newRootNote + suffix;
  }

  /// Transpose an entire segment's chord
  static String transposeSegmentChord(String chord, int semitones) {
    if (chord.isEmpty || semitones == 0) return chord;

    // Handle compound chords separated by slashes (e.g., "C/G")
    if (chord.contains('/')) {
      final parts = chord.split('/');
      return parts.map((part) => transposeChord(part.trim(), semitones)).join('/');
    }

    return transposeChord(chord, semitones);
  }
}
