import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:on_audio_query_pluse/on_audio_query.dart';

class SongData {
  SongData(List<SongModel> songs) : _songs = songs;

  final AudioPlayer audioPlayer = AudioPlayer();
  List<SongModel> _songs;
  int _currentSongIndex = -1;

  List<SongModel> get songs => _songs;
  int get length => _songs.length;
  int get songNumber => _currentSongIndex + 1;
  int get currentIndex => _currentSongIndex;

  void setSongs(List<SongModel> songs) {
    _songs = songs;
    _currentSongIndex = songs.isEmpty ? -1 : 0;
  }

  void addSongs(List<SongModel> songs) {
    if (songs.isEmpty) {
      return;
    }

    final existingPaths = _songs.map((song) => song.data).toSet();
    final mergedSongs = <SongModel>[..._songs];

    for (final song in songs) {
      if (existingPaths.add(song.data)) {
        mergedSongs.add(song);
      }
    }

    _songs = mergedSongs;
    if (_currentSongIndex < 0 && _songs.isNotEmpty) {
      _currentSongIndex = 0;
    }
  }

  static List<SongModel> buildManualSongs(List<String> filePaths) {
    return filePaths.map(buildManualSong).toList(growable: false);
  }

  static SongModel buildManualSong(String filePath) {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final title = path.basenameWithoutExtension(filePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final extension = path.extension(filePath).replaceFirst('.', '');

    return SongModel({
      '_id': filePath.hashCode.abs(),
      '_data': filePath,
      '_uri': filePath,
      '_display_name': fileName,
      '_display_name_wo_ext': title,
      '_size': size,
      'album': 'Manual import',
      'album_id': null,
      'artist': 'Unknown artist',
      'artist_id': null,
      'genre': null,
      'genre_id': null,
      'bookmark': null,
      'composer': null,
      'date_added': null,
      'date_modified': null,
      'duration': null,
      'title': title.isEmpty ? fileName : title,
      'track': null,
      'file_extension': extension,
      'is_alarm': false,
      'is_audiobook': false,
      'is_music': true,
      'is_notification': false,
      'is_podcast': false,
      'is_ringtone': false,
    });
  }

  void setCurrentIndex(int index) {
    _currentSongIndex = index;
  }

  SongModel? get nextSong {
    if (_songs.isEmpty) {
      return null;
    }
    if (_currentSongIndex < length - 1) {
      _currentSongIndex++;
    }
    if (_currentSongIndex >= length) {
      return null;
    }
    return _songs[_currentSongIndex];
  }

  SongModel? get randomSong {
    if (_songs.isEmpty) {
      return null;
    }
    final random = Random();
    return _songs[random.nextInt(_songs.length)];
  }

  SongModel? get prevSong {
    if (_songs.isEmpty) {
      return null;
    }
    if (_currentSongIndex > 0) {
      _currentSongIndex--;
    }
    if (_currentSongIndex < 0) {
      return null;
    }
    return _songs[_currentSongIndex];
  }
}
