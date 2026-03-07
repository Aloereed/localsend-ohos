import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/dto/info_dto.dart';
import 'package:common/model/dto/receive_request_response_dto.dart';
import 'package:common/model/file_type.dart';
import 'package:common/util/stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/state/send/web/web_send_file.dart';
import 'package:localsend_app/model/state/send/web/web_send_session.dart';
import 'package:localsend_app/model/state/send/web/web_send_state.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/network/server/controller/common.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:uri_content/uri_content.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _downloadPluginChannel = MethodChannel('samples.flutter.dev/downloadplugin');

/// Handles all requests for sending files.
class SendController {
  final ServerUtils server;

  SendController(this.server);

  /// Installs all routes for receiving files.
  void installRoutes({
    required SimpleServerRouteBuilder router,
    required String alias,
    required String fingerprint,
  }) {
    router.get('/', (HttpRequest request) async {
      final state = server.getState();
      if (state.webSendState == null) {
        // There is no web send state
        return await request.respondAsset(403, Assets.web.error403);
      }

      return await request.respondAsset(200, Assets.web.index);
    });

    router.get('/main.js', (HttpRequest request) async {
      final state = server.getState();
      if (state.webSendState == null) {
        // There is no web send state
        return await request.respondAsset(403, Assets.web.error403);
      }

      return await request.respondAsset(200, Assets.web.main, 'text/javascript; charset=utf-8');
    });

    router.get('/i18n.json', (HttpRequest request) async {
      final state = server.getState();
      if (state.webSendState == null) {
        // There is no web send state
        return await request.respondJson(403, message: 'Web send not initialized.');
      }

      return await request.respondJson(200, body: {
        'waiting': t.web.waiting,
        'enterPin': t.web.enterPin,
        'invalidPin': t.web.invalidPin,
        'tooManyAttempts': t.web.tooManyAttempts,
        'rejected': t.web.rejected,
        'files': t.web.files,
        'fileName': t.web.fileName,
        'size': t.web.size,
      });
    });

    router.post(ApiRoute.prepareDownload.v2, (HttpRequest request) async {
      final state = server.getState();
      if (state.webSendState == null) {
        // There is no web send state
        return request.respondJson(403, message: 'Web send not initialized.');
      }

      final requestSessionId = request.uri.queryParameters['sessionId'];
      if (requestSessionId != null) {
        // Check if the user already has permission
        final session =
            server.getState().webSendState?.sessions[requestSessionId];
        if (session != null &&
            session.responseHandler == null &&
            session.ip == request.ip) {
          final deviceInfo = server.ref.read(deviceInfoProvider);
          return await request.respondJson(200,
              body: ReceiveRequestResponseDto(
                info: InfoDto(
                  alias: alias,
                  version: protocolVersion,
                  deviceModel: deviceInfo.deviceModel,
                  deviceType: deviceInfo.deviceType,
                  fingerprint: fingerprint,
                  download: true,
                ),
                sessionId: session.sessionId,
                files: {
                  for (final entry in state.webSendState!.files.entries)
                    entry.key: entry.value.file,
                },
              ).toJson());
        }
      }

      final pinCorrect = await checkPin(
        server: server,
        pin: state.webSendState!.pin,
        pinAttempts: state.webSendState!.pinAttempts,
        request: request,
      );
      if (!pinCorrect) {
        return;
      }

      final streamController = StreamController<bool>();
      final sessionId = request.ip;
      server.setState(
        (oldState) => oldState!.copyWith(
          webSendState: oldState.webSendState!.copyWith(
            sessions: {
              ...oldState.webSendState!.sessions,
              sessionId: WebSendSession(
                sessionId: sessionId,
                responseHandler: streamController,
                ip: request.ip,
                deviceInfo: request.deviceInfo,
              ),
            },
          ),
        ),
      );

      final accepted = state.webSendState?.autoAccept == true ||
          await streamController.stream.first;
      if (!accepted) {
        // user rejected the file transfer
        server.setState(
          (oldState) => oldState!.copyWith(
            webSendState: oldState.webSendState!.copyWith(
              sessions: {
                for (final entry in oldState.webSendState!.sessions.entries)
                  if (entry.key != sessionId)
                    entry.key: entry.value, // remove session
              },
            ),
          ),
        );
        return await request.respondJson(403, message: 'File transfer rejected.');
      }

      server.setState(
        (oldState) => oldState!.copyWith(
          webSendState: oldState.webSendState!.updateSession(
            sessionId: sessionId,
            update: (oldSession) {
              return oldSession.copyWith(
                responseHandler:
                    null, // this indicates that the session is active
              );
            },
          ),
        ),
      );
      final deviceInfo = server.ref.read(deviceInfoProvider);
      return await request.respondJson(200,
          body: ReceiveRequestResponseDto(
            info: InfoDto(
              alias: alias,
              version: protocolVersion,
              deviceModel: deviceInfo.deviceModel,
              deviceType: deviceInfo.deviceType,
              fingerprint: fingerprint,
              download: true,
            ),
            sessionId: sessionId,
            files: {
              for (final entry in state.webSendState!.files.entries)
                entry.key: entry.value.file,
            },
          ).toJson());
    });

    router.head(ApiRoute.download.v2, (HttpRequest request) async {
      final file = await _getDownloadFile(request);
      if (file == null) {
        return;
      }

      var contentLength = file.file.size;
      final path = file.path;
      if (file.bytes == null && path != null && path.isNotEmpty && !path.startsWith('content://')) {
        try {
          final readablePath = await _resolveReadablePath(path);
          contentLength = File(readablePath).lengthSync();
        } catch (_) {
          contentLength = file.file.size;
        }
      }

      _setDownloadHeaders(
        response: request.response,
        fileName: file.file.fileName,
        contentLength: contentLength,
      );
      await request.response.close();
    });

    router.get(ApiRoute.download.v2, (HttpRequest request) async {
      final file = await _getDownloadFile(request);
      if (file == null) {
        return;
      }

      if (file.bytes != null) {
        _setDownloadHeaders(
          response: request.response,
          fileName: file.file.fileName,
          contentLength: file.bytes!.length,
        );

        final byteStream = Stream.fromIterable([file.bytes!]);
        final (streamController, subscription) = byteStream.digested();

        await request.response.addStream(streamController.stream);
        await request.response.close();
        await subscription.cancel();
      } else {
        final path = file.path;
        if (path == null || path.isEmpty) {
          return await request.respondJson(404, message: 'File not found.');
        }

        late final Stream<List<int>> fileStream;
        late final int contentLength;

        try {
          if (path.startsWith('content://')) {
            if (checkPlatform([TargetPlatform.ohos])) {
              return await request.respondJson(404, message: 'File not found.');
            }
            fileStream = UriContent().getContentStream(Uri.parse(path));
            contentLength = file.file.size;
          } else {
            final readablePath = await _resolveReadablePath(path);
            final tmpfile = File(readablePath);
            contentLength = tmpfile.lengthSync();
            fileStream = tmpfile.openRead();
          }
        } catch (_) {
          return await request.respondJson(404, message: 'File not found.');
        }

        _setDownloadHeaders(
          response: request.response,
          fileName: file.file.fileName,
          contentLength: contentLength,
        );

        final (streamController, subscription) = fileStream.digested();

        await request.response.addStream(streamController.stream);
        await request.response.close();
        await subscription.cancel();
      }
    });
  }

  Future<WebSendFile?> _getDownloadFile(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    if (sessionId == null) {
      await request.respondJson(400, message: 'Missing sessionId.');
      return null;
    }

    final session = server.getState().webSendState?.sessions[sessionId];
    if (session == null || session.responseHandler != null || session.ip != request.ip) {
      await request.respondJson(403, message: 'Invalid sessionId.');
      return null;
    }

    final fileId = request.uri.queryParameters['fileId'];
    if (fileId == null) {
      await request.respondJson(400, message: 'Missing fileId.');
      return null;
    }

    final file = server.getState().webSendState?.files[fileId];
    if (file == null) {
      await request.respondJson(403, message: 'Invalid fileId.');
      return null;
    }

    return file;
  }

  Future<String> _resolveReadablePath(String path) async {
    if (!checkPlatform([TargetPlatform.ohos]) || !path.startsWith('file://')) {
      return path;
    }

    final copiedUri = await _downloadPluginChannel.invokeMethod<String>(
      'copyFileWithReadable',
      {'uri': path},
    );
    final readableUri = copiedUri?.isNotEmpty == true ? copiedUri! : path;
    return Uri.decodeFull(
      readableUri.replaceFirst(RegExp(r'^file://(media|docs)'), ''),
    );
  }

  void _setDownloadHeaders({
    required HttpResponse response,
    required String fileName,
    required int contentLength,
  }) {
    final sanitizedFileName = fileName.replaceAll('/', '-');

    response
      ..statusCode = 200
      ..headers.set('content-type', 'application/octet-stream')
      ..headers.set(
        'content-disposition',
        'attachment; filename="${Uri.encodeComponent(sanitizedFileName)}"',
      )
      ..headers.set('content-length', '$contentLength');
  }

  Future<void> initializeWebSend({required List<CrossFile> files}) async {
    final webSendState = WebSendState(
      sessions: {},
      files: Map.fromEntries(await Future.wait(files.map((file) async {
        final id = _uuid.v4();
        return MapEntry(
          id,
          WebSendFile(
            file: FileDto(
              id: id,
              fileName: file.name,
              size: file.size,
              fileType: file.fileType,
              hash: null,
              preview: files.first.fileType == FileType.text &&
                      files.first.bytes != null
                  ? utf8.decode(files.first
                      .bytes!) // send simple message by embedding it into the preview
                  : null,
              metadata: file.lastModified != null || file.lastAccessed != null
                  ? FileMetadata(
                      lastModified: file.lastModified,
                      lastAccessed: file.lastAccessed,
                    )
                  : null,
              legacy: false,
            ),
            asset: file.asset,
            path: file.path,
            bytes: file.bytes,
          ),
        );
      }))),
      autoAccept: server.ref.read(settingsProvider).shareViaLinkAutoAccept,
      pin: null,
      pinAttempts: {},
    );

    server.setState(
      (oldState) => oldState?.copyWith(
        webSendState: webSendState,
      ),
    );
  }

  void acceptRequest(String sessionId) {
    _respondRequest(sessionId, true);
  }

  void declineRequest(String sessionId) {
    _respondRequest(sessionId, false);
  }

  void _respondRequest(String sessionId, bool accepted) {
    final controller =
        server.getState().webSendState?.sessions[sessionId]?.responseHandler;
    if (controller == null) {
      return;
    }

    controller.add(accepted);
    controller.close(); // ignore: discarded_futures
  }
}

extension on WebSendState {
  WebSendState updateSession({
    required String sessionId,
    required WebSendSession Function(WebSendSession oldSession) update,
  }) {
    return copyWith(
      sessions: {...sessions}..update(
          sessionId,
          (session) => update(session),
        ),
    );
  }
}
