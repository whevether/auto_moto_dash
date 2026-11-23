import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

import '../scene/scene_model.dart';

/// Encoded image (PNG / JPEG / WebP) referenced by an imported material.
class ImportedImage {
  ImportedImage(this.key, this.bytes, {this.mimeType});

  /// Unique key, also used as the runtime texture slot.
  final String key;
  final Uint8List bytes;
  final String? mimeType;
}

/// Surface of an imported part. Colours are sRGB like [MaterialDesc].
class ImportedMaterial {
  const ImportedMaterial({
    this.name = '',
    this.color = const Color(0xFFFFFFFF),
    this.metallic = 0,
    this.roughness = 0.6,
    this.emissive = const Color(0xFF000000),
    this.emissiveStrength = 0,
    this.opacity = 1,
    this.doubleSided = false,
    this.image,
  });

  final String name;
  final Color color;
  final double metallic, roughness;
  final Color emissive;
  final double emissiveStrength;
  final double opacity;
  final bool doubleSided;

  /// Base colour texture (sampled with the mesh uvs, v = 0 at the top).
  final ImportedImage? image;
}

/// One named piece of an imported model (e.g. `body`, `wheel-front-left`)
/// in the scene frame: x right, y up, z forward, metres as authored.
class ImportedPart {
  ImportedPart(this.name, this.mesh, this.material);
  final String name;
  final MeshData3D mesh;
  final ImportedMaterial material;

  /// Rotating wheel part (tyre, rim, brake disc). Steering wheels and
  /// fixed brake callipers are not.
  bool get isWheel {
    final n = name.toLowerCase();
    if (n.contains('steering') ||
        n.contains('brakepad') ||
        n.contains('caliper') ||
        n.contains('calliper')) {
      return false;
    }
    return n.contains('wheel') || n.contains('tire') || n.contains('tyre');
  }

  /// Driver's steering wheel (rim, spokes, hub) — not the column.
  bool get isSteeringWheel {
    final n = name.toLowerCase().replaceAll(RegExp(r'[\s_\-.]'), '');
    if (n.contains('column') || n.contains('paddle')) return false;
    // Hub pieces turn with the rim (a fixed badge on a turning wheel looks
    // broken).
    if (n.contains('steering') &&
        RegExp(r'emblem|logo|badge|hub|airbag|horn|spoke|rim').hasMatch(n)) {
      return true;
    }
    return n.contains('steeringwheel') ||
        n.contains('steerwheel') ||
        n.contains('lenkrad') ||
        n.contains('volant') ||
        n.contains('方向盘');
  }

  /// Part of the cabin (seats, dashboard, console …), by part or material
  /// name.
  bool get isInterior {
    final n = '$name ${material.name}'.toLowerCase();
    return RegExp(
      r'interior|seat|dash|console|cockpit|cabin|headliner|carpet|floormat|'
      r'trim_in|innen|内饰|座椅|仪表',
    ).hasMatch(n);
  }

  /// Lamp role from the material name (`head`, `tail`, `indicator`), so
  /// detailed models keep their own lamp graphics.
  String? get lampRole {
    final n = material.name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    if (n.contains('headlight') || n.contains('headlamp')) return 'head';
    if (n.contains('brakelight') ||
        n.contains('taillight') ||
        n.contains('taillamp') ||
        n.contains('rearlight')) {
      return 'tail';
    }
    if (n.contains('signal') ||
        n.contains('indicator') ||
        n.contains('blinker')) {
      return 'indicator';
    }
    return null;
  }

  /// Main body paint (tinted with the vehicle colour at runtime).
  bool get isPaint => RegExp(
    r'^(car|body)?\s*paint\s*(1\b|$)|^paint\s*1|^(car|body)\s*paint',
    caseSensitive: false,
  ).hasMatch(material.name.trim());

  Aabb3 get bounds => boundsOf(mesh.positions);
}

/// Model produced by `GltfImporter`, `ObjImporter` or `StlImporter`.
class ImportedModel {
  ImportedModel(this.parts, {this.source = ''});
  final List<ImportedPart> parts;
  final String source;

  Aabb3 get bounds {
    final b = Aabb3.minMax(
      Vector3.all(double.infinity),
      Vector3.all(double.negativeInfinity),
    );
    for (final p in parts) {
      b.hull(p.bounds);
    }
    return b;
  }

  int get triangleCount => parts.fold(0, (n, p) => n + p.mesh.triangleCount);

  Iterable<ImportedImage> get images sync* {
    final seen = <String>{};
    for (final p in parts) {
      final i = p.material.image;
      if (i != null && seen.add(i.key)) yield i;
    }
  }
}

Aabb3 boundsOf(Float32List p) {
  final lo = Vector3.all(double.infinity);
  final hi = Vector3.all(double.negativeInfinity);
  for (var i = 0; i + 2 < p.length; i += 3) {
    lo.setValues(
      math.min(lo.x, p[i]),
      math.min(lo.y, p[i + 1]),
      math.min(lo.z, p[i + 2]),
    );
    hi.setValues(
      math.max(hi.x, p[i]),
      math.max(hi.y, p[i + 1]),
      math.max(hi.z, p[i + 2]),
    );
  }
  return Aabb3.minMax(lo, hi);
}

/// Linear → sRGB channel.
double linearToSrgb(double v) {
  v = v.clamp(0.0, 1.0);
  return v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
}

Color colorFromLinear(List<double> c, [double alpha = 1]) => Color.from(
  alpha: alpha.clamp(0.0, 1.0),
  red: linearToSrgb(c[0]),
  green: linearToSrgb(c[1]),
  blue: linearToSrgb(c[2]),
);

/// Accumulates triangles in a source frame (right-handed, y up, +z front,
/// the glTF / OBJ convention) and converts them to the scene frame.
class MeshAccumulator {
  final List<double> positions = [], normals = [], uvs = [], colors = [];
  final List<int> indices = [];
  bool hasNormals = true, hasUvs = false, hasColors = false;

  int get vertexCount => positions.length ~/ 3;

  /// Converts to the scene frame. [zUp] sources (CAD / STL) are rotated so
  /// +z becomes up; x is mirrored (scene is left-handed) and winding flips.
  MeshData3D build({bool zUp = false}) {
    final n = vertexCount;
    final pos = Float32List(n * 3), nor = Float32List(n * 3);
    for (var i = 0; i < n; i++) {
      var x = positions[i * 3], y = positions[i * 3 + 1];
      var z = positions[i * 3 + 2];
      if (zUp) (y, z) = (z, -y);
      pos[i * 3] = -x;
      pos[i * 3 + 1] = y;
      pos[i * 3 + 2] = z;
      if (hasNormals) {
        x = normals[i * 3];
        y = normals[i * 3 + 1];
        z = normals[i * 3 + 2];
        if (zUp) (y, z) = (z, -y);
        nor[i * 3] = -x;
        nor[i * 3 + 1] = y;
        nor[i * 3 + 2] = z;
      }
    }
    final idx = Uint32List(indices.length);
    for (var t = 0; t + 2 < indices.length; t += 3) {
      idx[t] = indices[t];
      idx[t + 1] = indices[t + 2];
      idx[t + 2] = indices[t + 1];
    }
    if (!hasNormals) _smoothNormals(pos, idx, nor);
    return MeshData3D(
      positions: pos,
      normals: nor,
      indices: idx,
      uvs: hasUvs && uvs.length == n * 2 ? Float32List.fromList(uvs) : null,
      colors: hasColors && colors.length == n * 4
          ? Float32List.fromList(colors)
          : null,
    );
  }
}

/// Area-weighted vertex normals for the scene winding
/// (`cross(b - a, c - a)` points outward).
void _smoothNormals(Float32List p, Uint32List idx, Float32List out) {
  out.fillRange(0, out.length, 0);
  Vector3 v(int i) => Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
  for (var t = 0; t + 2 < idx.length; t += 3) {
    final a = idx[t], b = idx[t + 1], c = idx[t + 2];
    final va = v(a);
    final f = (v(b) - va).cross(v(c) - va);
    for (final i in [a, b, c]) {
      out[i * 3] += f.x;
      out[i * 3 + 1] += f.y;
      out[i * 3 + 2] += f.z;
    }
  }
  for (var i = 0; i + 2 < out.length; i += 3) {
    final l = math.sqrt(
      out[i] * out[i] + out[i + 1] * out[i + 1] + out[i + 2] * out[i + 2],
    );
    if (l > 1e-12) {
      out[i] /= l;
      out[i + 1] /= l;
      out[i + 2] /= l;
    } else {
      out[i + 1] = 1;
    }
  }
}
