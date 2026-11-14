import 'package:flutter/material.dart';
import 'shared/bindings/cloud_shared_join_shared_ledger.dart';

class JoinSharedLedgerPage extends StatelessWidget {
  const JoinSharedLedgerPage({super.key, this.prefilledCode});
  final String? prefilledCode;
  @override
  Widget build(BuildContext context) =>
      CloudSharedJoinControls(prefilledCode: prefilledCode);
}
