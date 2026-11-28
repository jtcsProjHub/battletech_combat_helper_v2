// File: lib/server/client_bundle.dart
// The built phone client: the output of `flutter build web` in client/.
// Finds it on disk and serves its files. Phones on the hotspot have no
// internet, so the build must not use the CanvasKit CDN (see
// scripts/build_client.sh).

import 'dart:io';

import 'package:path/path.dart' as p;

class ClientBundleException implements Exception {
  const ClientBundleException(this.message, [this.details]);

  final String message;
  final String? details;

  @override
  String toString() => details == null ? message : '$message\n$details';
}

class ClientBundle {
  ClientBundle(String root) : root = p.normalize(p.absolute(root));

  /// Folder holding index.html and the rest of the web build.
  final String root;

  File get indexFile => File(p.join(root, 'index.html'));

  /// The web build, from the first of these that has an index.html:
  /// 1. [configured], when given.
  /// 2. `data/client_web` next to the executable (for packaged builds).
  /// 3. `client/build/web` in the working directory or any folder above
  ///    the executable (for development, where the executable sits under
  ///    build/linux/...).
  /// Throws a [ClientBundleException] listing where it looked.
  static ClientBundle locate({String? configured}) {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = <String>[
      ?configured,
      p.join(exeDir, 'data', 'client_web'),
      p.join(Directory.current.path, 'client', 'build', 'web'),
      for (var dir = exeDir; p.dirname(dir) != dir; dir = p.dirname(dir))
        p.join(dir, 'client', 'build', 'web'),
    ];
    for (final c in candidates) {
      if (File(p.join(c, 'index.html')).existsSync()) return ClientBundle(c);
    }
    throw ClientBundleException(
      'The player web app is not built. Run scripts/build_client.sh, '
          'then retry.',
      'Looked in:\n${candidates.toSet().join('\n')}',
    );
  }

  /// The file for a request path, or null when there is none or the path
  /// leaves [root].
  File? fileFor(String urlPath) {
    final relative = p.url.normalize(urlPath).replaceFirst(RegExp('^/+'), '');
    if (relative.isEmpty || relative.startsWith('..')) return null;
    final path = p.normalize(p.join(root, p.joinAll(p.url.split(relative))));
    if (!p.isWithin(root, path)) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// Writes [file] to [response] with its content type. Files are not
  /// cached, so phones always load the build the laptop is serving.
  static Future<void> serve(File file, HttpResponse response) async {
    response.headers.contentType = _contentType(file.path);
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    await response.addStream(file.openRead());
    await response.close();
  }

  static ContentType _contentType(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.html' => ContentType.html,
        '.js' || '.mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
        '.json' => ContentType.json,
        '.wasm' => ContentType('application', 'wasm'),
        '.css' => ContentType('text', 'css', charset: 'utf-8'),
        '.png' => ContentType('image', 'png'),
        '.ico' => ContentType('image', 'x-icon'),
        '.svg' => ContentType('image', 'svg+xml'),
        '.ttf' => ContentType('font', 'ttf'),
        '.otf' => ContentType('font', 'otf'),
        '.woff2' => ContentType('font', 'woff2'),
        _ => ContentType.binary,
      };
}
