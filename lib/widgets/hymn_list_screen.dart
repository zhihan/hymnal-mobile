import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../models/hymn_db.dart';

/// Shared screen that displays a list of hymns loaded from the database,
/// used by category and lyricist detail screens.
class HymnListScreen extends StatefulWidget {
  final String title;
  final Future<List<HymnDb>> Function() loader;
  final IconData emptyIcon;
  final String emptyMessage;

  const HymnListScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  State<HymnListScreen> createState() => _HymnListScreenState();
}

class _HymnListScreenState extends State<HymnListScreen> {
  List<HymnDb> _hymns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHymns();
  }

  Future<void> _loadHymns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hymns = await widget.loader();
      setState(() {
        _hymns = hymns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading hymns: $e')));
      }
    }
  }

  void _navigateToHymn(HymnDb hymn) {
    context.push('/hymn/${hymn.bookId}/${hymn.number}');
  }

  String _getSnippet(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hymns.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.emptyIcon, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    widget.emptyMessage,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _hymns.length,
              itemBuilder: (context, index) {
                final hymn = _hymns[index];
                final snippet = _getSnippet(hymn.fullText);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      hymn.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          hymn.hymnId.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _navigateToHymn(hymn),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
