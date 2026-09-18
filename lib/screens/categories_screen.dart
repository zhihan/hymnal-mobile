import 'package:material_ui/material_ui.dart';

import '../services/hymn_db_service.dart';
import '../widgets/browse_stats_screen.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrowseStatsScreen(
      title: 'Browse by Category',
      loader: HymnDbService.getCategoryStats,
      emptyIcon: Icons.category_outlined,
      emptyMessage: 'No categories found',
      onItemTap: (context, categoryName) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CategoryDetailScreen(categoryName: categoryName),
          ),
        );
      },
    );
  }
}
