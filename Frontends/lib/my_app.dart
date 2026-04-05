import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/root_page.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final SongData _songData = SongData(const []);
  bool _isLoading = true;
  String? _errorMessage;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  @override
  void dispose() {
    _songData.audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initPlatformState() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _permissionDenied = false;
    });

    try {
      // Load saved data (favorites, playlists, manual song paths) first.
      await _songData.loadFromStorage();

      if (Platform.isAndroid) {
        // Request on_audio_query permissions (READ_MEDIA_AUDIO on Android 13+,
        // READ_EXTERNAL_STORAGE on older).
        final hasPermission = await _audioQuery.permissionsStatus();
        if (!hasPermission) {
          final granted = await _audioQuery.permissionsRequest();
          if (!granted) {
            // Permission denied — still load any previously-saved manual songs.
            await _loadSavedManualSongs();

            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _permissionDenied = true;
              _errorMessage = _songData.songs.isEmpty
                  ? 'Quyền truy cập bộ nhớ bị từ chối.\nVui lòng cấp quyền để quét nhạc, hoặc thêm bài hát thủ công.'
                  : null;
            });
            return;
          }
        }
      }

      // Query ALL songs on the device using on_audio_query.
      final songs = await _querySongsFromDevice();

      // Merge scanned songs with any saved manual songs.
      _songData.setSongs(songs);
      await _loadSavedManualSongs();

      if (_songData.songs.isEmpty) {
        _errorMessage =
            'Không tìm thấy nhạc. Bạn có thể thêm bài hát thủ công.';
      } else {
        _errorMessage = null;
      }
    } catch (error) {
      _errorMessage = 'Lỗi khi tải nhạc: $error';
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  /// Query all songs from the device via [OnAudioQuery], filtering to
  /// files with duration >= 30 seconds.
  Future<List<SongModel>> _querySongsFromDevice() async {
    if (!Platform.isAndroid) {
      return const <SongModel>[];
    }

    try {
      final allSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter: only songs with duration >= 30 000 ms (30 seconds).
      return allSongs.where((song) {
        final durationMs = song.duration ?? 0;
        return durationMs >= 30000;
      }).toList();
    } catch (e) {
      // If querying fails (e.g. missing permissions), return empty.
      return const <SongModel>[];
    }
  }

  /// Load manually-added songs from persistent storage and merge them.
  Future<void> _loadSavedManualSongs() async {
    final paths = _songData.manualSongPaths;
    if (paths.isEmpty) return;

    // Only add files that still exist on disk.
    final validPaths = paths.where((p) => File(p).existsSync()).toList();
    final manual = SongData.buildManualSongs(validPaths);
    _songData.addSongs(manual);
  }

  Future<void> _addManualSongs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
        withData: false,
      );

      final filePaths = result?.files
              .map((file) => file.path)
              .whereType<String>()
              .toList(growable: false) ??
          const <String>[];
      if (filePaths.isEmpty) {
        return;
      }

      final manualSongs = SongData.buildManualSongs(filePaths);
      if (manualSongs.isEmpty) {
        return;
      }

      _songData.addSongs(manualSongs);
      _songData.addManualPaths(filePaths);
      await _songData.persistManualPaths();

      if (!mounted) return;

      setState(() {
        _errorMessage = null;
        _permissionDenied = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Không thể thêm bài hát: $error';
        _isLoading = false;
      });
    }
  }

  void _toggleFavorite(int songId) {
    setState(() {
      _songData.toggleFavorite(songId);
    });
  }

  Future<void> _retryPermission() async {
    await _initPlatformState();
  }

  Widget _buildPermissionFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _permissionDenied
                  ? Icons.lock_outlined
                  : Icons.library_music_outlined,
              size: 64,
              color: _permissionDenied ? Colors.orange : null,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Quyền truy cập bị từ chối.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_permissionDenied)
                  ElevatedButton.icon(
                    onPressed: _retryPermission,
                    icon: const Icon(Icons.security),
                    label: const Text('Cấp quyền'),
                  ),
                ElevatedButton.icon(
                  onPressed: _addManualSongs,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm thủ công'),
                ),
                if (!_permissionDenied)
                  OutlinedButton.icon(
                    onPressed: _initPlatformState,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Quét lại'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child =
        _errorMessage == null ? const RootPage() : _buildPermissionFallback();

    return MPInheritedWidget(
      _songData,
      _isLoading,
      onAddManualSongs: _addManualSongs,
      onToggleFavorite: _toggleFavorite,
      onRefreshSongs: _initPlatformState,
      child: child,
    );
  }
}
