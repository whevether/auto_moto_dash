import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

import 'gltf_importer.dart' show ModelResolver;
import 'imported_model.dart';

/// Wavefront OBJ importer with MTL materials (`Kd`, `Ke`, `d` / `Tr`,
/// `Ns`, `Pr` / `Pm`, `map_Kd`), `o` / `g` parts, polygons (fan
/// triangulated), negative indices and the common `v x y z r g b` vertex
/// colour extension.
abstract final class ObjImporter {
  static Future<ImportedModel> parse(
    Uint8List bytes, {
    String name = 'model',
    ModelResolver? resolve,
    bool zUp = false,
  }) async {
    final lines = const LineSplitter().convert(
      utf8.decode(bytes, allowMalformed: true),
    );
    final v = <double>[], vc = <double>[], vt = <double>[], vn = <double>[];
    var anyColor = false;
    final mtl = <String, ImportedMaterial>{};
    final parts = <(String, String), MeshAccumulator>{};
    final keys = <(String, String), Map<String, int>>{};
    var part = 'mesh', material = '';

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final t = line.split(RegExp(r'\s+'));
      switch (t[0]) {
        case 'v':
          v.addAll([_d(t, 1), _d(t, 2), _d(t, 3)]);
          if (t.length >= 7) {
            anyColor = true;
            vc.addAll([_d(t, 4), _d(t, 5), _d(t, 6)]);
          } else {
            vc.addAll(const [1, 1, 1]);
          }
        case 'vt':
          vt.addAll([_d(t, 1), t.length > 2 ? _d(t, 2) : 0]);
        case 'vn':
          vn.addAll([_d(t, 1), _d(t, 2), _d(t, 3)]);
        case 'o' || 'g':
          part = t.length > 1 ? t.sublist(1).join(' ') : 'mesh';
        case 'usemtl':
          material = t.length > 1 ? t.sublist(1).join(' ') : '';
        case 'mtllib':
          if (resolve != null && t.length > 1) {
            try {
              final lib = line.substring(line.indexOf(t[1]));
              mtl.addAll(await _mtl(await resolve(lib), name, resolve));
            } on Object {
              // Missing library: keep default materials.
            }
          }
        case 'f':
          final key = (part, material);
          final acc = parts.putIfAbsent(key, () {
            final a = MeshAccumulator()..hasColors = anyColor;
            return a;
          });
          final seen = keys.putIfAbsent(key, () => {});
          final corners = <int>[];
          final noNormal = <int>[];
          for (var i = 1; i < t.length; i++) {
            final s = t[i].split('/');
            int ix(String x, int count) {
              final k = int.parse(x);
              return k < 0 ? count + k : k - 1;
            }

            final pi = ix(s[0], v.length ~/ 3);
            final ti = s.length > 1 && s[1].isNotEmpty
                ? ix(s[1], vt.length ~/ 2)
                : -1;
            final ni = s.length > 2 && s[2].isNotEmpty
                ? ix(s[2], vn.length ~/ 3)
                : -1;
            if (ni < 0) {
              // Flat shading: own vertex per face corner.
              noNormal.add(corners.length);
              corners.add(_push(acc, v, vc, vt, vn, pi, ti, -1));
              continue;
            }
            final k = '$pi/$ti/$ni';
            corners.add(seen[k] ??= _push(acc, v, vc, vt, vn, pi, ti, ni));
          }
          if (noNormal.isNotEmpty && corners.length >= 3) {
            final p = [
              for (final c in corners.take(3))
                Vector3(
                  acc.positions[c * 3],
                  acc.positions[c * 3 + 1],
                  acc.positions[c * 3 + 2],
                ),
            ];
            final f = (p[1] - p[0]).cross(p[2] - p[0])..normalize();
            for (final i in noNormal) {
              final c = corners[i];
              acc.normals
                ..[c * 3] = f.x
                ..[c * 3 + 1] = f.y
                ..[c * 3 + 2] = f.z;
            }
          }
          for (var i = 1; i + 1 < corners.length; i++) {
            acc.indices.addAll([corners[0], corners[i], corners[i + 1]]);
          }
      }
    }
    return ImportedModel([
      for (final MapEntry(key: (p, m), value: acc) in parts.entries)
        if (acc.indices.isNotEmpty)
          ImportedPart(
            p,
            acc.build(zUp: zUp),
            mtl[m] ?? ImportedMaterial(name: m),
          ),
    ], source: name);
  }

  static int _push(
    MeshAccumulator acc,
    List<double> v,
    List<double> vc,
    List<double> vt,
    List<double> vn,
    int pi,
    int ti,
    int ni,
  ) {
    final i = acc.vertexCount;
    acc.positions.addAll([v[pi * 3], v[pi * 3 + 1], v[pi * 3 + 2]]);
    acc.normals.addAll(
      ni >= 0 ? [vn[ni * 3], vn[ni * 3 + 1], vn[ni * 3 + 2]] : const [0, 1, 0],
    );
    if (ti >= 0) {
      acc.hasUvs = true;
      // OBJ v = 0 is the bottom edge; the scene uses v = 0 at the top.
      acc.uvs.addAll([vt[ti * 2], 1 - vt[ti * 2 + 1]]);
    } else {
      acc.uvs.addAll(const [0, 0]);
    }
    // OBJ vertex colours are sRGB; meshes carry linear colour.
    acc.colors.addAll([
      _lin(vc[pi * 3]),
      _lin(vc[pi * 3 + 1]),
      _lin(vc[pi * 3 + 2]),
      1,
    ]);
    return i;
  }

  static double _lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static Future<Map<String, ImportedMaterial>> _mtl(
    Uint8List bytes,
    String name,
    ModelResolver resolve,
  ) async {
    final out = <String, ImportedMaterial>{};
    String? cur;
    var kd = [1.0, 1.0, 1.0], ke = [0.0, 0.0, 0.0];
    var d = 1.0, rough = 0.6, metal = 0.0;
    String? map;
    Future<void> flush() async {
      final n = cur;
      if (n == null) return;
      ImportedImage? img;
      if (map != null) {
        try {
          img = ImportedImage('$name|$map', await resolve(map));
        } on Object {
          img = null;
        }
      }
      final lit = ke.any((e) => e > 0);
      out[n] = ImportedMaterial(
        name: n,
        color: Color.from(alpha: 1, red: kd[0], green: kd[1], blue: kd[2]),
        emissive: lit
            ? Color.from(alpha: 1, red: ke[0], green: ke[1], blue: ke[2])
            : const Color(0xFF000000),
        emissiveStrength: lit ? 1 : 0,
        opacity: d < 1 ? d.clamp(0.05, 0.99) : 1,
        roughness: rough,
        metallic: metal,
        image: img,
      );
    }

    for (final raw in const LineSplitter().convert(
      utf8.decode(bytes, allowMalformed: true),
    )) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final t = line.split(RegExp(r'\s+'));
      switch (t[0]) {
        case 'newmtl':
          await flush();
          cur = t.length > 1 ? t.sublist(1).join(' ') : '';
          kd = [1, 1, 1];
          ke = [0, 0, 0];
          d = 1;
          rough = 0.6;
          metal = 0;
          map = null;
        case 'Kd':
          kd = [_d(t, 1), _d(t, 2), _d(t, 3)];
        case 'Ke':
          ke = [_d(t, 1), _d(t, 2), _d(t, 3)];
        case 'd':
          d = _d(t, 1);
        case 'Tr':
          d = 1 - _d(t, 1);
        case 'Ns':
          // Blinn-Phong exponent → roughness.
          rough = math.sqrt(2 / (_d(t, 1) + 2)).clamp(0.05, 1.0);
        case 'Pr':
          rough = _d(t, 1);
        case 'Pm':
          metal = _d(t, 1);
        case 'map_Kd':
          // Options (-s, -o ...) precede the file name.
          map = t.last;
      }
    }
    await flush();
    return out;
  }
}

double _d(List<String> t, int i) =>
    i < t.length ? (double.tryParse(t[i]) ?? 0) : 0;

/// STL importer (binary and ASCII). STL files carry no units or up axis;
/// CAD exports are usually z-up, so [zUp] defaults to true.
abstract final class StlImporter {
  static ImportedModel parse(
    Uint8List bytes, {
    String name = 'model',
    bool zUp = true,
  }) {
    final acc = MeshAccumulator();
    final d = ByteData.sublistView(bytes);
    final binary =
        bytes.length >= 84 &&
        84 + 50 * d.getUint32(80, Endian.little) == bytes.length;
    void tri(List<double> n, List<List<double>> p) {
      var nx = n[0], ny = n[1], nz = n[2];
      final a = Vector3.array(p[0]), b = Vector3.array(p[1]);
      final c = Vector3.array(p[2]);
      final f = (b - a).cross(c - a);
      if (f.length2 < 1e-24) return;
      f.normalize();
      // Normals in STL are often missing or wrong: trust the winding.
      if (nx * f.x + ny * f.y + nz * f.z <= 0.5) (nx, ny, nz) = (f.x, f.y, f.z);
      final base = acc.vertexCount;
      for (final q in p) {
        acc.positions.addAll(q);
        acc.normals.addAll([nx, ny, nz]);
      }
      acc.indices.addAll([base, base + 1, base + 2]);
    }

    if (binary) {
      final n = d.getUint32(80, Endian.little);
      for (var i = 0; i < n; i++) {
        final o = 84 + i * 50;
        double f(int k) => d.getFloat32(o + k * 4, Endian.little);
        tri(
          [f(0), f(1), f(2)],
          [
            [f(3), f(4), f(5)],
            [f(6), f(7), f(8)],
            [f(9), f(10), f(11)],
          ],
        );
      }
    } else {
      final text = utf8.decode(bytes, allowMalformed: true);
      var normal = [0.0, 0.0, 0.0];
      final verts = <List<double>>[];
      for (final raw in const LineSplitter().convert(text)) {
        final t = raw.trim().split(RegExp(r'\s+'));
        if (t.isEmpty) continue;
        if (t[0] == 'facet' && t.length >= 5) {
          normal = [_d(t, 2), _d(t, 3), _d(t, 4)];
          verts.clear();
        } else if (t[0] == 'vertex') {
          verts.add([_d(t, 1), _d(t, 2), _d(t, 3)]);
        } else if (t[0] == 'endfacet' && verts.length >= 3) {
          for (var i = 1; i + 1 < verts.length; i++) {
            tri(normal, [verts[0], verts[i], verts[i + 1]]);
          }
        }
      }
    }
    if (acc.indices.isEmpty) {
      throw const FormatException('STL contains no triangles');
    }
    return ImportedModel([
      ImportedPart('body', acc.build(zUp: zUp), const ImportedMaterial()),
    ], source: name);
  }
}
