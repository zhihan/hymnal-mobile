import 'package:flutter/material.dart';
import '../models/hymn_song.dart';
import '../services/hymn_loader_service.dart';
import '../widgets/hymn_display.dart';

class HymnDetailScreen extends StatefulWidget {
  final int initialHymnNumber;

  const HymnDetailScreen({
    super.key,
    required this.initialHymnNumber,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  HymnSong? _currentHymn;
  bool _isLoading = true;
  String? _error;
  int _currentHymnNumber = 1;
  int _transposeOffset = 0;
  bool _showTransposeControls = false;
  int? _nextHymnNumber;
  int? _previousHymnNumber;

  @override
  void initState() {
    super.initState();
    _currentHymnNumber = widget.initialHymnNumber;
    _loadHymn(_currentHymnNumber);
  }

  Future<void> _loadHymn(int hymnNumber) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load the hymn first
      final hymn = await HymnLoaderService.loadHymnByNumber(hymnNumber);

      // Then load navigation info (these use cached available numbers)
      // Wrap in try-catch to handle errors gracefully
      int? nextNumber;
      int? previousNumber;

      try {
        nextNumber = await HymnLoaderService.getNextHymnNumber(hymnNumber);
        previousNumber = await HymnLoaderService.getPreviousHymnNumber(hymnNumber);
      } catch (navError) {
        // If navigation loading fails, we can still show the hymn
        // Just disable the navigation buttons
        // Navigation will be null, buttons will be disabled
      }

      setState(() {
        _currentHymn = hymn;
        _nextHymnNumber = nextNumber;
        _previousHymnNumber = previousNumber;
        _currentHymnNumber = hymnNumber;
        _isLoading = false;
        _transposeOffset = 0; // Reset transpose when loading new hymn
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _transposeUp() {
    setState(() {
      _transposeOffset++;
    });
  }

  void _transposeDown() {
    setState(() {
      _transposeOffset--;
    });
  }

  void _resetTranspose() {
    setState(() {
      _transposeOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('补充本 $_currentHymnNumber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _previousHymnNumber != null
                ? () => _loadHymn(_previousHymnNumber!)
                : null,
            tooltip: _previousHymnNumber != null
                ? 'Previous hymn ($_previousHymnNumber)'
                : 'No previous hymn',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _nextHymnNumber != null
                ? () => _loadHymn(_nextHymnNumber!)
                : null,
            tooltip: _nextHymnNumber != null
                ? 'Next hymn ($_nextHymnNumber)'
                : 'No next hymn',
          ),
          IconButton(
            icon: Icon(_showTransposeControls
                ? Icons.expand_less
                : Icons.expand_more),
            onPressed: () {
              setState(() {
                _showTransposeControls = !_showTransposeControls;
              });
            },
            tooltip: 'Toggle transpose controls',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '无法加载诗歌',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!.contains('Failed to load')
                    ? '诗歌编号 $_currentHymnNumber 不存在\n请返回选择其他诗歌'
                    : _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadHymn(_currentHymnNumber),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentHymn == null) {
      return const Center(
        child: Text('No hymn loaded'),
      );
    }

    return Column(
      children: [
        // Transpose controls (collapsible)
        if (_showTransposeControls)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Transpose:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                // Transpose down button
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _transposeDown,
                  tooltip: 'Transpose down',
                  iconSize: 28,
                ),
                // Current transpose offset display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Text(
                    _transposeOffset > 0
                        ? '+$_transposeOffset'
                        : _transposeOffset.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Transpose up button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _transposeUp,
                  tooltip: 'Transpose up',
                  iconSize: 28,
                ),
                const SizedBox(width: 8),
                // Reset button
                TextButton(
                  onPressed: _transposeOffset != 0 ? _resetTranspose : null,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        // Hymn display
        Expanded(
          child: HymnDisplay(
            hymn: _currentHymn!,
            transposeOffset: _transposeOffset,
          ),
        ),
      ],
    );
  }
}
