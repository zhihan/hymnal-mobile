import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GuitarLeadsheetScreen extends StatefulWidget {
  final String svgUrl;
  final String hymnTitle;

  const GuitarLeadsheetScreen({
    super.key,
    required this.svgUrl,
    required this.hymnTitle,
  });

  @override
  State<GuitarLeadsheetScreen> createState() => _GuitarLeadsheetScreenState();
}

class _GuitarLeadsheetScreenState extends State<GuitarLeadsheetScreen> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: SvgPicture.network(
                    widget.svgUrl,
                    width: constraints.maxWidth,
                    alignment: Alignment.topCenter,
                    placeholderBuilder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Opacity(
                opacity: 0.5,
                child: IconButton.filled(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
