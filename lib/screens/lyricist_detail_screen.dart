import 'package:material_ui/material_ui.dart';
import '../services/hymn_db_service.dart';
import '../widgets/hymn_list_screen.dart';

class LyricistDetailScreen extends StatelessWidget {
  final String lyricistName;

  const LyricistDetailScreen({super.key, required this.lyricistName});

  @override
  Widget build(BuildContext context) {
    return HymnListScreen(
      title: 'Songs by $lyricistName',
      loader: () => HymnDbService.getHymnsByLyricist(lyricistName),
      emptyIcon: Icons.person,
      emptyMessage: 'No hymns found by this lyricist',
    );
  }
}
