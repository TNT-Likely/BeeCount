import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../ai/providers/ai_provider_config.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../providers/ai_chat_providers.dart';
import '../services/attachment_service.dart';
import '../services/billing/post_processor.dart';
import '../services/data/tag_seed_service.dart';
import '../widgets/ui/ui.dart';

/// 图片记账入口(相册/相机)。瘦身后:UI 流程 + 兜底,业务调 [AiBookkeeper]。
class ImageBillingHelper {
  /// 从相册选择图片并自动记账
  static Future<void> pickImageForBilling(
    BuildContext context,
    WidgetRef ref,
  ) =>
      _processImageBilling(context, ref, ImageSource.gallery);

  /// 打开相机拍照并自动记账
  static Future<void> openCameraForBilling(
    BuildContext context,
    WidgetRef ref,
  ) =>
      _processImageBilling(context, ref, ImageSource.camera);

  static Future<void> _processImageBilling(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final l10n = AppLocalizations.of(context);

    try {
      // 1. 选图
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      if (!context.mounted) return;

      // 2. 显示 loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.aiOcrRecognizing),
                ],
              ),
            ),
          ),
        ),
      );

      final imageFile = File(pickedFile.path);

      // 3. AI vision 兜底
      if (!await AIProviderManager.isCapabilityConfigured(
          AICapabilityType.vision)) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        showToast(context, l10n.aiNotConfiguredHint);
        return;
      }

      // 4. 当前账本
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        showToast(context, l10n.aiOcrNoLedger);
        return;
      }

      // 5. 委托 AiBookkeeper(自动查 categories/accounts + 多笔保存)
      final autoAddAttachment = ref.read(smartBillingAutoAttachmentProvider);
      final billingTypes = <String>[
        source == ImageSource.gallery
            ? TagSeedService.billingTypeImage
            : TagSeedService.billingTypeCamera,
        TagSeedService.billingTypeAi,
      ];

      final attachmentService = ref.read(attachmentServiceProvider);
      final bookkeeper = ref.read(aiBookkeeperProvider);
      final result = await bookkeeper.fromImage(
        image: imageFile,
        ledgerId: currentLedger.id,
        billingTypes: billingTypes,
        l10n: l10n,
        // 多笔时每笔都挂同一张原图,方便后续从任意一笔溯源
        onSaved: autoAddAttachment
            ? (txId, _) => attachmentService.saveAttachment(
                  transactionId: txId,
                  sourceFile: imageFile,
                  index: 0,
                )
            : null,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();

      // 6. 提示用户
      if (!result.success) {
        showToast(context, l10n.aiOcrCheckLog);
        return;
      }

      await PostProcessor.run(
        ref,
        ledgerId: currentLedger.id,
        tags: true,
        attachments: autoAddAttachment,
      );
      if (!context.mounted) return;

      final firstBill = result.firstBill!;
      final typeText = firstBill.type?.name == 'income'
          ? l10n.aiTypeIncome
          : l10n.aiTypeExpense;
      final amountStr = result.totalAbsAmount.toStringAsFixed(2);
      final toastText = result.isMulti
          ? '${l10n.aiOcrSuccess(typeText, amountStr)} × ${result.savedCount}'
          : l10n.aiOcrSuccess(typeText, amountStr);
      showToast(context, toastText);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      showToast(context, l10n.aiOcrFailed(e.toString()));
    }
  }
}
