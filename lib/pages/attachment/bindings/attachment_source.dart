import 'dart:io';

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/attachment_service.dart';

enum _AttachmentSource { camera, gallery }

/// Shared App binding: the UI package never requests permissions or files.
Future<List<File>> pickAttachmentFiles(BuildContext context, WidgetRef ref,
    {required int remaining}) async {
  if (remaining <= 0) return [];
  final l10n = AppLocalizations.of(context);
  final source = await showBeeSheet<_AttachmentSource>(context,
      title: l10n.attachmentAdd,
      child: BeeAttachmentSources(
          cameraLabel: l10n.attachmentTakePhoto,
          galleryLabel: l10n.attachmentChooseFromGallery,
          onCamera: () => Navigator.pop(context, _AttachmentSource.camera),
          onGallery: () => Navigator.pop(context, _AttachmentSource.gallery)));
  if (source == null || !context.mounted) return [];
  final service = ref.read(attachmentServiceProvider);
  if (source == _AttachmentSource.gallery) {
    return service.pickFromGallery(maxCount: remaining);
  }
  final file = await service.takePhoto();
  return file == null ? [] : [file];
}
