import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class OrientationShareMessage {
  static const link = 'https://sbuddy.elbiblio.com';
  static const text =
      'SoulBuddy has helped me pray, reflect, and grow in faith. Join me: $link';
}

class OrientationShareService {
  const OrientationShareService();

  Future<void> shareWithContact() async {
    try {
      final data = await rootBundle.load('assets/images/sanctuary/renewal.png');
      final image = XFile.fromData(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: 'image/png',
        name: 'soulbuddy-orientation.png',
      );
      await Share.shareXFiles(
        [image],
        text: OrientationShareMessage.text,
        subject: 'SoulBuddy',
      );
    } catch (_) {
      await Share.share(OrientationShareMessage.text, subject: 'SoulBuddy');
    }
  }

  Future<bool> shareThroughTelegram() => launchUrl(
    Uri.https('t.me', '/share/url', {
      'url': OrientationShareMessage.link,
      'text': 'Pray and grow with me on SoulBuddy.',
    }),
    mode: LaunchMode.externalApplication,
  );
}
