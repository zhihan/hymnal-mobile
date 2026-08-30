import '../models/melody.dart';

class GuitarPosition {
  /// String number in normal tab notation: 1 is high E, 6 is low E.
  final int stringNumber;
  final int fret;

  const GuitarPosition(this.stringNumber, this.fret);
}

class FingeredNote {
  final MelodyNote note;
  final GuitarPosition? position;

  const FingeredNote(this.note, this.position);
}

class GuitarFingering {
  // MIDI pitches from low E to high E.
  static const _openStrings = [40, 45, 50, 55, 59, 64];

  static List<GuitarPosition> positionsForPitch(
    int pitch, {
    int capo = 0,
    int maxFret = 24,
  }) {
    final positions = <GuitarPosition>[];
    for (
      var lowToHighIndex = 0;
      lowToHighIndex < _openStrings.length;
      lowToHighIndex++
    ) {
      final fret = pitch - (_openStrings[lowToHighIndex] + capo);
      if (fret >= 0 && fret <= maxFret) {
        positions.add(GuitarPosition(6 - lowToHighIndex, fret));
      }
    }
    return positions;
  }

  /// Melody pitches are extracted at vocal (tune-line) pitch, which sits
  /// above where a standard-tuned guitar can be played in open position.
  /// Shift the whole melody down an octave so tabs land in a comfortable,
  /// idiomatic guitar register instead of climbing the upper frets.
  static const int _octaveShift = -12;

  /// Choose a playable path that favors staying within a narrow fret
  /// region and switching strings over sliding along one string.
  static List<FingeredNote> arrange(
    List<MelodyNote> notes, {
    int capo = 0,
    int transpose = 0,
    int maxFret = 24,
  }) {
    if (notes.isEmpty) return const [];

    final candidates = notes
        .map(
          (note) => positionsForPitch(
            note.pitch + transpose + _octaveShift,
            capo: capo,
            maxFret: maxFret,
          ),
        )
        .toList();
    final costs = <List<double>>[];
    final previous = <List<int>>[];

    for (var noteIndex = 0; noteIndex < notes.length; noteIndex++) {
      final positions = candidates[noteIndex];
      if (positions.isEmpty) {
        costs.add(const []);
        previous.add(const []);
        continue;
      }
      final noteCosts = List<double>.filled(positions.length, double.infinity);
      final notePrevious = List<int>.filled(positions.length, -1);

      for (
        var currentIndex = 0;
        currentIndex < positions.length;
        currentIndex++
      ) {
        final current = positions[currentIndex];
        // Open strings take no left-hand finger at all, so they're not
        // just "one fret cheaper" than fret 1 - they're categorically
        // easier. Reward them well beyond the linear per-fret cost below
        // so the arranger reaches for a nearby open string (e.g. fret 5
        // on one string is the same pitch as open on the next) instead of
        // fretting the equivalent note.
        final baseCost = current.fret == 0 ? -1.0 : current.fret * 0.08;
        if (noteIndex == 0 || candidates[noteIndex - 1].isEmpty) {
          noteCosts[currentIndex] = baseCost;
          continue;
        }
        for (
          var priorIndex = 0;
          priorIndex < candidates[noteIndex - 1].length;
          priorIndex++
        ) {
          final prior = candidates[noteIndex - 1][priorIndex];
          final movement = (current.fret - prior.fret).abs().toDouble();
          final stringChange = (current.stringNumber - prior.stringNumber)
              .abs();
          // Weight fret movement heavily and string changes lightly so the
          // path prefers staying in one hand region and switching strings
          // over sliding the same string up and down the neck.
          final cost =
              costs[noteIndex - 1][priorIndex] +
              movement * 1.6 +
              stringChange * 0.1 +
              baseCost;
          if (cost < noteCosts[currentIndex]) {
            noteCosts[currentIndex] = cost;
            notePrevious[currentIndex] = priorIndex;
          }
        }
      }
      costs.add(noteCosts);
      previous.add(notePrevious);
    }

    final selected = List<int>.filled(notes.length, -1);
    var index = notes.length - 1;
    while (index >= 0) {
      if (candidates[index].isEmpty) {
        index--;
        continue;
      }
      if (selected[index] == -1) {
        var best = 0;
        for (var i = 1; i < costs[index].length; i++) {
          if (costs[index][i] < costs[index][best]) best = i;
        }
        selected[index] = best;
      }
      if (index > 0 && previous[index][selected[index]] >= 0) {
        selected[index - 1] = previous[index][selected[index]];
      }
      index--;
    }

    return List.generate(notes.length, (i) {
      final choice = selected[i];
      return FingeredNote(notes[i], choice < 0 ? null : candidates[i][choice]);
    });
  }
}
