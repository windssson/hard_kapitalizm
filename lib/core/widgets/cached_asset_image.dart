import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/managers/asset_manager.dart';

class CachedAssetImage extends ConsumerStatefulWidget {
  final String fileName;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedAssetImage({
    super.key,
    required this.fileName,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  ConsumerState<CachedAssetImage> createState() => _CachedAssetImageState();
}

class _CachedAssetImageState extends ConsumerState<CachedAssetImage> {
  File? _imageFile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName) {
      setState(() {
        _imageFile = null;
        _error = null;
        _isLoading = true;
      });
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    try {
      final manager = ref.read(assetManagerProvider);
      final file = await manager.getAsset(widget.fileName);
      if (mounted) {
        setState(() {
          _imageFile = file;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _imageFile == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ?? const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return Image.file(
      _imageFile!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
