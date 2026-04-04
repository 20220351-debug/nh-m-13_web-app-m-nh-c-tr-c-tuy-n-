import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/root_page.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MediaStore _mediaStore = MediaStore();
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
      if (Platform.isAndroid) {
        await MediaStore.ensureInitialized();

        // Request on_audio_query permissions (READ_MEDIA_AUDIO on Android 13+,
        // READ_EXTERNAL_STORAGE on older). This is needed so artwork queries
        // don't fail with MissingPermissions in the native plugin.
        final hasPermission = await _audioQuery.permissionsStatus();
        if (!hasPermission) {
          final granted = await _audioQuery.permissionsRequest();
          if (!granted) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _permissionDenied = true;
              _errorMessage =
                  'Quyền truy cập bộ nhớ bị từ chối.\nVui lòng cấp quyền để quét nhạc và hiển thị ảnh bìa, hoặc thêm bài hát thủ công.';
            });
            return;
          }
        }
      }

      final songs = await _loadSongsFromMusicFolder();
      if (songs.isEmpty) {
        _errorMessage =
            'Không tìm thấy nhạc. Bạn có thể chọn thư mục nhạc hoặc thêm bài hát thủ công.';
      } else {
        _songData.setSongs(songs);
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

  Future<List<SongModel>> _loadSongsFromMusicFolder() async {
    if (!Platform.isAndroid) {
      return const <SongModel>[];
    }

    final documentTree = await _mediaStore.requestForAccess(
      initialRelativePath: 'Music',
    );

    if (documentTree == null) {
      return const <SongModel>[];
    }

    final acceptedExtensions = <String>{
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.flac',
      '.ogg',
      '.opus',
      '.amr',
      '.wma',
    };

    final songs = <SongModel>[];
    for (final document in documentTree.children) {
      if (document.isDirectory) {
        continue;
      }

      final fileName = document.name ?? 'Unknown track';
      final extension = fileName.contains('.')
          ? '.${fileName.split('.').last.toLowerCase()}'
          : '';
      if (acceptedExtensions.isNotEmpty &&
          extension.isNotEmpty &&
          !acceptedExtensions.contains(extension)) {
        continue;
      }

      songs.add(
        SongModel({
          '_id': document.uri.hashCode.abs(),
          '_data': document.uriString,
          '_uri': document.uriString,
          '_display_name': fileName,
          '_display_name_wo_ext': fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName,
          '_size': document.fileLength,
          'album': 'Music',
          'album_id': null,
          'artist': 'Unknown artist',
          'artist_id': null,
          'genre': null,
          'genre_id': null,
          'bookmark': null,
          'composer': null,
          'date_added': document.lastModified,
          'date_modified': document.lastModified,
          'duration': null,
          'title': fileName,
          'track': null,
          'file_extension': extension.replaceFirst('.', ''),
          'is_alarm': false,
          'is_audiobook': false,
          'is_music': true,
          'is_notification': false,
          'is_podcast': false,
          'is_ringtone': false,
        }),
      );
    }

    return songs;
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

      setState(() {
        _songData.addSongs(manualSongs);
        _errorMessage = null;
        _permissionDenied = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Không thể thêm bài hát: $error';
        _isLoading = false;
      });
    }
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
                    label: const Text('Chọn thư mục nhạc'),
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
      child: child,
    );
  }
}
