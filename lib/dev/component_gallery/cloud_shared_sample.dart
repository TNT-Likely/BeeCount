import 'package:beecount_business_ui/cloud_shared.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizations_resolver.dart';

/// Controlled fixtures. Optional live content must be supplied by the App host.
class CloudSharedSample extends StatefulWidget {
  const CloudSharedSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<CloudSharedSample> createState() => _CloudSharedSampleState();
}

class _CloudSharedSampleState extends State<CloudSharedSample> {
  int hours = 24;
  bool generated = false;
  String event = '共享账本局部示例，不生成真实邀请或修改成员';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!generated)
        BeeCloudSharedInviteForm(
            roleLabel: l.sharedInviteFormRole,
            role: l.sharedRoleEditor,
            expiryLabel: l.sharedInviteFormExpiry,
            expiryOptions: {
              for (final h in [24, 72, 168])
                h: l.sharedInviteExpiryDays(h ~/ 24)
            },
            selectedHours: hours,
            onExpiry: (h) => setState(() => hours = h),
            generateLabel: l.sharedInviteGenerate,
            onGenerate: () => setState(() => generated = true),
            warning: l.sharedInviteWarning)
      else
        BeeCloudSharedInviteCode(
            code: 'ABC 234',
            expiry: l.sharedInviteExpiresAt('2026-10-28 09:41'),
            copyCodeLabel: l.sharedInviteCopyCode,
            shareLabel: l.sharedInviteShareLink,
            copyLinkLabel: l.sharedInviteCopyLink,
            instruction: l.sharedInviteInstruction,
            anotherLabel: l.sharedInviteGenerateAnother,
            onCopyCode: () => setState(() => event = '示例复制代码'),
            onShare: () => setState(() => event = '示例分享链接'),
            onCopyLink: () => setState(() => event = '示例复制链接'),
            onAnother: () => setState(() => generated = false)),
      const SizedBox(height: 12),
      BeeCloudSharedCard(
          child: Column(children: [
        BeeCloudSharedMemberRow(
            avatar: const CircleAvatar(child: Text('A')),
            name: 'Alex',
            email: 'qa-owner@example.invalid',
            role: l.sharedRoleOwner,
            selfLabel: l.sharedMembersYou),
        const Divider(height: 1),
        BeeCloudSharedMemberRow(
            avatar: const CircleAvatar(child: Text('B')),
            name: 'Blair',
            email: 'qa-editor@example.invalid',
            role: l.sharedRoleEditor,
            removeLabel: l.sharedMembersRemoveCta,
            onRemove: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                        title: Text(l.sharedMembersRemoveTitle),
                        content: Text(l.sharedMembersRemoveConfirm('Blair')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l.commonCancel)),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => event = '示例移除回调，不请求服务');
                              },
                              child: Text(l.commonRemove))
                        ]))),
      ])),
      const SizedBox(height: 12),
      BeeCloudSharedCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.syncHealthTitle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        BeeCloudSharedHealthRow(
            label: l.syncHealthRowTx,
            value: l.syncHealthValue(27, 26),
            warning: true),
        BeeCloudSharedHealthRow(
            label: l.syncHealthRowUnpushed, value: '1', warning: true)
      ])),
      const SizedBox(height: 12),
      Text(event,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      if (widget.liveData != null) ...[
        const SizedBox(height: 12),
        widget.liveData!
      ],
    ]);
  }
}
