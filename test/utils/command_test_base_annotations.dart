import 'dart:io';
import 'package:mockito/annotations.dart';
import 'package:path/path.dart' as p;

@GenerateMocks([File, Directory, Process])
class Annotations {}

extension DirectoryExtension on Directory {
  Directory directory(String path) {
    return Directory(p.join(this.path, path));
  }
}
