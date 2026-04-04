import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:synchronized/synchronized.dart';

class SafeArtworkWidget extends StatefulWidget {
  final int id;
  final ArtworkType type;
  final Widget? nullArtworkWidget;
  final BorderRadius? artworkBorder;
  final BoxFit artworkFit;

  const SafeArtworkWidget({
    super.key,
    required this.id,
    required this.type,
    this.nullArtworkWidget,
    this.artworkBorder,
    this.artworkFit = BoxFit.cover,
  });

  @override
  State<SafeArtworkWidget> createState() => _SafeArtworkWidgetState();
}

class _SafeArtworkWidgetState extends State<SafeArtworkWidget> {
  Uint8List? _artwork;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant SafeArtworkWidget oldWidget) {
    if (oldWidget.id != widget.id || oldWidget.type != widget.type) {
      _loadArtwork();
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadArtwork() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final artwork = await _ArtworkFetcher.instance.getArtwork(
      widget.id,
      widget.type,
    );

    if (mounted) {
      setState(() {
        _artwork = artwork;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: widget.artworkBorder ?? BorderRadius.circular(50.0),
        ),
        child: widget.nullArtworkWidget ?? const Icon(Icons.music_note),
      );
    }

    if (_artwork == null || _artwork!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: widget.artworkBorder ?? BorderRadius.circular(50.0),
        ),
        child: widget.nullArtworkWidget ?? const Icon(Icons.music_note),
      );
    }

    return ClipRRect(
      borderRadius: widget.artworkBorder ?? BorderRadius.circular(50.0),
      child: Image.memory(
        _artwork!,
        fit: widget.artworkFit,
        errorBuilder: (_, __, ___) => widget.nullArtworkWidget ?? const Icon(Icons.music_note),
      ),
    );
  }
}

class _ArtworkFetcher {
  static final _ArtworkFetcher instance = _ArtworkFetcher._();

  _ArtworkFetcher._();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final Lock _lock = Lock();
  final Map<String, Uint8List?> _cache = {};

  Future<Uint8List?> getArtwork(int id, ArtworkType type) async {
    final cacheKey = '${id}_${type.name}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Synchronize to prevent native plugin "Reply already submitted" crash 
    // caused by concurrent method channel calls.
    return await _lock.synchronized(() async {
      // Re-check after acquiring lock
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey];
      }

      try {
        final result = await _audioQuery.queryArtwork(
          id,
          type,
          format: ArtworkFormat.JPEG,
          size: 200,
          quality: 100,
        );
        _cache[cacheKey] = result;
        return result;
      } catch (e) {
        // Catches PlatformException (MissingPermissions) and any other errors.
        // Return null on error so it falls back to the placeholder widget.
        _cache[cacheKey] = null;
        return null;
      }
    });
  }
}

