import 'package:dart_pub_notifier_bot/dart_pub_notifier_bot.dart' as dart_pub_notifier_bot;
import 'dart:io';
import 'dart:convert';
import 'package:xargs/xargs.dart';
import 'package:path/path.dart';
import 'package:xfile/xfile.dart';

main(List<String> arguments) async {
  XArgs xArgs = XArgs.of(arguments);
  bool originMode = xArgs.hasKey('originMode');
  if (originMode) {
    String botToken = xArgs['token'];
    String action = xArgs['action'];
    String args = xArgs['args'];
    print(args);
    Map json = jsonDecode(args);
    HttpClient client = HttpClient();
    String url = 'https://api.telegram.org/bot$botToken/$action?${mapToQuery(json)}';
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    String body = await response.transform(utf8.decoder).join('');
    print(body);
  } else {
    String botToken = xArgs['token'];
    String action = xArgs['action'];
    var foundRunners = runners.where((runner) => runner.action == action).toList();
    if (foundRunners.isNotEmpty) {
      await foundRunners.first.run(botToken, xArgs);
    } else {
      print('找不到實作對象啦幹');
    }
  }
}

String mapToQuery(Map map) => map.entries.map((ent) => '${ent.key}=${ent.value}').join('&');

List<ActionRunner> runners = [SayAction(), UpdatePluginAction()];

abstract class ActionRunner {
  String get action;

  String get method;

  Map<String, dynamic> buildParams(XArgs args);

  void run(String botToken, XArgs args) async {
    HttpClient client = HttpClient();
    String url = 'https://api.telegram.org/bot$botToken/$method?${mapToQuery(buildParams(args))}';
    print('請求=$url');
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    String body = await response.transform(utf8.decoder).join('');
    print(body);
  }
}

class SayAction extends ActionRunner {
  @override
  String get action => 'say';

  @override
  String get method => 'sendMessage';

  @override
  Map<String, dynamic> buildParams(XArgs args) {
    return {
      'chat_id': args['chatId'],
      'text': args['text'],
    };
  }
}

class UpdatePluginAction extends ActionRunner {
  String get runPath => dirname(Platform.script.path).substring(1);
  String get _readChangeLog => XFile.fromPath('./CHANGELOG.md').file.readAsStringSync();
  ChangelogSegment get latestChangelog => _readChangeLog.split('\n').fold(<ChangelogSegment>[], combine).last;

  String get changeContent {
    return 'hello';
  }

  @override
  String get action => 'update';

  @override
  Map<String, dynamic> buildParams(XArgs args) {
    return {
      'chat_id': 433095941,
      'text': changeContent,
    };
  }

  @override
  void run(String botToken, XArgs args) {
    print(latestChangelog.content);
  }

  @override
  String get method => 'sendMessage';

  List<ChangelogSegment> combine(List<ChangelogSegment> total, String line) {
    ChangelogSegment segment;
    RegExp regExp;
    if ((regExp = RegExp(r'^## (\d.\d.\d)')).hasMatch(line)) {
      String version = regExp.firstMatch(line).group(1);
      segment = ChangelogSegment(version);
      total.add(segment);
    } else {
      segment = total.last;
      if (line.isNotEmpty) segment.addLine(line);
    }
    return total;
  }
}

class ChangelogSegment {
  String version;
  StringBuffer buffer = StringBuffer();

  ChangelogSegment(this.version);

  void addLine(String line) => buffer.writeln(line);

  String get content => buffer.toString();
}
