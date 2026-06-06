import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  String content = file.readAsStringSync();
  content = content.replaceAll('.withValues(alpha: \\1)', '.withValues(alpha: 0.1)');
  file.writeAsStringSync(content);
  print('Replaced \\1 with 0.1');
}
