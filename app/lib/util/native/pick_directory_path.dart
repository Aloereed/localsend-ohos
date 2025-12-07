import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart'
    as android_channel;
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Opens a file picker to select a directory.
/// Returns null if the user cancels the selection.
Future<String?> pickDirectoryPath(BuildContext context) async {
  if (defaultTargetPlatform == TargetPlatform.android &&
      (RefenaScope.defaultRef.read(deviceRawInfoProvider).androidSdkInt ?? 0) >=
          android_channel.contentUriMinSdk) {
    return await android_channel.pickDirectoryPathAndroid();
  }

  if (checkPlatform([TargetPlatform.android, TargetPlatform.iOS])) {
    /// We need to use the file_picker package because file_selector does not expose the raw path.
    /// We need the raw path to properly manipulate the path to save new files, or
    /// to list files recursively.
    /// Also, on iOS, file_selector does not work with directories.
    return await FilePicker.platform.getDirectoryPath();
  } else if (checkPlatform([TargetPlatform.ohos])) {
    /// For OHOS, due to permission restrictions, we need to create a custom dialog
    /// to let users select folders under /storage/Users/currentUser/Download/com.aloereed.aloesend
    return await _showOhosDirectoryPicker(context);
  } else {
    return await file_selector.getDirectoryPath();
  }
}

Future<String?> _showOhosDirectoryPicker(BuildContext context) async {
  const String baseDirectory = '/storage/Users/currentUser/Download/com.aloereed.aloesend';
  // if baseDir not exists, create it
  if (!await Directory(baseDirectory).exists()) {
    await Directory(baseDirectory).create(recursive: true);
  }
  return await showDialog<String>(
    context: context,
    barrierDismissible: true, // 允许点击外部关闭
    barrierColor: Colors.black54,
    builder: (context) => _OhosDirectoryPickerDialog(baseDirectory: baseDirectory),
  );
}

class _OhosDirectoryPickerDialog extends StatefulWidget {
  final String baseDirectory;

  const _OhosDirectoryPickerDialog({required this.baseDirectory});

  @override
  State<_OhosDirectoryPickerDialog> createState() => _OhosDirectoryPickerDialogState();
}

class _OhosDirectoryPickerDialogState extends State<_OhosDirectoryPickerDialog> {
  late String currentPath;
  List<Directory> directories = [];
  bool isLoading = true;
  bool _isDisposed = false; // 添加状态标记

  @override
  void initState() {
    super.initState();
    currentPath = widget.baseDirectory;
    _loadDirectories();
  }

  @override
  void dispose() {
    _isDisposed = true; // 标记为已销毁
    super.dispose();
  }

  Future<void> _loadDirectories() async {
    if (_isDisposed) return; // 如果已销毁，不执行
    
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
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          directories = [];
          isLoading = false;
        });
      }
    }
  }

  void _navigateToDirectory(String dirPath) {
    if (_isDisposed || !mounted) return;
    
    setState(() {
      currentPath = dirPath;
    });
    _loadDirectories();
  }

  void _navigateUp() {
    if (_isDisposed || !mounted) return;
    
    if (currentPath != widget.baseDirectory) {
      final parentPath = Directory(currentPath).parent.path;
      if (parentPath.startsWith(widget.baseDirectory)) {
        _navigateToDirectory(parentPath);
      }
    }
  }

  void _selectCurrentFolder() {
    if (_isDisposed || !mounted) return;
    Navigator.of(context).pop(currentPath);
  }

  void _cancel() {
    if (_isDisposed || !mounted) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        // 确保可以通过返回键关闭
        return true;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[900]!.withOpacity(0.85)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_open,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '选择文件夹',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _cancel,
                              color: colorScheme.onSurface,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Breadcrumb
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              if (currentPath != widget.baseDirectory)
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, size: 20),
                                  onPressed: _navigateUp,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              if (currentPath != widget.baseDirectory)
                                const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getRelativePath(),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Directory list
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
                                      '此文件夹为空',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: directories.length,
                                itemBuilder: (context, index) {
                                  final dir = directories[index];
                                  final dirName = path.basename(dir.path);

                                  return InkWell(
                                    onTap: () => _navigateToDirectory(dir.path),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.folder,
                                            color: colorScheme.primary,
                                            size: 32,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              dirName,
                                              style: Theme.of(context).textTheme.bodyLarge,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: colorScheme.outline,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Bottom actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _selectCurrentFolder,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('选择此文件夹'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}