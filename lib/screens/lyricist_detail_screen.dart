import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/hymn_db.dart';
import '../services/hymn_db_service.dart';

class LyricistDetailScreen extends StatefulWidget {
  final String lyricistName;

  const LyricistDetailScreen({
    super.key,
    required this.lyricistName,
  });

  @override
  State<LyricistDetailScreen> createState() => _LyricistDetailScreenState();
}

class _LyricistDetailScreenState extends State<LyricistDetailScreen> {
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
      final hymns = await HymnDbService.getHymnsByLyricist(widget.lyricistName);
      setState(() {
        _hymns = hymns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hymns: $e')),
        );
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Songs by ${widget.lyricistName}'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _hymns.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hymns found by this lyricist',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
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
