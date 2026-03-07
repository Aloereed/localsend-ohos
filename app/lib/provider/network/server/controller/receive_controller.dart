import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:common/model/dto/info_dto.dart';
import 'package:common/model/dto/info_register_dto.dart';
import 'package:common/model/dto/prepare_upload_request_dto.dart';
import 'package:common/model/dto/prepare_upload_response_dto.dart';
import 'package:common/model/dto/register_dto.dart';
import 'package:common/model/file_status.dart';
import 'package:common/model/file_type.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/model/state/server/receiving_file.dart';
import 'package:localsend_app/model/persistence/message_history_entry.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/progress_page.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/pages/receive_page_controller.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/http_provider.dart';
import 'package:localsend_app/provider/message_history_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/controller/common.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/file_saver.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/tray_helper.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:localsend_app/widget/dialogs/open_file_dialog.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routerino/routerino.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

const _uuid = Uuid();

final _logger = Logger('ReceiveController');

/// Handles all requests for receiving files.
class ReceiveController {
  final ServerUtils server;
  final Set<String> _closeOnFinishSessionIds = <String>{};

  ReceiveController(this.server);

  /// Installs all routes for receiving files.
  void installRoutes({
    required SimpleServerRouteBuilder router,
    required String alias,
    required int port,
    required bool https,
    required String fingerprint,
    required String showToken,
  }) {
    router.get(ApiRoute.info.v1, (HttpRequest request) async {
      return await _infoHandler(request: request, alias: alias, fingerprint: fingerprint);
    });

    router.get(ApiRoute.info.v2, (HttpRequest request) async {
      return await _infoHandler(request: request, alias: alias, fingerprint: fingerprint);
    });

    // An upgraded version of /info
    router.post(ApiRoute.register.v1, (HttpRequest request) async {
      return await _registerHandler(request: request, alias: alias, port: port, https: https, fingerprint: fingerprint);
    });

    router.post(ApiRoute.register.v2, (HttpRequest request) async {
      return await _registerHandler(request: request, alias: alias, port: port, https: https, fingerprint: fingerprint);
    });

    router.post(ApiRoute.prepareUpload.v1, (HttpRequest request) async {
      return await _prepareUploadHandler(request: request, port: port, https: https, v2: false);
    });

    router.post(ApiRoute.prepareUpload.v2, (HttpRequest request) async {
      return await _prepareUploadHandler(request: request, port: port, https: https, v2: true);
    });

    router.post(ApiRoute.upload.v1, (HttpRequest request) async {
      return await _uploadHandler(request: request, v2: false);
    });

    router.post(ApiRoute.upload.v2, (HttpRequest request) async {
      return await _uploadHandler(request: request, v2: true);
    });

    router.post(ApiRoute.cancel.v1, (HttpRequest request) async {
      return await _cancelHandler(request: request, v2: false);
    });

    router.post(ApiRoute.cancel.v2, (HttpRequest request) async {
      return await _cancelHandler(request: request, v2: true);
    });

    router.post(ApiRoute.show.v1, (HttpRequest request) async {
      return await _showHandler(request: request, showToken: showToken);
    });

    router.post(ApiRoute.show.v2, (HttpRequest request) async {
      return await _showHandler(request: request, showToken: showToken);
    });
  }

  Future<void> _infoHandler({
    required HttpRequest request,
    required String alias,
    required String fingerprint,
  }) async {
    final senderFingerprint = request.uri.queryParameters['fingerprint'];
    if (senderFingerprint == fingerprint) {
      // "I talked to myself lol"
      return await request.respondJson(412, message: 'Self-discovered');
    }

    final deviceInfo = server.ref.read(deviceInfoProvider);

    final dto = InfoDto(
      alias: alias,
      version: protocolVersion,
      deviceModel: deviceInfo.deviceModel,
      deviceType: deviceInfo.deviceType,
      fingerprint: fingerprint,
      download: server.getState().webSendState != null,
    );

    return await request.respondJson(200, body: dto.toJson());
  }

  Future<void> _registerHandler({
    required HttpRequest request,
    required String alias,
    required String fingerprint,
    required int port,
    required bool https,
  }) async {
    final payload = await request.readAsString();
    final RegisterDto requestDto;
    try {
      requestDto = RegisterDto.fromJson(jsonDecode(payload));
    } catch (e) {
      return await request.respondJson(400, message: 'Request body malformed');
    }

    if (requestDto.fingerprint == fingerprint) {
      // "I talked to myself lol"
      return await request.respondJson(412, message: 'Self-discovered');
    }

    // Save device information
    await server.ref.redux(nearbyDevicesProvider).dispatchAsync(RegisterDeviceAction(requestDto.toDevice(request.ip, port, https)));
    server.ref.notifier(discoveryLoggerProvider).addLog('[DISCOVER/TCP] Received "/register" HTTP request: ${requestDto.alias} (${request.ip})');

    final deviceInfo = server.ref.read(deviceInfoProvider);

    final responseDto = InfoDto(
      alias: alias,
      version: protocolVersion,
      deviceModel: deviceInfo.deviceModel,
      deviceType: deviceInfo.deviceType,
      fingerprint: fingerprint,
      download: server.getState().webSendState != null,
    );

    return await request.respondJson(200, body: responseDto.toJson());
  }

  Future<void> _prepareUploadHandler({
    required HttpRequest request,
    required int port,
    required bool https,
    required bool v2,
  }) async {
    if (server.getState().session != null) {
      return await request.respondJson(409, message: 'Another file transfer is in progress');
    }

    final pinCorrect = await checkPin(
      request: request,
      server: server,
      pin: server.ref.read(settingsProvider).receivePin,
      pinAttempts: server.getState().pinAttempts,
    );
    if (!pinCorrect) {
      return;
    }

    final PrepareUploadRequestDto dto;
    try {
      final payload = await request.readAsString();
      dto = PrepareUploadRequestDto.fromJson(jsonDecode(payload));
    } catch (e) {
      return await request.respondJson(400, message: 'Request body malformed');
    }

    if (dto.files.isEmpty) {
      return await request.respondJson(400, message: 'Request must contain at least one file');
    }

    final settings = server.ref.read(settingsProvider);
    final destinationDir = settings.destination ?? await getDefaultDestinationDirectory();
    final cacheDir = await getCacheDirectory();
    final sessionId = _uuid.v4();

    _logger.info('Session Id: $sessionId');
    _logger.info('Destination Directory: $destinationDir');

    final streamController = StreamController<Map<String, String>?>();
    server.setState(
      (oldState) => oldState?.copyWith(
        session: ReceiveSessionState(
          sessionId: sessionId,
          status: SessionStatus.waiting,
          sender: dto.info.toDevice(request.ip, port, https),
          senderAlias: server.ref.read(favoritesProvider).firstWhereOrNull((e) => e.fingerprint == dto.info.fingerprint)?.alias ?? dto.info.alias,
          files: {
            for (final file in dto.files.values)
              file.id: ReceivingFile(
                file: file,
                status: FileStatus.queue,
                token: null,
                desiredName: null,
                path: null,
                savedToGallery: false,
                errorMessage: null,
              ),
          },
          startTime: null,
          endTime: null,
          destinationDirectory: destinationDir,
          cacheDirectory: cacheDir,
          saveToGallery: checkPlatformWithGallery() && settings.saveToGallery && dto.files.values.every((f) => !f.fileName.contains('/')),
          createdDirectories: {},
          responseHandler: streamController,
        ),
      ),
    );

    bool quickSave = settings.quickSave && server.getState().session?.message == null;
    final quickSaveFromFavorites = settings.quickSaveFromFavorites && server.getState().session?.message == null;
    if (quickSaveFromFavorites) {
      final bool isFavorite = server.ref.read(favoritesProvider).any((e) => e.fingerprint == dto.info.fingerprint);
      if (isFavorite) {
        quickSave = true;
      }
    }

    final receiveSession = server.getState().session!;
    final message = receiveSession.message;
    final Map<String, String>? selection;
    if (message != null) {
      await _upsertIncomingTextEntry(server, receiveSession, message);
      _focusMessageConversation(server, receiveSession);
      selection = const <String, String>{};
    } else {
      server.ref.notifier(selectedReceivingFilesProvider).setFiles(receiveSession.files.values.map((f) => f.file).toList());
      await _upsertIncomingTransferEntry(server, receiveSession, MessageTransferState.pendingIncoming);
      if (quickSave) {
        selection = {
          for (final f in receiveSession.files.values) f.file.id: f.file.fileName,
        };
      } else {
        if (checkPlatformHasTray() && (await windowManager.isMinimized() || !(await windowManager.isVisible()) || !(await windowManager.isFocused()))) {
          await showFromTray();
        }
        _presentIncomingTransfer(server, receiveSession);
        selection = await streamController.stream.first;
      }
    }

    if (server.getState().session == null) {
      return await request.respondJson(500, message: 'Server is in invalid state');
    }

    if (selection == null) {
      await _upsertIncomingTransferEntry(server, server.getState().session!, MessageTransferState.declined);
      closeSession();
      return await request.respondJson(403, message: 'File request declined by recipient');
    }

    final acceptedSelection = selection!;
    if (acceptedSelection.isEmpty) {
      closeSession();
      return await request.respondJson(204);
    }

    server.setState(
      (oldState) {
        final current = oldState!.session!;
        return oldState.copyWith(
          session: current.copyWith(
            status: SessionStatus.sending,
            files: Map.fromEntries(
              current.files.values.map((entry) {
                final desiredName = acceptedSelection[entry.file.id];
                return MapEntry(
                  entry.file.id,
                  ReceivingFile(
                    file: entry.file,
                    status: desiredName != null ? FileStatus.queue : FileStatus.skipped,
                    token: desiredName != null ? _uuid.v4() : null,
                    desiredName: desiredName,
                    path: null,
                    savedToGallery: false,
                    errorMessage: null,
                  ),
                );
              }),
            ),
            responseHandler: null,
          ),
        );
      },
    );
    await _upsertIncomingTransferEntry(server, server.getState().session!, MessageTransferState.receiving);

    final files = {
      for (final file in server.getState().session!.files.values.where((f) => f.token != null)) file.file.id: file.token,
    };

    if (checkPlatform([TargetPlatform.android, TargetPlatform.iOS])) {
      if (checkPlatform([TargetPlatform.android]) && !server.getState().session!.destinationDirectory.startsWith('/storage/emulated/0/Download')) {
        try {
          final result = await Permission.storage.request();
          _logger.info('storage permission: $result');
        } catch (e) {
          _logger.warning('Could not request storage permission', e);
        }
      }
      try {
        await Permission.storage.request();
      } catch (e) {
        _logger.warning('Could not request storage permission', e);
      }
    }

    if (v2) {
      return await request.respondJson(
        200,
        body: PrepareUploadResponseDto(
          sessionId: sessionId,
          files: files.cast(),
        ).toJson(),
      );
    }

    return await request.respondJson(200, body: files);
  }

  Future<void> _uploadHandler({
    required HttpRequest request,
    required bool v2,
  }) async {
    final receiveState = server.getState().session;
    if (receiveState == null) {
      return await request.respondJson(409, message: 'No session');
    }

    if (request.ip != receiveState.sender.ip) {
      _logger.warning('Invalid ip address: ${request.ip} (expected: ${receiveState.sender.ip})');
      return await request.respondJson(403, message: 'Invalid IP address: ${request.ip}');
    }

    const allowedStates = {SessionStatus.sending, SessionStatus.finishedWithErrors};
    if (!allowedStates.contains(receiveState.status)) {
      _logger.warning('Wrong state: ${receiveState.status}');
      return await request.respondJson(409, message: 'Recipient is in wrong state');
    }

    final fileId = request.uri.queryParameters['fileId'];
    final token = request.uri.queryParameters['token'];
    final sessionId = request.uri.queryParameters['sessionId'];
    if (fileId == null || token == null || (v2 && sessionId == null)) {
      _logger.warning('Missing parameters: fileId=$fileId, token=$token, sessionId=$sessionId');
      return await request.respondJson(400, message: 'Missing parameters');
    }

    if (v2 && sessionId != receiveState.sessionId) {
      _logger.warning('Wrong session id: $sessionId (expected: ${receiveState.sessionId})');
      return await request.respondJson(403, message: 'Invalid session id');
    }

    final receivingFile = receiveState.files[fileId];
    if (receivingFile == null || receivingFile.token != token) {
      _logger.warning('Wrong fileId: $fileId (expected: ${receivingFile?.file.id})');
      return await request.respondJson(403, message: 'Invalid token');
    }

    server.setState(
      (oldState) => oldState?.copyWith(
        session: receiveState.copyWith(
          files: {...receiveState.files}..update(
              fileId,
              (_) => receivingFile.copyWith(status: FileStatus.sending),
            ),
          startTime: receiveState.startTime ?? DateTime.now().millisecondsSinceEpoch,
          status: SessionStatus.sending,
        ),
      ),
    );
    final fileType = receivingFile.file.fileType;
    final saveToGallery = receiveState.saveToGallery && (fileType == FileType.image || fileType == FileType.video);

    String? outerDestinationPath;
    try {
      final (destinationPath, documentUri, finalName) = await digestFilePathAndPrepareDirectory(
        parentDirectory: saveToGallery ? receiveState.cacheDirectory : receiveState.destinationDirectory,
        fileName: receivingFile.desiredName!,
        createdDirectories: receiveState.createdDirectories,
      );

      outerDestinationPath = destinationPath;
      _logger.info('Saving ${receivingFile.file.fileName} to $destinationPath');

      await saveFile(
        destinationPath: destinationPath,
        documentUri: documentUri,
        name: finalName,
        saveToGallery: saveToGallery,
        isImage: fileType == FileType.image,
        stream: request,
        androidSdkInt: server.ref.read(deviceInfoProvider).androidSdkInt,
        lastModified: receivingFile.file.metadata?.lastModified,
        lastAccessed: receivingFile.file.metadata?.lastAccessed,
        onProgress: (savedBytes) {
          if (receivingFile.file.size != 0) {
            server.ref.notifier(progressProvider).setProgress(
                  sessionId: receiveState.sessionId,
                  fileId: fileId,
                  progress: savedBytes / receivingFile.file.size,
                );
          }
        },
      );
      if (server.getState().session == null || !allowedStates.contains(server.getState().session!.status)) {
        return await request.respondJson(500, message: 'Server is in invalid state');
      }
      server.setState(
        (oldState) => oldState?.copyWith(
          session: oldState.session?.fileFinished(
            fileId: fileId,
            status: FileStatus.finished,
            path: saveToGallery ? null : destinationPath,
            savedToGallery: saveToGallery,
            errorMessage: null,
          ),
        ),
      );
      await _upsertIncomingTransferEntry(server, server.getState().session!, _incomingTransferState(server.getState().session!));
      _logger.info('Saved ${receivingFile.file.fileName}.');
    } catch (e, st) {
      server.setState(
        (oldState) => oldState?.copyWith(
          session: oldState.session?.fileFinished(
            fileId: fileId,
            status: FileStatus.failed,
            path: null,
            savedToGallery: false,
            errorMessage: e.toString(),
          ),
        ),
      );
      await _upsertIncomingTransferEntry(server, server.getState().session!, _incomingTransferState(server.getState().session!));
      _logger.severe('Failed to save file', e, st);
    }

    server.ref.notifier(progressProvider).setProgress(
          sessionId: receiveState.sessionId,
          fileId: fileId,
          progress: 1,
        );

    final session = server.getState().session;
    if (session == null) {
      return await request.respondJson(500, message: 'Server is in invalid state');
    }

    if (allowedStates.contains(session.status) && session.files.values.map((e) => e.status).isFinishedOrError) {
      final hasError = session.files.values.any((f) => f.status == FileStatus.failed);
      server.setState(
        (oldState) => oldState?.copyWith(
          session: oldState.session!.copyWith(
            status: hasError ? SessionStatus.finishedWithErrors : SessionStatus.finished,
            endTime: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      await _upsertIncomingTransferEntry(
        server,
        server.getState().session!,
        hasError ? MessageTransferState.failed : MessageTransferState.completed,
      );
      final settings = server.ref.read(settingsProvider);
      bool quickSave = settings.quickSave && server.getState().session?.message == null;
      final quickSaveFromFavorites = settings.quickSaveFromFavorites && server.getState().session?.message == null;
      if (quickSaveFromFavorites) {
        final bool isFavorite = server.ref.read(favoritesProvider).any((e) => e.fingerprint == session.sender.fingerprint);
        if (isFavorite) {
          quickSave = true;
        }
      }
      if (quickSave) {
        Future.delayed(Duration.zero, () {
          _closeOnFinishSessionIds.remove(session.sessionId);
          closeSession();
          _logger.info('Closing session');
          if (outerDestinationPath != null && outerDestinationPath.isNotEmpty) {
            OpenFileDialog.open(
              Routerino.context,
              filePath: outerDestinationPath,
              fileType: fileType,
              openGallery: saveToGallery,
            );
          }
        });
      } else if (_closeOnFinishSessionIds.remove(session.sessionId)) {
        Future.delayed(Duration.zero, () {
          closeSession();
          _logger.info('Closing message receive session');
        });
      }
      _logger.info('Received all files.');
    }

    return server.getState().session?.files[fileId]?.status == FileStatus.finished
        ? await request.respondJson(200)
        : await request.respondJson(500, message: 'Could not save file. Check receiving device for more information.');
  }


  Future<void> _cancelHandler({
    required HttpRequest request,
    required bool v2,
  }) async {
    final receiveSession = server.getState().session;
    if (receiveSession != null) {
      // We are currently receiving files.

      if (!v2 && receiveSession.sender.version != '1.0') {
        // disallow v1 cancel for active v2 sessions
        return await request.respondJson(403, message: 'No permission');
      }

      if (receiveSession.sender.ip != request.ip) {
        return await request.respondJson(403, message: 'No permission');
      }

      // require session id for v2
      // don't require it when during waiting state
      if (v2 && receiveSession.status != SessionStatus.waiting) {
        final sessionId = request.uri.queryParameters['sessionId'];
        if (sessionId != receiveSession.sessionId) {
          return await request.respondJson(403, message: 'No permission');
        }
      }

      // check if valid state
      final currentStatus = receiveSession.status;
      if (currentStatus != SessionStatus.waiting && currentStatus != SessionStatus.sending) {
        return await request.respondJson(403, message: 'No permission');
      }

      _cancelBySender(server);
      return await request.respondJson(200);
    } else {
      // We are not receiving files so we may be sending files.

      final sessionId = request.uri.queryParameters['sessionId'];
      final sendSessions = server.ref.read(sendProvider);
      final SendSessionState sendState;
      if (v2) {
        // In v2, we require sessionId.

        final selectedSession = sendSessions.values.firstWhereOrNull((s) => s.remoteSessionId == sessionId);
        if (selectedSession == null) {
          return await request.respondJson(403, message: 'No permission');
        }

        sendState = selectedSession;
      } else {
        // In v1, we are a little bit more tolerant.
        // Let's assume the sessionId if only one send session exist

        final onlySession = sendSessions.values.singleOrNull;
        if (onlySession == null) {
          return await request.respondJson(403, message: 'No permission');
        }

        sendState = onlySession;
      }

      if (sendState.target.ip != request.ip) {
        return await request.respondJson(403, message: 'No permission');
      }

      // check if valid state
      if (sendState.status != SessionStatus.sending) {
        return await request.respondJson(403, message: 'No permission');
      }

      server.ref.notifier(sendProvider).cancelSessionByReceiver(
            sendState.sessionId,
          );
      return await request.respondJson(200);
    }
  }

  Future<void> _showHandler({
    required HttpRequest request,
    required String showToken,
  }) async {
    final senderToken = request.uri.queryParameters['token'];
    if (senderToken == showToken && checkPlatformIsDesktop()) {
      // ignore: unawaited_futures
      showFromTray().catchError((e) {
        // don't wait for it
        _logger.severe('Failed to show from tray', e);
      });

      // ignore: unawaited_futures
      request.readAsString().then((body) async {
        if (body.isEmpty) {
          return;
        }

        final Map<String, dynamic> jsonBody = jsonDecode(body);
        final List<String> args = (jsonBody['args'] as List?)?.cast<String>() ?? <String>[];
        final filesAdded = await server.ref.redux(selectedSendingFilesProvider).dispatchAsyncTakeResult(LoadSelectionFromArgsAction(args));
        if (filesAdded) {
          server.ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.send));
        }
      });

      return await request.respondJson(200);
    }

    return await request.respondJson(403, message: 'Invalid token');
  }

  void acceptFileRequest(
    Map<String, String> fileNameMap, {
    bool closeOnFinish = false,
  }) {
    final session = server.getState().session;
    if (closeOnFinish && session != null) {
      _closeOnFinishSessionIds.add(session.sessionId);
    }
    if (session != null && session.message == null && fileNameMap.isNotEmpty) {
      unawaited(_upsertIncomingTransferEntry(server, session, MessageTransferState.receiving));
    }

    final controller = session?.responseHandler;
    if (controller == null || controller.isClosed) {
      return;
    }

    controller.add(fileNameMap);
    controller.close(); // ignore: discarded_futures
  }

  void declineFileRequest() {
    final session = server.getState().session;
    if (session != null && session.message == null) {
      unawaited(_upsertIncomingTransferEntry(server, session, MessageTransferState.declined));
    }

    final controller = session?.responseHandler;
    if (controller == null || controller.isClosed) {
      return;
    }

    controller.add(null);
    controller.close(); // ignore: discarded_futures
  }

  /// Updates the destination directory for the current session.
  void setSessionDestinationDir(String destinationDirectory) {
    server.setState(
      (oldState) => oldState?.copyWith(
        session: oldState.session?.copyWith(
          destinationDirectory: destinationDirectory.replaceAll('\\', '/'),
        ),
      ),
    );
  }

  /// Updates the "saveToGallery" setting for the current session.
  void setSessionSaveToGallery(bool saveToGallery) {
    server.setState(
      (oldState) => oldState?.copyWith(
        session: oldState.session?.copyWith(
          saveToGallery: saveToGallery,
        ),
      ),
    );
  }

  /// In addition to [closeSession], this method also
  /// - cancels incoming requests (TODO)
  /// - notifies the sender that the session has been canceled
  void cancelSession() async {
    final session = server.getStateOrNull()?.session;
    if (session == null) {
      return;
    }

    if (session.message == null) {
      unawaited(_upsertIncomingTransferEntry(server, session, MessageTransferState.canceled));
    }

    try {
      server.ref.read(httpProvider).discovery.post(ApiRoute.cancel.target(session.sender, query: {'sessionId': session.sessionId}));
    } catch (e) {
      _logger.warning('Failed to notify sender', e);
    }

    closeSession();
  }

  void closeSession() {
    final sessionId = server.getStateOrNull()?.session?.sessionId;
    if (sessionId == null) {
      return;
    }

    _closeOnFinishSessionIds.remove(sessionId);

    server.setState(
      (oldState) => oldState?.copyWith(
        session: null,
      ),
    );
    server.ref.notifier(progressProvider).removeSession(sessionId);
  }
}


void _presentIncomingTransfer(ServerUtils server, ReceiveSessionState session) {
  final currentTab = server.ref.read(homePageControllerProvider).currentTab;
  final openMessageTab =
      currentTab == HomeTab.message || server.ref.read(openMessageTabOnIncomingFilesProvider);
  if (openMessageTab) {
    _focusMessageConversation(server, session);
    return;
  }

  server.ref.redux(receivePageControllerProvider).dispatch(InitReceivePageAction());
  unawaited(Routerino.context.push(() => const ReceivePage()));
}


void _focusMessageConversation(ServerUtils server, ReceiveSessionState session) {
  final peer = MessagePeerSnapshot.fromDevice(
    session.sender,
    aliasOverride: session.senderAlias,
  );
  server.ref.notifier(activeMessageSelectionProvider).setState(
        (_) => MessageConversationSelection.fromPeer(peer),
      );
  server.ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.message));
}

Future<void> _upsertIncomingTextEntry(
  ServerUtils server,
  ReceiveSessionState session,
  String message,
) async {
  final peer = MessagePeerSnapshot.fromDevice(
    session.sender,
    aliasOverride: session.senderAlias,
  );
  final existing = server.ref.read(messageHistoryProvider).firstWhereOrNull(
        (entry) => entry.id == session.sessionId,
      );
  final now = DateTime.now().toUtc();
  await server.ref.redux(messageHistoryProvider).dispatchAsync(
        UpsertMessageHistoryEntryAction(
          MessageHistoryEntry(
            id: session.sessionId,
            conversationId: peer.conversationId,
            peer: peer,
            direction: MessageDirection.incoming,
            kind: MessageEntryKind.text,
            state: MessageTransferState.completed,
            text: message,
            isLink: guessIsLink(message),
            items: const [],
            sessionId: session.sessionId,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        ),
      );
}

Future<void> _upsertIncomingTransferEntry(
  ServerUtils server,
  ReceiveSessionState session,
  MessageTransferState state,
) async {
  final peer = MessagePeerSnapshot.fromDevice(
    session.sender,
    aliasOverride: session.senderAlias,
  );
  final existing = server.ref.read(messageHistoryProvider).firstWhereOrNull(
        (entry) => entry.id == session.sessionId,
      );
  final now = DateTime.now().toUtc();
  await server.ref.redux(messageHistoryProvider).dispatchAsync(
        UpsertMessageHistoryEntryAction(
          MessageHistoryEntry(
            id: session.sessionId,
            conversationId: peer.conversationId,
            peer: peer,
            direction: MessageDirection.incoming,
            kind: MessageEntryKind.transferBatch,
            state: state,
            text: null,
            isLink: false,
            items: session.files.values
                .map(
                  (file) => MessageTransferItem(
                    id: file.file.id,
                    fileName: file.desiredName ?? file.file.fileName,
                    fileType: file.file.fileType,
                    size: file.file.size,
                    path: file.path,
                    savedToGallery: file.savedToGallery,
                    errorMessage: file.errorMessage,
                  ),
                )
                .toList(growable: false),
            sessionId: session.sessionId,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        ),
      );
}

MessageTransferState _incomingTransferState(ReceiveSessionState? session) {
  if (session == null) {
    return MessageTransferState.canceled;
  }
  if (session.files.values.any((file) => file.status == FileStatus.failed)) {
    return MessageTransferState.failed;
  }
  if (session.files.values.map((file) => file.status).isFinishedOrError) {
    return MessageTransferState.completed;
  }
  if (session.files.values.any((file) => file.status == FileStatus.sending || file.status == FileStatus.finished)) {
    return MessageTransferState.receiving;
  }
  return MessageTransferState.pendingIncoming;
}

void _cancelBySender(ServerUtils server) {
  final receiveSession = server.getState().session;
  if (receiveSession == null) {
    return;
  }

  if (receiveSession.status == SessionStatus.waiting) {
    Routerino.context.popUntil(ReceivePage);
  }

  server.setState((oldState) => oldState?.copyWith(
        session: oldState.session?.copyWith(
          status: SessionStatus.canceledBySender,
          endTime: DateTime.now().millisecondsSinceEpoch,
        ),
      ));
  if (receiveSession.message == null) {
    unawaited(_upsertIncomingTransferEntry(
      server,
      server.getStateOrNull()?.session ?? receiveSession,
      MessageTransferState.canceled,
    ));
  }
}

extension on ReceiveSessionState {
  ReceiveSessionState fileFinished({
    required String fileId,
    required FileStatus status,
    required String? path,
    required bool savedToGallery,
    required String? errorMessage,
  }) {
    return copyWith(
      files: {...files}..update(
          fileId,
          (file) => file.copyWith(
            status: status,
            path: path,
            savedToGallery: savedToGallery,
            errorMessage: errorMessage,
          ),
        ),
    );
  }
}




