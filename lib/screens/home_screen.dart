import 'package:flutter/material.dart';
import 'hymn_detail_screen.dart';
import '../services/hymn_loader_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hymnNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _hymnNumberController.dispose();
    super.dispose();
  }

  Future<void> _goToHymn() async {
    if (_formKey.currentState!.validate()) {
      final hymnNumber = int.parse(_hymnNumberController.text);

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Try to load the hymn to verify it exists
        await HymnLoaderService.loadHymnByNumber(hymnNumber);

        // If successful, navigate to detail screen
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HymnDetailScreen(
                initialHymnNumber: hymnNumber,
              ),
            ),
          );
        }
      } catch (e) {
        // If hymn doesn't exist, show error message
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '诗歌编号 $hymnNumber 不存在，请输入其他编号';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('补充本'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.music_note,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                '补充本',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _hymnNumberController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      enabled: !_isLoading,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: '请输入诗歌编号',
                        hintText: '例如: 1, 101, 501',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        errorText: _errorMessage,
                        errorMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入诗歌编号';
                        }
                        final number = int.tryParse(value);
                        if (number == null) {
                          return '请输入有效的数字';
                        }
                        if (number < 1) {
                          return '请输入大于0的数字';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _goToHymn(),
                      onChanged: (_) {
                        // Clear error when user starts typing
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _goToHymn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('查看诗歌'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
