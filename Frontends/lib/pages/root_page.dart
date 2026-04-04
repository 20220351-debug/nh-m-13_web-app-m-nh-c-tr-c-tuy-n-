import 'package:flute_example/pages/now_playing.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flute_example/widgets/mp_lisview.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rootIW = MPInheritedWidget.of(context);
    //Goto Now Playing Page
    void goToNowPlaying(SongModel song, {bool nowPlayTap = false}) {
      Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (context) => NowPlaying(
                    rootIW.songData,
                    song,
                    nowPlayTap: nowPlayTap,
                  )));
    }

    //Shuffle Songs and goto now playing page
    void shuffleSongs() {
      final randomSong = rootIW.songData.randomSong;
      if (randomSong != null) {
        goToNowPlaying(randomSong);
      }
    }

    final songs = rootIW.songData.songs;
    final manualAddSongs = rootIW.onAddManualSongs;

    Widget emptyState() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_music_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('No songs found on this device.'),
              if (manualAddSongs != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: manualAddSongs,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm thủ công'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter Music Player"),
        actions: <Widget>[
          Container(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: InkWell(
                  child: const Text("Now Playing"),
                  onTap: songs.isEmpty
                      ? null
                      : () => goToNowPlaying(
                            songs[rootIW.songData.currentIndex < 0
                                ? 0
                                : rootIW.songData.currentIndex],
                            nowPlayTap: true,
                          )),
            ),
          )
        ],
      ),
      // drawer: new MPDrawer(),
      body: rootIW.isLoading
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
              ? emptyState()
              : const Scrollbar(child: MPListView()),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.shuffle), onPressed: shuffleSongs),
    );
  }
}
