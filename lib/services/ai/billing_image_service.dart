import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/image_file_info.dart';

/// 图片附件与 AI 识别图片分别管理，避免识别压缩损失附件原图。
class BillingImageFiles {
  final File attachment;
  final File recognition;
  final Directory? _temporaryDirectory;

  const BillingImageFiles(this.attachment, this.recognition,
      [this._temporaryDirectory]);

  Future<void> dispose() async {
    final directory = _temporaryDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class BillingImageService {
  static const maxDimension = 1920;
  static const quality = 85;

  final ImagePicker _picker;
  final Future<Directory> Function() _getTemporaryDirectory;

  BillingImageService({
    ImagePicker? picker,
    Future<Directory> Function()? temporaryDirectory,
  })  : _picker = picker ?? ImagePicker(),
        _getTemporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  Future<File?> pickImage(ImageSource source,
      {required bool keepOriginal}) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: keepOriginal ? null : maxDimension.toDouble(),
      maxHeight: keepOriginal ? null : maxDimension.toDouble(),
      imageQuality: keepOriginal ? null : quality,
    );
    return image == null ? null : File(image.path);
  }

  Future<BillingImageFiles> prepare(File file,
      {required bool keepOriginal}) async {
    if (!keepOriginal) return BillingImageFiles(file, file);

    final info = await ImageFileInfo.fromFile(file);
    final width = info.width;
    final height = info.height;
    if (width == null || height == null) {
      throw const FormatException('无法读取识别图片尺寸');
    }
    final scale = math.min(1.0, maxDimension / math.max(width, height));
    final targetWidth = math.max(1, (width * scale).floor());
    final targetHeight = math.max(1, (height * scale).floor());

    final parent = await _getTemporaryDirectory();
    final directory = await parent.createTemp('billing-image-');
    ui.Codec? codec;
    ui.Image? image;
    try {
      // 先按最长边限制解码。压缩插件的 minWidth/minHeight 并非最大尺寸，
      // 直接传 1920 会让窄长截图仍保留过大的高度。
      codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('无法生成识别图片');
      final compressed = await FlutterImageCompress.compressWithList(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: quality,
      );
      if (compressed.isEmpty) throw StateError('识别图片压缩失败');
      final recognition = await File('${directory.path}/recognition.jpg')
          .writeAsBytes(compressed);
      return BillingImageFiles(file, recognition, directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
