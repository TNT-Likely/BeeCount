import 'package:agentcore/agentcore.dart';
import 'package:test/test.dart';

void main() {
  test('selects resident tools and request-matched tools', () {
    final registry = AgentToolRegistry([
      _descriptor('record', resident: true),
      _descriptor('budget', terms: const ['预算', 'budget']),
      _descriptor('recurring', terms: const ['周期', '订阅']),
    ]);

    final selection = registry.select('看看这个月的预算');

    expect(selection.names, {'record', 'budget'});
    expect(selection.tools.keys, {'record', 'budget'});
    expect(selection.definitions.map((item) => item.name),
        containsAll(['record', 'budget']));
  });

  test('validates definition and executor names', () {
    expect(
      () => AgentToolDescriptor(
        definition: const AgentNativeToolDefinition(
          name: 'definition',
          description: 'test',
          parameters: {'type': 'object'},
        ),
        tool: const _Tool('executor'),
      ),
      throwsArgumentError,
    );
  });

  test('exposes execution policies from the selected descriptors', () {
    final selection = AgentToolRegistry([
      _descriptor('write', resident: true, singleUse: true),
      _descriptor('read', resident: true, deduplicate: true),
    ]).select('anything');

    expect(selection.singleUseToolNames, {'write'});
    expect(selection.deduplicatedToolNames, {'read'});
  });

  test('reports only matched selected tools that require execution', () {
    final selection = AgentToolRegistry([
      _descriptor(
        'trend',
        resident: true,
        terms: const ['各月'],
        requiresExecutionOnMatch: true,
      ),
      _descriptor(
        'budget',
        terms: const ['预算'],
        requiresExecutionOnMatch: true,
      ),
      _descriptor('chat', resident: true),
    ]).select('对比各月支出');

    expect(selection.requiredToolNames, {'trend'});
  });

  test('supports a host-defined deterministic query matcher', () {
    final selection = AgentToolRegistry([
      _descriptor(
        'record',
        resident: true,
        matcher: (query) => RegExp(r'\d').hasMatch(query),
        requiresExecutionOnMatch: true,
      ),
    ]).select('lunch 35');

    expect(selection.requiredToolNames, {'record'});
  });

  test('can search conversation context but require tools from current text',
      () {
    final registry = AgentToolRegistry([
      _descriptor(
        'record',
        terms: const ['记账'],
        requiresExecutionOnMatch: true,
      ),
      _descriptor('budget', terms: const ['预算']),
    ]);

    final selection = registry.select(
      '谢谢\n上一轮请记账并查看预算',
      requirementQuery: '谢谢',
    );

    expect(selection.names, {'record', 'budget'});
    expect(selection.requiredToolNames, isEmpty);
  });
}

AgentToolDescriptor _descriptor(
  String name, {
  bool resident = false,
  List<String> terms = const [],
  bool singleUse = false,
  bool deduplicate = false,
  bool requiresExecutionOnMatch = false,
  AgentToolQueryMatcher? matcher,
}) =>
    AgentToolDescriptor(
      definition: AgentNativeToolDefinition(
        name: name,
        description: name,
        parameters: const {'type': 'object'},
      ),
      tool: _Tool(name),
      isResident: resident,
      selectionTerms: terms,
      singleUse: singleUse,
      deduplicate: deduplicate,
      requiresExecutionOnMatch: requiresExecutionOnMatch,
      selectionMatcher: matcher,
    );

final class _Tool implements AgentTool {
  const _Tool(this.name);

  @override
  final String name;

  @override
  Future<Map<String, Object?>> execute(AgentToolCall call) async => const {};
}
