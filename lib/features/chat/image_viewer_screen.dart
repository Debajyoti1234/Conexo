import 'package:flutter/material.dart';

/// A clean full-screen image viewer with pinch-to-zoom support.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.imageProvider,
    super.key,
    this.heroTag,
    this.onClose,
  });

  final ImageProvider imageProvider;
  final String? heroTag;
  final VoidCallback? onClose;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final Matrix4 _initialMatrix = Matrix4.identity();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformation);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformation);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformation() {
    final value = _transformationController.value;
    if (value == _initialMatrix) return;
  }

  void _resetZoom() {
    _transformationController.value = _initialMatrix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () {
            widget.onClose?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white),
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          child: Image(
            image: widget.imageProvider,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  size: 48,
                  color: Colors.white54,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}