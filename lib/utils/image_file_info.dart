import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 读取实际图片文件的大小和尺寸，不解码整张图片。
class ImageFileInfo {
  final int fileSize;
  final int? width;
  final int? height;

  const ImageFileInfo(this.fileSize, {this.width, this.height});

  static Future<ImageFileInfo> fromFile(File file) async => _read(
      await file.length(), () => ui.ImmutableBuffer.fromFilePath(file.path));

  static Future<ImageFileInfo> fromBytes(Uint8List bytes) =>
      _read(bytes.length, () => ui.ImmutableBuffer.fromUint8List(bytes));

  static Future<ImageFileInfo> _read(
      int fileSize, Future<ui.ImmutableBuffer> Function() loadBuffer) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await loadBuffer();
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return ImageFileInfo(fileSize,
          width: descriptor.width, height: descriptor.height);
    } catch (_) {
      // 无法读取尺寸时仍展示文件大小。
      return ImageFileInfo(fileSize);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
