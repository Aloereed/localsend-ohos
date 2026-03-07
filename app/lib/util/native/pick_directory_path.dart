import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart'
    as android_channel;
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';

Future<String?> pickDirectoryPath(BuildContext context) async {
  if (defaultTargetPlatform == TargetPlatform.android &&
      (RefenaScope.defaultRef.read(deviceRawInfoProvider).androidSdkInt ?? 0) >=
          android_channel.contentUriMinSdk) {
    return android_channel.pickDirectoryPathAndroid();
  }

  if (checkPlatform([TargetPlatform.android, TargetPlatform.iOS])) {
    return FilePicker.platform.getDirectoryPath();
  } else if (checkPlatform([TargetPlatform.ohos])) {
    return _showOhosDirectoryPicker(context);
  } else {
    return file_selector.getDirectoryPath();
  }
}

Future<String?> _showOhosDirectoryPicker(BuildContext context) async {
  const baseDirectory =
      '/storage/Users/currentUser/Download/com.aloereed.aloesend';
  if (!await Directory(baseDirectory).exists()) {
    await Directory(baseDirectory).create(recursive: true);
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) => _OhosDirectoryPickerDialog(baseDirectory: baseDirectory),
  );
}

class _OhosDirectoryPickerDialog extends StatefulWidget {
  final String baseDirectory;

  const _OhosDirectoryPickerDialog({required this.baseDirectory});

  @override
  State<_OhosDirectoryPickerDialog> createState() =>
      _OhosDirectoryPickerDialogState();
}

class _OhosDirectoryPickerDialogState extends State<_OhosDirectoryPickerDialog> {
  late String currentPath;
  List<Directory> directories = [];
  bool isLoading = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    currentPath = widget.baseDirectory;
    _loadDirectories();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadDirectories() async {
    if (_isDisposed) {
      return;
    }
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final dir = Directory(currentPath);
      final entities = await dir.list().toList();
      final dirs = entities
          .whereType<Directory>()
          .where((d) => !path.basename(d.path).startsWith('.'))
          .toList()
        ..sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

      if (!_isDisposed && mounted) {
        setState(() {
          directories = dirs;
          isLoading = false;
        });
      }
    } catch (_) {
      if (!_isDisposed && mounted) {
        setState(() {
          directories = [];
          isLoading = false;
        });
      }
    }
  }

  void _navigateToDirectory(String dirPath) {
    if (_isDisposed || !mounted) {
      return;
    }

    setState(() {
      currentPath = dirPath;
    });
    _loadDirectories();
  }

  void _navigateUp() {
    if (_isDisposed || !mounted) {
      return;
    }

    if (currentPath != widget.baseDirectory) {
      final parentPath = Directory(currentPath).parent.path;
      if (parentPath.startsWith(widget.baseDirectory)) {
        _navigateToDirectory(parentPath);
      }
    }
  }

  void _selectCurrentFolder() {
    if (_isDisposed || !mounted) {
      return;
    }
    Navigator.of(context).pop(currentPath);
  }

  void _cancel() {
    if (_isDisposed || !mounted) {
      return;
    }
    Navigator.of(context).pop(null);
  }

  String _getRelativePath() {
    if (currentPath == widget.baseDirectory) {
      return 'Download/AloeSend';
    }
    return currentPath.substring(widget.baseDirectory.length + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async => true,
      child: ModernDialogScaffold(
        title: 'Choose Folder',
        subtitle: 'Only directories accessible to the app are shown.',
        maxWidth: MediaQuery.of(context).size.width * 0.9,
        onClose: _cancel,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.66,
          child: Column(
            children: [
              GlassSurface(
                applyBlur: false,
                borderRadius: BorderRadius.circular(20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    if (currentPath != widget.baseDirectory) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        onPressed: _navigateUp,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        _getRelativePath(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                      )
                    : directories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_off_outlined,
                                  size: 64,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'This folder is empty',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: colorScheme.outline),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: directories.length,
                            itemBuilder: (context, index) {
                              final dir = directories[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ModernActionTile(
                                  icon: Icons.folder_rounded,
                                  title: path.basename(dir.path),
                                  subtitle: dir.path,
                                  onTap: () => _navigateToDirectory(dir.path),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
          FilledButton(
            onPressed: _selectCurrentFolder,
            child: const Text('Use This Folder'),
          ),
        ],
      ),
    );
  }
}
