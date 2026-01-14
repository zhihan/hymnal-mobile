import 'package:flutter/material.dart';
import '../services/hymn_db_service.dart';
import '../utils/lyricist_formatter.dart';
import 'lyricist_detail_screen.dart';

class LyricistsScreen extends StatefulWidget {
  const LyricistsScreen({super.key});

  @override
  State<LyricistsScreen> createState() => _LyricistsScreenState();
}

class _LyricistsScreenState extends State<LyricistsScreen> {
  Map<String, int> _lyricistStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLyricists();
  }

  Future<void> _loadLyricists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await HymnDbService.getLyricistStats();
      setState(() {
        _lyricistStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lyricists: $e')),
        );
      }
    }
  }

  void _navigateToLyricist(String lyricistName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricistDetailScreen(lyricistName: lyricistName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Browse by Author'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _lyricistStats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No lyricists found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _lyricistStats.length,
                  itemBuilder: (context, index) {
                    final entry = _lyricistStats.entries.elementAt(index);
                    final lyricistName = entry.key;
                    final hymnCount = entry.value;
                    final formattedName = LyricistFormatter.format(lyricistName);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          lyricistName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (formattedName != lyricistName) ...[
                              const SizedBox(height: 4),
                              Text(
                                formattedName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
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
                        onTap: () => _navigateToLyricist(lyricistName),
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
