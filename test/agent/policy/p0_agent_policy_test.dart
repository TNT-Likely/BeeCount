import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/policy/p0_agent_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = P0AgentPolicy();

  AgentRequest request({
    String text = '午饭 35',
    bool isForeground = true,
    bool allowsExplicitMemory = false,
  }) =>
      AgentRequest(
        text: text,
        scope: AgentScope(
          id: 'user-1',
          ledgerId: 1,
          isForeground: isForeground,
          allowsExplicitMemory: allowsExplicitMemory,
        ),
      );

  test('P0 policy permits record only for the current foreground user text',
      () {
    final allowed = policy.decide(
      request(),
      AgentToolCall(
        name: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 35'},
      ),
    );
    final denied = policy.decide(
      request(),
      AgentToolCall(
        name: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 36'},
      ),
    );

    expect(allowed.isAllowed, isTrue);
    expect(denied.isAllowed, isFalse);
  });

  test('P0 policy denies background writes and cross-ledger reads', () {
    final backgroundWrite = policy.decide(
      request(isForeground: false),
      AgentToolCall(
        name: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 35'},
      ),
    );
    final crossLedgerRead = policy.decide(
      request(),
      AgentToolCall(
        name: 'query_transactions',
        arguments: const {'ledgerId': 2},
      ),
    );

    expect(backgroundWrite.isAllowed, isFalse);
    expect(crossLedgerRead.isAllowed, isFalse);
  });

  test('P0 policy only permits explicit memory changes when user opted in', () {
    final denied = policy.decide(
      request(),
      AgentToolCall(
        name: 'save_explicit_memory',
        arguments: const {'content': '咖啡用微信'},
      ),
    );
    final allowed = policy.decide(
      request(allowsExplicitMemory: true),
      AgentToolCall(
        name: 'save_explicit_memory',
        arguments: const {'content': '咖啡用微信'},
      ),
    );

    expect(denied.isAllowed, isFalse);
    expect(allowed.isAllowed, isTrue);
  });
}
