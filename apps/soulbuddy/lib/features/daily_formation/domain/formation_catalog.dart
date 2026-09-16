class FormationCatalog {
  const FormationCatalog({
    required this.version,
    required this.sourceSha256,
    required this.videos,
    required this.packs,
    required this.days,
    required this.rules,
  });

  final int version;
  final String sourceSha256;
  final List<FormationVideo> videos;
  final List<FormationPack> packs;
  final List<FormationDay> days;
  final List<FormationRule> rules;

  Map<String, FormationVideo> get videosById => {
    for (final video in videos) video.id: video,
  };

  factory FormationCatalog.fromJson(Map<dynamic, dynamic> json) =>
      FormationCatalog(
        version: json['version'] as int,
        sourceSha256: json['sourceSha256'] as String,
        videos: _list(json['videos']).map(FormationVideo.fromJson).toList(),
        packs: _list(json['packs']).map(FormationPack.fromJson).toList(),
        days: _list(json['days']).map(FormationDay.fromJson).toList(),
        rules: _list(json['rules']).map(FormationRule.fromJson).toList(),
      );

  static List<Map<dynamic, dynamic>> _list(dynamic value) =>
      (value as List).cast<Map<dynamic, dynamic>>();
}

class FormationVideo {
  const FormationVideo({
    required this.id,
    required this.title,
    required this.channel,
    required this.youtubeUrl,
    required this.youtubeId,
    required this.runtimeSeconds,
    required this.status,
  });

  final String id;
  final String title;
  final String channel;
  final String youtubeUrl;
  final String youtubeId;
  final int runtimeSeconds;
  final String status;

  factory FormationVideo.fromJson(Map<dynamic, dynamic> json) => FormationVideo(
    id: json['id'] as String,
    title: json['title'] as String,
    channel: json['channel'] as String,
    youtubeUrl: json['youtubeUrl'] as String,
    youtubeId: json['youtubeId'] as String,
    runtimeSeconds: json['runtimeSeconds'] as int,
    status: json['status'] as String,
  );
}

class FormationPack {
  const FormationPack({
    required this.id,
    required this.order,
    required this.title,
  });

  final String id;
  final int order;
  final String title;

  factory FormationPack.fromJson(Map<dynamic, dynamic> json) => FormationPack(
    id: json['id'] as String,
    order: json['order'] as int,
    title: json['title'] as String,
  );
}

class FormationDay {
  const FormationDay({
    required this.id,
    required this.day,
    required this.packId,
    required this.focus,
    required this.objective,
    required this.scripture,
    required this.reflection,
    required this.action,
    required this.videoIds,
  });

  final String id;
  final int day;
  final String packId;
  final String focus;
  final String objective;
  final String scripture;
  final String reflection;
  final String action;
  final List<String> videoIds;

  factory FormationDay.fromJson(Map<dynamic, dynamic> json) => FormationDay(
    id: json['id'] as String,
    day: json['day'] as int,
    packId: json['packId'] as String,
    focus: json['focus'] as String,
    objective: json['objective'] as String,
    scripture: json['scripture'] as String,
    reflection: json['reflection'] as String,
    action: json['action'] as String,
    videoIds: (json['videoIds'] as List).cast<String>(),
  );
}

class FormationRule {
  const FormationRule({required this.id, required this.priority});

  final String id;
  final int priority;

  factory FormationRule.fromJson(Map<dynamic, dynamic> json) => FormationRule(
    id: json['id'] as String,
    priority: json['priority'] as int,
  );
}
