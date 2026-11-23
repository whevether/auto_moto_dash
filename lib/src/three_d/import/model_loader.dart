import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'gltf_importer.dart';
import 'imported_model.dart';
import 'obj_stl_importer.dart';

/// Model file formats understood by [ModelLoader].
enum ModelFormat {
  glb,
  gltf,
  obj,
  stl;

  static ModelFormat? of(String path) {
    final p = path.toLowerCase().split('?').first;
    for (final f in values) {
      if (p.endsWith('.${f.name}')) return f;
    }
    return null;
  }
}

/// Loads models from the asset bundle or any byte source.
///
/// Supported: glTF 2.0 (`.glb`, `.gltf` with embedded / external buffers
/// and textures), Wavefront `.obj` + `.mtl`, and `.stl` (binary / ASCII).
/// Other formats (FBX, DAE, 3DS, USDZ, BLEND) should be converted to glb,
/// e.g. with Blender's glTF exporter.
abstract final class ModelLoader {
  static final Map<String, Future<ImportedModel>> _cache = {};

  /// Loads [path] from [bundle] (default [rootBundle]); files the model
  /// references are resolved relative to it. Results are cached by path.
  static Future<ImportedModel> asset(
    String path, {
    AssetBundle? bundle,
    bool? zUp,
  }) => _cache.putIfAbsent('$path|$zUp', () async {
    final b = bundle ?? rootBundle;
    Future<Uint8List> read(String p) async {
      final data = await b.load(p);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    return parse(
      await read(path),
      ModelFormat.of(path) ??
          (throw FormatException('Unknown model format: $path')),
      name: path,
      resolve: (uri) => read(resolveRelative(path, uri)),
      zUp: zUp,
    );
  });

  /// Parses model [bytes]; [resolve] loads files the model references
  /// (relative uris as written in the file).
  static Future<ImportedModel> parse(
    Uint8List bytes,
    ModelFormat format, {
    String name = 'model',
    ModelResolver? resolve,
    bool? zUp,
  }) => switch (format) {
    ModelFormat.glb || ModelFormat.gltf => GltfImporter.parse(
      bytes,
      name: name,
      resolve: resolve,
      zUp: zUp ?? false,
    ),
    ModelFormat.obj => ObjImporter.parse(
      bytes,
      name: name,
      resolve: resolve,
      zUp: zUp ?? false,
    ),
    ModelFormat.stl => Future.value(
      StlImporter.parse(bytes, name: name, zUp: zUp ?? true),
    ),
  };

  /// [uri] relative to the directory of [base] (`a/b/car.gltf` +
  /// `tex/c.png` → `a/b/tex/c.png`).
  static String resolveRelative(String base, String uri) {
    if (uri.contains('://') || uri.startsWith('/')) return uri;
    final parts = base.split('/')..removeLast();
    for (final s in uri.split('/')) {
      if (s == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (s != '.' && s.isNotEmpty) {
        parts.add(s);
      }
    }
    return parts.join('/');
  }

  static final Map<String, Future<ui.Image>> _images = {};

  /// Decodes an imported texture once per key.
  static Future<ui.Image> decodeImage(ImportedImage image) =>
      _images.putIfAbsent(image.key, () async {
        final codec = await ui.instantiateImageCodec(image.bytes);
        return (await codec.getNextFrame()).image;
      });
}
