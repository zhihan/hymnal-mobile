/// Utility class for formatting lyricist names
class LyricistFormatter {
  /// Formats a lyricist name to use initials for first and middle names,
  /// and full last name.
  ///
  /// Examples:
  /// - "Hannah Kilham Burlingham" -> "H. K. Burlingham"
  /// - "Witness Lee" -> "W. Lee"
  /// - "B. P. H." -> "B. P. H." (already formatted with periods)
  /// - "Edward Mote" -> "E. Mote"
  static String format(String? lyricist) {
    if (lyricist == null || lyricist.isEmpty) {
      return '';
    }

    // If the name already contains periods, assume it's already formatted
    if (lyricist.contains('.')) {
      return lyricist;
    }

    // Split the name by spaces
    final parts = lyricist.trim().split(RegExp(r'\s+'));

    // If only one name, return as is
    if (parts.length == 1) {
      return parts[0];
    }

    // Convert all parts except the last to initials
    final initials = parts.sublist(0, parts.length - 1).map((part) {
      if (part.isEmpty) return '';
      return '${part[0].toUpperCase()}.';
    }).where((initial) => initial.isNotEmpty);

    // Get the last name
    final lastName = parts.last;

    // Combine initials and last name
    return '${initials.join(' ')} $lastName';
  }
}
