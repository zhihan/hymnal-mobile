import 'package:flutter/material.dart';
import '../services/db_builder.dart';

/// Screen for building the database
/// Run this once to generate the pre-built database
class DbBuilderScreen extends StatefulWidget {
  const DbBuilderScreen({super.key});

  @override
  State<DbBuilderScreen> createState() => _DbBuilderScreenState();
}

class _DbBuilderScreenState extends State<DbBuilderScreen> {
  String status = 'Ready to build database';
  bool isBuilding = false;
  bool isComplete = false;

  Future<void> _buildDatabase() async {
    setState(() {
      isBuilding = true;
      status = 'Starting database build...';
    });

    try {
      final path = await DbBuilder.buildAndExportDatabase();
      setState(() {
        isBuilding = false;
        isComplete = true;
        status = 'Database built successfully!\n\nExported to:\n$path\n\nCheck console for details.';
      });
    } catch (e, stack) {
      setState(() {
        isBuilding = false;
        status = 'Error building database:\n$e\n\n$stack';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Builder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.storage,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Isar Database Builder',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This tool builds the Isar database from JSON files\nand exports it to assets/db/',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 48),
              if (isBuilding)
                const CircularProgressIndicator()
              else if (!isComplete)
                ElevatedButton(
                  onPressed: _buildDatabase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Build Database',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    status,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
