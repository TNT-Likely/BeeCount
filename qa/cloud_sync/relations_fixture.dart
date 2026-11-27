import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
// The host fixture provides separate per-device document folders.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class RelationsPaths extends PathProviderPlatform {
  RelationsPaths(this.root);
  final Directory root;
  static PathProviderPlatform get current => PathProviderPlatform.instance;
  static void restore(PathProviderPlatform value) =>
      PathProviderPlatform.instance = value;
  @override
  Future<String> getApplicationDocumentsPath() async => root.path;
  @override
  Future<String> getTemporaryPath() async => root.path;
}

class RelationsDevice {
  RelationsDevice(this.root)
      : db = BeeDatabase.forTesting(
            NativeDatabase(File('${root.path}/app.sqlite')));
  final Directory root;
  final BeeDatabase db;
  final cloud = BeeCountCloudProvider();
  late final tracker = ChangeTracker(db);
  late final repo = LocalRepository(db, changeTracker: tracker);
  late final engine =
      SyncEngine(db: db, repo: repo, provider: cloud, changeTracker: tracker);
  late final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)]);
  AttachmentService get attachments =>
      container.read(attachmentServiceProvider);

  void selectFiles() => PathProviderPlatform.instance = RelationsPaths(root);

  Future<void> sync(int ledger) async {
    final result = await engine.sync(ledgerId: ledger.toString());
    if (result.hasError) {
      throw StateError('Sync ledger $ledger failed: ${result.error}');
    }
  }

  Future<void> close() async {
    await engine.dispose();
    container.dispose();
    await cloud.dispose();
    await db.close();
  }
}

/// Drops a response only after receiving an HTTP 200 from the real upstream.
class RelationsRelay {
  RelationsRelay._(this.origin, this.server);
  final Uri origin;
  final HttpServer server;
  final _client = HttpClient()..autoUncompress = false;
  bool offline = false;
  bool loseNextPush = false;
  int blocked = 0;
  int lost = 0;
  int downloads = 0;
  final List<Map<String, dynamic>> pushes = [];

  String get localOrigin => 'http://127.0.0.1:${server.port}';

  static Future<RelationsRelay> open(Uri origin) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = RelationsRelay._(origin, server);
    server.listen(relay.forward);
    return relay;
  }

  Future<void> forward(HttpRequest input) async {
    final out = input.response;
    try {
      if (offline) {
        blocked++;
        out.statusCode = HttpStatus.serviceUnavailable;
        out.write('QA offline');
        return;
      }
      final target = origin.replace(
          path: input.uri.path,
          query: input.uri.hasQuery ? input.uri.query : null);
      final request = await _client.openUrl(input.method, target);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      for (final field in [
        'authorization',
        'content-type',
        'x-beecount-recurring',
        'idempotency-key',
        'x-device-id'
      ]) {
        final value = input.headers.value(field);
        if (value != null) request.headers.set(field, value);
      }
      await request.addStream(input);
      final response = await request.close();
      out.statusCode = response.statusCode;
      for (final field in ['content-type', 'content-encoding']) {
        final value = response.headers.value(field);
        if (value != null) out.headers.set(field, value);
      }
      if (input.method == 'POST' &&
          input.uri.path.endsWith('/sync/push') &&
          response.statusCode == 200) {
        final data = await utf8.decodeStream(response);
        final ack = jsonDecode(data) as Map<String, dynamic>;
        pushes.add({'accepted': ack['accepted'], 'rejected': ack['rejected']});
        if (loseNextPush) {
          loseNextPush = false;
          lost++;
          out.statusCode = HttpStatus.serviceUnavailable;
          out.write('{"detail":"QA response lost after commit"}');
        } else {
          out.add(utf8.encode(data));
        }
      } else {
        if (input.method == 'GET' &&
            input.uri.path.contains('/attachments/') &&
            response.statusCode == 200) {
          downloads++;
        }
        await out.addStream(response);
      }
    } catch (_) {
      out.statusCode = HttpStatus.badGateway;
    } finally {
      await out.close();
    }
  }

  Future<void> close() async {
    await server.close(force: true);
    _client.close(force: true);
  }
}

class RelationsWeb {
  RelationsWeb(this.origin);
  final Uri origin;
  String? token;
  Future<Map<String, dynamic>> api(String method, String path,
      [Map<String, dynamic>? body]) async {
    final request = http.Request(method, origin.resolve(path));
    request.followRedirects = false;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await request.send())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw StateError(
          '$method ${request.url.path} HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> snapshot(String ledger) async {
    final result = await api('GET', '/api/v1/sync/full?ledger_id=$ledger');
    return jsonDecode(result['snapshot']['payload']['content'] as String)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> events(int since) =>
      api('GET', '/api/v1/sync/pull?since=$since&limit=500');
}

Future<({File source, String digest})> relationImage(
    Directory root, int seed, int index) async {
  // Different content and identical display names exercise content-addressed storage.
  final picture = ui.PictureRecorder();
  final canvas = ui.Canvas(picture);
  final color = 0xff000000 | ((seed * 101 + index * 0x10101) & 0xffffff);
  canvas.drawColor(ui.Color(color), ui.BlendMode.src);
  canvas.drawRect(ui.Rect.fromLTWH(1, 2, index + 1.0, 5),
      ui.Paint()..color = const ui.Color(0xffffffff));
  final recording = picture.endRecording();
  final image = await recording.toImage(20, 12);
  final buffer = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final bytes =
      buffer.buffer.asUint8List(buffer.offsetInBytes, buffer.lengthInBytes);
  image.dispose();
  recording.dispose();
  final file = File('${root.path}/input-$index/receipt.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return (source: file, digest: sha256.convert(bytes).toString());
}
