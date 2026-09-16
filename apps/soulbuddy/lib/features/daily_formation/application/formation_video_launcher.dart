import 'package:url_launcher/url_launcher.dart';

typedef FormationCanLaunch = Future<bool> Function(Uri uri);
typedef FormationLaunch = Future<bool> Function(Uri uri, LaunchMode mode);

class FormationVideoLauncher {
  FormationVideoLauncher({
    FormationCanLaunch? canLaunch,
    FormationLaunch? launch,
  }) : _canLaunch = canLaunch ?? canLaunchUrl,
       _launch = launch ?? _launchUrl;

  final FormationCanLaunch _canLaunch;
  final FormationLaunch _launch;

  Future<bool> open({required String youtubeId, required Uri webUrl}) async {
    final appUrl = Uri(scheme: 'vnd.youtube', path: youtubeId);
    if (await _canLaunch(appUrl) &&
        await _launch(appUrl, LaunchMode.externalApplication)) {
      return true;
    }
    return _launch(webUrl, LaunchMode.inAppBrowserView);
  }

  static Future<bool> _launchUrl(Uri uri, LaunchMode mode) =>
      launchUrl(uri, mode: mode);
}
