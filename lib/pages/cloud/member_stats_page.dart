import 'package:flutter/material.dart';
import 'shared/bindings/cloud_shared_member_stats.dart';

class MemberStatsPage extends StatelessWidget {
  const MemberStatsPage(
      {super.key, required this.ledgerExternalId, required this.ledgerName});
  final String ledgerExternalId, ledgerName;
  @override
  Widget build(BuildContext context) => CloudSharedStatsControls(
      ledgerExternalId: ledgerExternalId, ledgerName: ledgerName);
}
