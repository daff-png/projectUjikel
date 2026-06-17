import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String?> saveExportFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final safeFilename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final targetDir = await _resolveDownloadDirectory();
  final file = File('${targetDir.path}${Platform.pathSeparator}$safeFilename');

  try {
    await targetDir.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    final fallback = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$safeFilename',
    );
    await fallback.writeAsBytes(bytes, flush: true);
    return fallback.path;
  }
}

Future<Directory> _resolveDownloadDirectory() async {
  if (Platform.isAndroid) {
    try {
      final directories = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (directories != null && directories.isNotEmpty) {
        return directories.first;
      }
    } catch (_) {
      // ignore and fallback
    }
    return Directory('/storage/emulated/0/Download');
  }

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  }

  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null && profile.isNotEmpty) {
      return Directory('$profile${Platform.pathSeparator}Downloads');
    }
  }

  if (Platform.isLinux || Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}Downloads');
    }
  }

  return Directory.systemTemp;
}
