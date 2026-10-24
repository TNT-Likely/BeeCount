import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TagLibraryMissingPath implements Exception {}

/// Platform I/O is an App adapter, independent of the controlled tag widgets.
class TagLibraryFiles {
  const TagLibraryFiles();
  Future<String?> pick() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['yml', 'yaml']);
    } catch (_) {
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    }
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) throw TagLibraryMissingPath();
    return path;
  }

  Future<String> read(String path) => File(path).readAsString();

  /// Android retains the original Download/BeeCount destination; other platforms
  /// keep the existing system-share route.
  Future<String?> share(String yaml, String subject) async {
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final directory = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download/BeeCount')
        : await getTemporaryDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}/beecount_tags_$stamp.yml');
    await file.writeAsString(yaml);
    if (Platform.isAndroid) {
      return file.path.replaceAll('/storage/emulated/0/', '');
    }
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], subject: subject));
    return null;
  }
}
