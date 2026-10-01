import 'dart:io';

/// Host-side entry point: Flutter is needed for the App adapter, but evaluation
/// uses a memory database and never installs or launches the simulator App.
Future<void> main(List<String> arguments) async {
  var live = false;
  var filter = '';
  String? output;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--live':
        live = true;
      case '--filter':
      case '--output':
        final option = arguments[index];
        if (index + 1 >= arguments.length ||
            arguments[index + 1].startsWith('--')) {
          stderr.writeln('Missing value for $option');
          exitCode = 2;
          return;
        }
        final value = arguments[++index];
        if (option == '--filter') {
          filter = value;
        } else {
          output = value;
        }
      case '--help':
        stdout.writeln(
            'dart run tool/ai_eval.dart [--live] [--filter ID-or-tag] [--output path-prefix]\n'
            'Live mode requires AI_EVAL_BASE_URL / AI_EVAL_MODEL / AI_EVAL_API_KEY.\n'
            'Default: offline tool regression; reports in build/ai-eval/.');
        return;
      default:
        stderr.writeln('Unknown option: ${arguments[index]}');
        exitCode = 2;
        return;
    }
  }
  if (!File('test/ai_eval/fixtures/readonly_cases_v1.json').existsSync()) {
    stderr.writeln('Run from the repository root.');
    exitCode = 2;
    return;
  }
  if (live &&
      ['AI_EVAL_BASE_URL', 'AI_EVAL_MODEL', 'AI_EVAL_API_KEY']
          .any((key) => (Platform.environment[key] ?? '').trim().isEmpty)) {
    stderr.writeln(
        'Live mode requires AI_EVAL_BASE_URL / AI_EVAL_MODEL / AI_EVAL_API_KEY.');
    exitCode = 2;
    return;
  }
  final revision = await Process.run('git', ['rev-parse', 'HEAD']);
  final status = await Process.run('git', ['status', '--porcelain']);
  final process = await Process.start('flutter', [
    'test',
    '--reporter',
    'expanded',
    'test/ai_eval/assistant_eval_test.dart',
  ], environment: {
    'TZ': 'Asia/Shanghai',
    'AI_EVAL_MODE': live ? 'live' : 'offline',
    'AI_EVAL_FILTER': filter,
    'AI_EVAL_OUTPUT': output ?? 'build/ai-eval/${live ? 'live' : 'offline'}',
    'AI_EVAL_REVISION':
        revision.exitCode == 0 ? '${revision.stdout}'.trim() : 'unknown',
    'AI_EVAL_DIRTY': '${status.stdout}'.trim().isNotEmpty ? 'true' : 'false',
  });
  await Future.wait(
      [stdout.addStream(process.stdout), stderr.addStream(process.stderr)]);
  exitCode = await process.exitCode;
}
