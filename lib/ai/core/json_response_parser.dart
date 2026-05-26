import 'dart:convert';

import '../../services/system/logger_service.dart';
import 'bill_info.dart';

/// AI 响应 JSON 解析器。
///
/// 容错策略(应对 AI 实际吐出的各种花样):
/// - **JSON 数组**:`[{...}, {...}]` 是默认 prompt 期望的格式
/// - **单 JSON 对象**:`{...}` 兼容老用户自定义 prompt
/// - **Markdown 包裹**:` ```json ... ``` ` 通过 balanced-block 提取自动跳过
/// - **trailing comma**:`{,}` / `[,]` AI 偶发生成 JSON5 风格,清理后再 parse
/// - **统一 sanitize**:amount 缺失/为 0 的丢弃;time 缺失/不可解析的兜底当前时间
///
/// 渠道层信任 `parse` 的输出 —— 返回的 list 已经做过 amount 校验和 time 兜底,
/// 可直接逐笔入库,**不需要**再做 `where((b) => b.amount != null && ...)` 之类
/// 的二次过滤。
class JsonResponseParser {
  static const String _tag = 'JsonResponseParser';

  const JsonResponseParser();

  /// 解析 AI 响应文本为 `List<BillInfo>`。返回空 list 表示无有效账单。
  List<BillInfo> parse(String response) {
    logger.debug(_tag, '原始响应: $response');

    // 数组路径优先 —— 新默认 prompt 期望此格式
    final arrayBlock = _extractBalancedBlock(response, '[', ']');
    if (arrayBlock != null) {
      try {
        final decoded = jsonDecode(_cleanupJson(arrayBlock));
        if (decoded is List) {
          final bills = <BillInfo>[];
          for (var i = 0; i < decoded.length; i++) {
            final item = decoded[i];
            if (item is! Map<String, dynamic>) {
              logger.warning(_tag, '数组第 ${i + 1} 项不是对象,跳过: $item');
              continue;
            }
            try {
              final raw = BillInfo.fromJson(item);
              final sanitized = _sanitize(raw);
              if (sanitized == null) {
                logger
                    .warning(_tag, '数组第 ${i + 1} 项金额无效,跳过: ${raw.toJson()}');
                continue;
              }
              bills.add(sanitized);
            } catch (e) {
              logger.warning(_tag, '数组第 ${i + 1} 项解析失败,跳过: $e');
            }
          }
          if (bills.isNotEmpty) {
            logger.info(_tag, '账单提取成功(数组): ${bills.length} 笔');
            return bills;
          }
          logger.warning(_tag, '数组中没有有效账单项');
          // 不直接 return,fallback 到单对象路径(防 AI 把单笔写成 `[]` 又附 `{...}`)
        }
      } catch (e) {
        logger.warning(_tag, '数组 JSON 解析失败,尝试单对象 fallback: $e');
      }
    }

    // Fallback: 单对象(旧格式 / 用户自定义老 prompt)
    final objectBlock = _extractBalancedBlock(response, '{', '}');
    if (objectBlock == null) {
      logger.warning(_tag, '响应中没有找到 JSON: $response');
      return const [];
    }
    try {
      final json = jsonDecode(_cleanupJson(objectBlock)) as Map<String, dynamic>;
      final raw = BillInfo.fromJson(json);
      final sanitized = _sanitize(raw);
      if (sanitized == null) {
        logger.warning(_tag, '单对象金额无效: ${raw.toJson()}');
        return const [];
      }
      logger.info(_tag, '账单提取成功(单对象): $sanitized');
      return [sanitized];
    } catch (e) {
      logger.warning(_tag, '单对象 JSON 解析失败: $e');
      return const [];
    }
  }

  /// 单笔统一校验 + 兜底。
  ///
  /// 返回 null = 该笔应丢弃(amount 缺失或为 0);
  /// 返回非 null = 已修正(time 缺失填当前时间),可直接入库。
  BillInfo? _sanitize(BillInfo bill) {
    final amt = bill.amount;
    if (amt == null || amt.abs() <= 0) return null;
    if (bill.time == null) {
      return bill.copyWith(time: DateTime.now());
    }
    return bill;
  }

  /// JSON5 容错清理 —— 去除引号外的 trailing comma(如 `{,}` / `[,]`)。
  ///
  /// 简单状态机:进入引号内的字符全部原样保留(避免误删 note 字段里用户输入
  /// 的「苹果, 香蕉」这类合法逗号),引号外的 `,` 如果其后跟 `}` 或 `]`
  /// (空白容忍)则丢弃。
  String _cleanupJson(String input) {
    final out = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (inString) {
        out.write(c);
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
        out.write(c);
        continue;
      }
      if (c == ',') {
        var j = i + 1;
        while (j < input.length &&
            (input[j] == ' ' ||
                input[j] == '\t' ||
                input[j] == '\n' ||
                input[j] == '\r')) {
          j++;
        }
        if (j < input.length && (input[j] == '}' || input[j] == ']')) {
          continue;
        }
      }
      out.write(c);
    }
    return out.toString();
  }

  /// 从文本中提取首个**配对完整**的 `[...]` 或 `{...}` 块。
  ///
  /// brace-balance 计数 + 字符串字面量识别,可以穿过 markdown 包裹
  /// (\`\`\`json ... \`\`\`) 和前后多余的解释文字。
  String? _extractBalancedBlock(String text, String open, String close) {
    final start = text.indexOf(open);
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == open) {
        depth++;
      } else if (c == close) {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }
}
