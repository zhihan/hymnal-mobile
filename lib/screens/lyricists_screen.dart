import 'package:material_ui/material_ui.dart';

import '../services/hymn_db_service.dart';
import '../utils/lyricist_formatter.dart';
import '../widgets/browse_stats_screen.dart';
import 'lyricist_detail_screen.dart';

class LyricistsScreen extends StatelessWidget {
  const LyricistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrowseStatsScreen(
      title: 'Browse by Author',
      loader: HymnDbService.getLyricistStats,
      emptyIcon: Icons.person_outlined,
      emptyMessage: 'No lyricists found',
      itemSubtitleBuilder: (lyricistName) {
        final formattedName = LyricistFormatter.format(lyricistName);
        if (formattedName == lyricistName) return null;
        return Text(
          formattedName,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        );
      },
      onItemTap: (context, lyricistName) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LyricistDetailScreen(lyricistName: lyricistName),
          ),
        );
      },
    );
  }
}
