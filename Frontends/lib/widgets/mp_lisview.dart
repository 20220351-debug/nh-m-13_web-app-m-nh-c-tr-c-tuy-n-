import 'package:flute_example/data/song_data.dart';
import 'package:flute_example/pages/now_playing.dart';
import 'package:flute_example/widgets/mp_circle_avatar.dart';
import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class MPListView extends StatelessWidget {
  const MPListView({super.key});

  final List<MaterialColor> _colors = Colors.primaries;
  @override
  Widget build(BuildContext context) {
    final rootIW = MPInheritedWidget.of(context);
    SongData songData = rootIW.songData;
    return ListView.builder(
      itemCount: songData.songs.length,
      itemBuilder: (context, int index) {
        var s = songData.songs[index];
        final MaterialColor color = _colors[index % _colors.length];

        return ListTile(
          dense: false,
          leading: Hero(
            child: avatar(s, color),
            tag: s.title,
          ),
          title: Text(s.title),
          subtitle: Text(
            "By ${s.artist ?? 'Unknown artist'}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () {
            songData.setCurrentIndex(index);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => NowPlaying(songData, s)));
          },
        );
      },
    );
  }
}
