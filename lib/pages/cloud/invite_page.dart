import 'package:flutter/material.dart';
import '../../presentation/v4/bindings/cloud_shared_invite.dart';

class InvitePage extends StatelessWidget {
  const InvitePage(
      {super.key, required this.ledgerExternalId, required this.ledgerName});
  final String ledgerExternalId, ledgerName;
  @override
  Widget build(BuildContext context) => CloudSharedInviteControls(
      ledgerExternalId: ledgerExternalId, ledgerName: ledgerName);
}
