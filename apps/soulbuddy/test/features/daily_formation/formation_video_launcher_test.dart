import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/application/formation_video_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('uses the YouTube app URI before the web fallback', () async {
    final calls = <({Uri uri, LaunchMode mode})>[];
    final launcher = FormationVideoLauncher(
      canLaunch: (uri) async => uri.scheme == 'vnd.youtube',
      launch: (uri, mode) async {
        calls.add((uri: uri, mode: mode));
        return true;
      },
    );

    final opened = await launcher.open(
      youtubeId: 'W9fR7sHw9Y8',
      webUrl: Uri.parse('https://www.youtube.com/watch?v=W9fR7sHw9Y8'),
    );

    expect(opened, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.uri.toString(), 'vnd.youtube:W9fR7sHw9Y8');
    expect(calls.single.mode, LaunchMode.externalApplication);
  });

  test(
    'opens the web video in an in-app browser when YouTube is unavailable',
    () async {
      final calls = <({Uri uri, LaunchMode mode})>[];
      final web = Uri.parse('https://www.youtube.com/watch?v=W9fR7sHw9Y8');
      final launcher = FormationVideoLauncher(
        canLaunch: (_) async => false,
        launch: (uri, mode) async {
          calls.add((uri: uri, mode: mode));
          return true;
        },
      );

      final opened = await launcher.open(youtubeId: 'W9fR7sHw9Y8', webUrl: web);

      expect(opened, isTrue);
      expect(calls.single, (uri: web, mode: LaunchMode.inAppBrowserView));
    },
  );
}
