import 'dart:convert';
import 'dart:io';

final RegExp _hangulRegex = RegExp(r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AF]');

const Set<String> _scanExtensions = {
  '.dart',
  '.yaml',
  '.yml',
  '.kt',
  '.kts',
  '.java',
  '.swift',
  '.m',
  '.mm',
  '.h',
  '.hpp',
  '.c',
  '.cc',
  '.cpp',
  '.js',
  '.jsx',
  '.ts',
  '.tsx',
  '.json',
  '.xml',
};

const Set<String> _excludedDirNames = {
  '.git',
  '.dart_tool',
  'build',
  '.idea',
  '.vscode',
  '.climpire-worktrees',
};

void main(List<String> args) {
  final bool strictStrings = args.contains('--strict-strings');
  final allowlist = _loadAllowlist();
  final violations = <_Violation>[];

  for (final entity in Directory.current.listSync(recursive: true)) {
    if (entity is! File) {
      continue;
    }

    final relativePath = _toRelativePath(entity.path);
    if (_isExcludedPath(relativePath)) {
      continue;
    }

    final extension = _extensionOf(relativePath);
    if (!_scanExtensions.contains(extension)) {
      continue;
    }

    _scanFile(entity, relativePath, allowlist, violations);
  }

  final commentViolations = violations
      .where((v) => v.category == _ViolationCategory.comment)
      .toList();
  final stringViolations = violations
      .where((v) => v.category == _ViolationCategory.string)
      .toList();

  stdout.writeln('Korean policy report');
  stdout.writeln('- comment violations: ${commentViolations.length}');
  stdout.writeln('- string violations: ${stringViolations.length}');
  stdout.writeln('- strict string mode: $strictStrings');

  for (final violation in violations.take(80)) {
    stdout.writeln(
      '  [${violation.category.name}] ${violation.path}:${violation.line} ${violation.preview}',
    );
  }

  if (violations.length > 80) {
    stdout.writeln('  ... ${violations.length - 80} more');
  }

  final hasFailingComments = commentViolations.isNotEmpty;
  final hasFailingStrings = strictStrings && stringViolations.isNotEmpty;
  if (hasFailingComments || hasFailingStrings) {
    stderr.writeln('Policy gate failed.');
    exit(1);
  }
}

void _scanFile(
  File file,
  String relativePath,
  _Allowlist allowlist,
  List<_Violation> violations,
) {
  final lines = file.readAsLinesSync();
  bool inSlashBlockComment = false;
  bool inXmlBlockComment = false;

  for (var i = 0; i < lines.length; i++) {
    final lineNumber = i + 1;
    final line = lines[i];

    if (!_hangulRegex.hasMatch(line)) {
      if (line.contains('/*')) {
        inSlashBlockComment = true;
      }
      if (line.contains('*/')) {
        inSlashBlockComment = false;
      }
      if (line.contains('<!--')) {
        inXmlBlockComment = true;
      }
      if (line.contains('-->')) {
        inXmlBlockComment = false;
      }
      continue;
    }

    final isComment =
        inSlashBlockComment ||
        inXmlBlockComment ||
        _looksLikeCommentLine(line, relativePath);
    final isString = _looksLikeStringLiteralLine(line);

    if (!isComment && !isString) {
      continue;
    }

    final preview = line.trim();
    if (allowlist.isAllowed(relativePath, preview)) {
      continue;
    }

    violations.add(
      _Violation(
        path: relativePath,
        line: lineNumber,
        preview: preview,
        category: isComment ? _ViolationCategory.comment : _ViolationCategory.string,
      ),
    );

    if (line.contains('/*')) {
      inSlashBlockComment = true;
    }
    if (line.contains('*/')) {
      inSlashBlockComment = false;
    }
    if (line.contains('<!--')) {
      inXmlBlockComment = true;
    }
    if (line.contains('-->')) {
      inXmlBlockComment = false;
    }
  }
}

bool _looksLikeCommentLine(String line, String path) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
    return true;
  }
  if (trimmed.startsWith('<!--')) {
    return true;
  }

  final extension = _extensionOf(path);
  if ((extension == '.yaml' || extension == '.yml') && trimmed.startsWith('#')) {
    return true;
  }

  return false;
}

bool _looksLikeStringLiteralLine(String line) {
  final hasQuote = line.contains("'") || line.contains('"') || line.contains("'''");
  return hasQuote;
}

String _toRelativePath(String absolutePath) {
  final root = Directory.current.path;
  if (absolutePath.startsWith(root)) {
    return absolutePath.substring(root.length + 1).replaceAll('\\', '/');
  }
  return absolutePath.replaceAll('\\', '/');
}

String _extensionOf(String path) {
  final index = path.lastIndexOf('.');
  if (index == -1) {
    return '';
  }
  return path.substring(index).toLowerCase();
}

bool _isExcludedPath(String relativePath) {
  final segments = relativePath.split('/');
  for (final segment in segments) {
    if (_excludedDirNames.contains(segment)) {
      return true;
    }
  }

  if (relativePath.startsWith('ios/Pods/')) {
    return true;
  }
  if (relativePath.startsWith('android/.gradle/')) {
    return true;
  }

  return false;
}

_Allowlist _loadAllowlist() {
  final file = File('tool/qa/korean_text_allowlist.json');
  if (!file.existsSync()) {
    return _Allowlist.empty();
  }

  final dynamic decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    return _Allowlist.empty();
  }

  List<RegExp> parseRegExpList(String key) {
    final dynamic value = decoded[key];
    if (value is! List) {
      return const [];
    }

    final regexes = <RegExp>[];
    for (final item in value) {
      if (item is String) {
        regexes.add(RegExp(item));
      }
    }
    return regexes;
  }

  return _Allowlist(
    pathRegexes: parseRegExpList('pathRegex'),
    literalRegexes: parseRegExpList('literalRegex'),
  );
}

class _Allowlist {
  final List<RegExp> pathRegexes;
  final List<RegExp> literalRegexes;

  const _Allowlist({required this.pathRegexes, required this.literalRegexes});

  factory _Allowlist.empty() {
    return const _Allowlist(pathRegexes: [], literalRegexes: []);
  }

  bool isAllowed(String path, String preview) {
    for (final regex in pathRegexes) {
      if (regex.hasMatch(path)) {
        return true;
      }
    }
    for (final regex in literalRegexes) {
      if (regex.hasMatch(preview)) {
        return true;
      }
    }
    return false;
  }
}

enum _ViolationCategory { comment, string }

class _Violation {
  final String path;
  final int line;
  final String preview;
  final _ViolationCategory category;

  const _Violation({
    required this.path,
    required this.line,
    required this.preview,
    required this.category,
  });
}
