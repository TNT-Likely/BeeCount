import 'dart:collection';

import '../contracts.dart';
import '../protocol/native_tool_protocol.dart';

typedef AgentToolQueryMatcher = bool Function(String normalizedQuery);

/// One reusable declaration for a native tool, its local executor, and the
/// metadata used to decide whether its schema belongs in a model request.
///
/// Business applications still own the actual names, descriptions, schemas,
/// and implementations. The registry only provides generic validation and a
/// small deterministic selector, so hosts do not need an LLM call merely to
/// decide which tool schemas to expose.
final class AgentToolDescriptor {
  AgentToolDescriptor({
    required this.definition,
    required this.tool,
    this.isResident = false,
    Iterable<String> selectionTerms = const [],
    this.singleUse = false,
    this.deduplicate = false,
    this.selectionMatcher,
  }) : selectionTerms = UnmodifiableListView(
          selectionTerms
              .map((term) => term.trim().toLowerCase())
              .where((term) => term.isNotEmpty)
              .toSet()
              .toList(growable: false),
        ) {
    if (definition.name != tool.name) {
      throw ArgumentError(
        '工具定义名称 ${definition.name} 与执行器名称 ${tool.name} 不一致。',
      );
    }
  }

  final AgentNativeToolDefinition definition;
  final AgentTool tool;
  final bool isResident;
  final List<String> selectionTerms;
  final bool singleUse;
  final bool deduplicate;

  final AgentToolQueryMatcher? selectionMatcher;
}

/// The immutable subset of a registry made available to one Agent run.
final class AgentToolSelection {
  AgentToolSelection(
    Iterable<AgentToolDescriptor> descriptors,
  ) : descriptors = UnmodifiableListView(
          List<AgentToolDescriptor>.of(descriptors, growable: false),
        );

  final List<AgentToolDescriptor> descriptors;

  Set<String> get names => UnmodifiableSetView(
        descriptors.map((descriptor) => descriptor.definition.name).toSet(),
      );

  List<AgentNativeToolDefinition> get definitions => List.unmodifiable(
        descriptors.map((descriptor) => descriptor.definition),
      );

  Map<String, AgentTool> get tools => Map.unmodifiable({
        for (final descriptor in descriptors)
          descriptor.tool.name: descriptor.tool,
      });

  Set<String> get singleUseToolNames => UnmodifiableSetView({
        for (final descriptor in descriptors)
          if (descriptor.singleUse) descriptor.tool.name,
      });

  Set<String> get deduplicatedToolNames => UnmodifiableSetView({
        for (final descriptor in descriptors)
          if (descriptor.deduplicate) descriptor.tool.name,
      });
}

/// Validates a complete tool catalog and selects a bounded request-specific
/// subset using resident flags plus host-provided terms and explicit names.
///
/// This is intentionally lexical and deterministic. Applications can replace
/// the selection policy with a richer router while retaining the same
/// descriptor and selection contracts.
final class AgentToolRegistry {
  AgentToolRegistry(Iterable<AgentToolDescriptor> descriptors)
      : _descriptors = UnmodifiableListView(
          List<AgentToolDescriptor>.of(descriptors, growable: false),
        ) {
    final names = <String>{};
    for (final descriptor in _descriptors) {
      if (!names.add(descriptor.definition.name)) {
        throw ArgumentError('重复注册 Agent 工具：${descriptor.definition.name}');
      }
    }
  }

  final List<AgentToolDescriptor> _descriptors;

  List<AgentToolDescriptor> get descriptors => _descriptors;

  AgentToolDescriptor? find(String name) {
    for (final descriptor in _descriptors) {
      if (descriptor.definition.name == name) return descriptor;
    }
    return null;
  }

  AgentToolSelection select(
    String query, {
    Iterable<String> includeToolNames = const [],
    int? maximumTools,
  }) {
    final normalized = query.trim().toLowerCase();
    final explicitNames = includeToolNames.toSet();
    final scored = <({AgentToolDescriptor descriptor, int score})>[];
    for (final descriptor in _descriptors) {
      var score = descriptor.isResident ? 100000 : 0;
      if (explicitNames.contains(descriptor.definition.name)) score += 100000;
      for (final term in descriptor.selectionTerms) {
        if (normalized.contains(term)) {
          score += 1000 + term.length;
        }
      }
      if (descriptor.selectionMatcher?.call(normalized) ?? false) {
        score += 2000;
      }
      if (score > 0) scored.add((descriptor: descriptor, score: score));
    }
    scored.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) return byScore;
      return left.descriptor.definition.name
          .compareTo(right.descriptor.definition.name);
    });
    final limit =
        maximumTools == null || maximumTools < 1 ? scored.length : maximumTools;
    final selected = scored.take(limit).map((item) => item.descriptor).toList();
    return AgentToolSelection(selected);
  }
}
