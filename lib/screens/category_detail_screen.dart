import 'package:material_ui/material_ui.dart';
import '../services/hymn_db_service.dart';
import '../widgets/hymn_list_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String categoryName;

  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return HymnListScreen(
      title: categoryName,
      loader: () => HymnDbService.getHymnsByCategory(categoryName),
      emptyIcon: Icons.music_note,
      emptyMessage: 'No hymns found in this category',
    );
  }
}
