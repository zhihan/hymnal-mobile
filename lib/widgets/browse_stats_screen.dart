import 'package:material_ui/material_ui.dart';

/// Shared browse screen that loads a name→count stat map and renders it
/// as a list of tappable cards. Used by the categories and lyricists
/// browse screens.
class BrowseStatsScreen extends StatefulWidget {
  final String title;
  final Future<Map<String, int>> Function() loader;
  final IconData emptyIcon;
  final String emptyMessage;
  final void Function(BuildContext context, String name) onItemTap;

  /// Optional extra subtitle content for an item (e.g. an alternate
  /// formatted name). Return null for no extra content.
  final Widget? Function(String name)? itemSubtitleBuilder;

  const BrowseStatsScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onItemTap,
    this.itemSubtitleBuilder,
  });

  @override
  State<BrowseStatsScreen> createState() => _BrowseStatsScreenState();
}

class _BrowseStatsScreenState extends State<BrowseStatsScreen> {
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await widget.loader();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
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
              itemCount: _stats.length,
              itemBuilder: (context, index) {
                final entry = _stats.entries.elementAt(index);
                final name = entry.key;
                final hymnCount = entry.value;
                final extraSubtitle = widget.itemSubtitleBuilder?.call(name);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: extraSubtitle == null
                        ? Text(
                            '$hymnCount ${hymnCount == 1 ? 'hymn' : 'hymns'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              extraSubtitle,
                              const SizedBox(height: 4),
                              Text(
                                '$hymnCount ${hymnCount == 1 ? 'hymn' : 'hymns'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => widget.onItemTap(context, name),
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
