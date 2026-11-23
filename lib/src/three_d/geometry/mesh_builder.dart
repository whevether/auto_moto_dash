import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import '../scene/scene_model.dart';

/// Procedural mesh builder shared by every backend.
///
/// Every face is oriented against an outward hint, so callers never have to
/// reason about winding: `cross(b - a, c - a)` of the output always points
/// away from the supplied interior point.
class MeshBuilder {
  final List<double> _p = [];
  final List<double> _n = [];
  final List<int> _i = [];
  final List<Matrix4> _stack = [];
  Matrix4 _m = Matrix4.identity();

  int get vertexCount => _p.length ~/ 3;

  /// Applies [transform] to everything added inside [body].
  void withTransform(Matrix4 transform, void Function() body) {
    _stack.add(_m);
    _m = _m * transform;
    body();
    _m = _stack.removeLast();
  }

  Vector3 _tp(Vector3 v) => _m.transformed3(v);
  Vector3 _tn(Vector3 v) {
    final r = _m.getRotation()
      ..invert()
      ..transpose();
    return (r * v)..normalize();
  }

  int _vertex(Vector3 p, Vector3 n) {
    final tp = _tp(p);
    final tn = _tn(n);
    _p.addAll([tp.x, tp.y, tp.z]);
    _n.addAll([tn.x, tn.y, tn.z]);
    return vertexCount - 1;
  }

  /// Flat triangle facing away from [inside].
  void tri(Vector3 a, Vector3 b, Vector3 c, Vector3 inside) {
    var n = (b - a).cross(c - a);
    if (n.length2 < 1e-14) return;
    final centroid = (a + b + c) / 3;
    if (n.dot(centroid - inside) < 0) {
      final t = b;
      b = c;
      c = t;
      n = -n;
    }
    n.normalize();
    final ia = _vertex(a, n), ib = _vertex(b, n), ic = _vertex(c, n);
    _i.addAll([ia, ib, ic]);
  }

  /// Flat quad (a, b, c, d around the perimeter) facing away from [inside].
  void quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector3 inside) {
    tri(a, b, c, inside);
    tri(a, c, d, inside);
  }

  /// Single-sided quad facing [normal] (for decals, screens, road paint).
  void facingQuad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector3 normal) {
    final centre = (a + b + c + d) / 4;
    quad(a, b, c, d, centre - normal);
  }

  /// Axis-aligned box centred at [c] with full [size].
  void box(Vector3 c, Vector3 size) {
    final h = size / 2;
    Vector3 v(double sx, double sy, double sz) =>
        Vector3(c.x + sx * h.x, c.y + sy * h.y, c.z + sz * h.z);
    final p = [
      v(-1, -1, -1),
      v(1, -1, -1),
      v(1, 1, -1),
      v(-1, 1, -1),
      v(-1, -1, 1),
      v(1, -1, 1),
      v(1, 1, 1),
      v(-1, 1, 1),
    ];
    quad(p[0], p[1], p[2], p[3], c); // back
    quad(p[4], p[5], p[6], p[7], c); // front
    quad(p[0], p[4], p[7], p[3], c); // left
    quad(p[1], p[5], p[6], p[2], c); // right
    quad(p[3], p[2], p[6], p[7], c); // top
    quad(p[0], p[1], p[5], p[4], c); // bottom
  }

  /// Cylinder along the local X axis (wheels), centred at [c].
  void cylinderX(
    Vector3 c,
    double radius,
    double width, {
    int segments = 18,
    bool caps = true,
    double innerRadius = 0,
  }) {
    final x0 = c.x - width / 2, x1 = c.x + width / 2;
    final ring = <Vector2>[
      for (var s = 0; s < segments; s++)
        Vector2(
          math.cos(2 * math.pi * s / segments),
          math.sin(2 * math.pi * s / segments),
        ),
    ];
    final start = vertexCount;
    // Smooth tread.
    for (var s = 0; s < segments; s++) {
      final r = ring[s];
      final n = Vector3(0, r.y, r.x);
      _vertex(Vector3(x0, c.y + r.y * radius, c.z + r.x * radius), n);
      _vertex(Vector3(x1, c.y + r.y * radius, c.z + r.x * radius), n);
    }
    for (var s = 0; s < segments; s++) {
      final a = start + s * 2, b = start + ((s + 1) % segments) * 2;
      _smoothQuad(a, a + 1, b + 1, b, c);
    }
    if (!caps) return;
    for (final x in [x0, x1]) {
      final inside = Vector3(x == x0 ? x1 : x0, c.y, c.z);
      for (var s = 0; s < segments; s++) {
        final r0 = ring[s], r1 = ring[(s + 1) % segments];
        final p0 = Vector3(x, c.y + r0.y * radius, c.z + r0.x * radius);
        final p1 = Vector3(x, c.y + r1.y * radius, c.z + r1.x * radius);
        if (innerRadius > 0) {
          final q0 = Vector3(
            x,
            c.y + r0.y * innerRadius,
            c.z + r0.x * innerRadius,
          );
          final q1 = Vector3(
            x,
            c.y + r1.y * innerRadius,
            c.z + r1.x * innerRadius,
          );
          quad(p0, p1, q1, q0, inside);
        } else {
          tri(Vector3(x, c.y, c.z), p0, p1, inside);
        }
      }
    }
  }

  /// Vertical cylinder / cone (poles, trunks) with base centre [base].
  void cylinderY(
    Vector3 base,
    double bottomRadius,
    double topRadius,
    double height, {
    int segments = 10,
  }) {
    final start = vertexCount;
    final slope = (bottomRadius - topRadius) / height;
    for (var s = 0; s < segments; s++) {
      final a = 2 * math.pi * s / segments;
      final dx = math.cos(a), dz = math.sin(a);
      final n = Vector3(dx, slope, dz)..normalize();
      _vertex(
        Vector3(base.x + dx * bottomRadius, base.y, base.z + dz * bottomRadius),
        n,
      );
      _vertex(
        Vector3(
          base.x + dx * topRadius,
          base.y + height,
          base.z + dz * topRadius,
        ),
        n,
      );
    }
    final centre = base + Vector3(0, height / 2, 0);
    for (var s = 0; s < segments; s++) {
      final a = start + s * 2, b = start + ((s + 1) % segments) * 2;
      _smoothQuad(a, b, b + 1, a + 1, centre);
    }
    if (topRadius > 0) {
      final top = base + Vector3(0, height, 0);
      for (var s = 0; s < segments; s++) {
        final a0 = 2 * math.pi * s / segments,
            a1 = 2 * math.pi * (s + 1) / segments;
        tri(
          top,
          top + Vector3(math.cos(a0) * topRadius, 0, math.sin(a0) * topRadius),
          top + Vector3(math.cos(a1) * topRadius, 0, math.sin(a1) * topRadius),
          centre,
        );
      }
    }
  }

  /// Low-poly blob (tree canopy, helmet): a squashed UV sphere.
  void ellipsoid(Vector3 c, Vector3 radii, {int segments = 10, int rings = 7}) {
    final start = vertexCount;
    for (var r = 0; r <= rings; r++) {
      final phi = math.pi * r / rings;
      for (var s = 0; s <= segments; s++) {
        final theta = 2 * math.pi * s / segments;
        final n = Vector3(
          math.sin(phi) * math.cos(theta),
          math.cos(phi),
          math.sin(phi) * math.sin(theta),
        );
        _vertex(
          Vector3(
            c.x + n.x * radii.x,
            c.y + n.y * radii.y,
            c.z + n.z * radii.z,
          ),
          Vector3(n.x / radii.x, n.y / radii.y, n.z / radii.z)..normalize(),
        );
      }
    }
    final cols = segments + 1;
    for (var r = 0; r < rings; r++) {
      for (var s = 0; s < segments; s++) {
        final a = start + r * cols + s;
        _smoothQuad(a, a + 1, a + cols + 1, a + cols, c);
      }
    }
  }

  /// Lofts closed cross-sections along their own positions with smooth
  /// normals; [caps] closes the first and last section. Sections must have
  /// the same point count.
  void loft(List<List<Vector3>> sections, {bool caps = true}) {
    if (sections.length < 2) return;
    final count = sections.first.length;
    final start = vertexCount;
    // Accumulated smooth normals.
    final normals = List.generate(
      sections.length * count,
      (_) => Vector3.zero(),
    );
    final centres = [
      for (final s in sections)
        s.fold(Vector3.zero(), (a, b) => a + b) / s.length.toDouble(),
    ];
    Vector3 at(int si, int pi) => sections[si][pi % count];
    for (var si = 0; si < sections.length - 1; si++) {
      for (var pi = 0; pi < count; pi++) {
        final a = at(si, pi), b = at(si, pi + 1);
        final c = at(si + 1, pi + 1), d = at(si + 1, pi);
        var n = (b - a).cross(c - a) + (c - a).cross(d - a);
        final mid = (centres[si] + centres[si + 1]) / 2;
        if (n.dot((a + b + c + d) / 4 - mid) < 0) n = -n;
        for (final idx in [
          si * count + pi,
          si * count + (pi + 1) % count,
          (si + 1) * count + (pi + 1) % count,
          (si + 1) * count + pi,
        ]) {
          normals[idx] += n;
        }
      }
    }
    for (var si = 0; si < sections.length; si++) {
      for (var pi = 0; pi < count; pi++) {
        final n = normals[si * count + pi];
        if (n.length2 < 1e-12) n.setValues(0, 1, 0);
        _vertex(sections[si][pi], n.normalized());
      }
    }
    for (var si = 0; si < sections.length - 1; si++) {
      final mid = (centres[si] + centres[si + 1]) / 2;
      for (var pi = 0; pi < count; pi++) {
        final a = start + si * count + pi;
        final b = start + si * count + (pi + 1) % count;
        final c = start + (si + 1) * count + (pi + 1) % count;
        final d = start + (si + 1) * count + pi;
        _smoothQuad(a, b, c, d, mid, transformed: true);
      }
    }
    if (!caps) return;
    for (final si in [0, sections.length - 1]) {
      final s = sections[si];
      final inside = centres[si == 0 ? 1 : sections.length - 2];
      for (var pi = 0; pi < count; pi++) {
        tri(centres[si], s[pi], s[(pi + 1) % count], inside);
      }
    }
  }

  /// Indexed quad over existing vertices, oriented away from [inside]
  /// (given in builder space before or after transform, see [transformed]).
  void _smoothQuad(
    int a,
    int b,
    int c,
    int d,
    Vector3 inside, {
    bool transformed = false,
  }) {
    final ins = _tp(inside);
    Vector3 v(int i) => Vector3(_p[i * 3], _p[i * 3 + 1], _p[i * 3 + 2]);
    final pa = v(a), pb = v(b), pc = v(c), pd = v(d);
    var n = (pb - pa).cross(pc - pa) + (pc - pa).cross(pd - pa);
    if (n.length2 < 1e-16) return;
    final centroid = (pa + pb + pc + pd) / 4;
    if (n.dot(centroid - ins) < 0) {
      _i.addAll([a, c, b, a, d, c]);
    } else {
      _i.addAll([a, b, c, a, c, d]);
    }
  }

  /// Rounded rectangle cross-section at depth [z] (points CCW in XY).
  static List<Vector3> roundedSection({
    required double z,
    required double width,
    required double bottom,
    required double top,
    double radius = 0.12,
    double topWidth = -1,
    int cornerSteps = 3,
  }) {
    final tw = topWidth < 0 ? width : topWidth;
    final h = top - bottom;
    final r = math.min(radius, math.min(h / 2, math.min(width, tw) / 2) * 0.98);
    final pts = <Vector3>[];
    void corner(double cx, double cy, double a0) {
      for (var k = 0; k <= cornerSteps; k++) {
        final a = a0 + (math.pi / 2) * k / cornerSteps;
        pts.add(Vector3(cx + math.cos(a) * r, cy + math.sin(a) * r, z));
      }
    }

    corner(width / 2 - r, bottom + r, -math.pi / 2); // bottom right
    corner(tw / 2 - r, top - r, 0); // top right
    corner(-tw / 2 + r, top - r, math.pi / 2); // top left
    corner(-width / 2 + r, bottom + r, math.pi); // bottom left
    return pts;
  }

  /// Ring in the local XY plane (steering wheel rim), facing ±z.
  void torus(
    Vector3 c,
    double radius,
    double tube, {
    int segments = 32,
    int sides = 8,
    double startRad = 0,
    double sweepRad = 2 * math.pi,
  }) {
    final start = vertexCount;
    final closed = sweepRad >= 2 * math.pi - 1e-6;
    final segs = closed ? segments : segments + 1;
    for (var s = 0; s < segs; s++) {
      final a = startRad + sweepRad * s / segments;
      final dir = Vector3(math.cos(a), math.sin(a), 0);
      for (var k = 0; k < sides; k++) {
        final b = 2 * math.pi * k / sides;
        final n = dir * math.cos(b) + Vector3(0, 0, math.sin(b));
        _vertex(c + dir * radius + n * tube, n);
      }
    }
    for (var s = 0; s < segments; s++) {
      final s1 = closed ? (s + 1) % segments : s + 1;
      final a =
          c +
          Vector3(
                math.cos(startRad + sweepRad * (s + 0.5) / segments),
                math.sin(startRad + sweepRad * (s + 0.5) / segments),
                0,
              ) *
              radius;
      for (var k = 0; k < sides; k++) {
        final k1 = (k + 1) % sides;
        _smoothQuad(
          start + s * sides + k,
          start + s1 * sides + k,
          start + s1 * sides + k1,
          start + s * sides + k1,
          a,
        );
      }
    }
  }

  /// Flat rectangle with uvs (u right, v down), centred at [c] in a plane
  /// spanned by [right] and [up] (unit vectors), facing `right × up` or
  /// [facing] when given.
  static MeshData3D texturedQuad(
    Vector3 c,
    Vector3 right,
    Vector3 up,
    double width,
    double height, {
    Vector3? facing,
  }) {
    final r = right * (width / 2), u = up * (height / 2);
    var n = right.cross(up)..normalize();
    final flip = facing != null && n.dot(facing) < 0;
    if (flip) n = -n;
    final p = [c - r + u, c + r + u, c + r - u, c - r - u];
    return MeshData3D(
      positions: Float32List.fromList([
        for (final v in p) ...[v.x, v.y, v.z],
      ]),
      normals: Float32List.fromList([
        for (var i = 0; i < 4; i++) ...[n.x, n.y, n.z],
      ]),
      // cross(p3 - p0, p1 - p0) = right × up.
      indices: Uint32List.fromList(
        flip ? [0, 1, 3, 1, 2, 3] : [0, 3, 1, 1, 3, 2],
      ),
      uvs: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
    );
  }

  MeshData3D build({bool dynamic = false}) => MeshData3D(
    positions: Float32List.fromList(_p),
    normals: Float32List.fromList(_n),
    indices: Uint32List.fromList(_i),
    dynamic: dynamic,
  );

  bool get isEmpty => _i.isEmpty;
}

/// Fixed-topology triangle strip whose positions are rewritten every frame
/// (road surface, lane paint). Two rows of [stations] vertices.
class StripMesh {
  StripMesh(this.stations)
    : positions = Float32List(stations * 2 * 3),
      normals = Float32List(stations * 2 * 3) {
    final idx = <int>[];
    for (var s = 0; s < stations - 1; s++) {
      final a = s * 2, b = s * 2 + 1, c = s * 2 + 3, d = s * 2 + 2;
      // Left row (a, d) and right row (b, c); upward-facing quad.
      // cross(d - a, b - a) is +y for x right / z forward.
      idx.addAll([a, d, b, b, d, c]);
    }
    indices = Uint32List.fromList(idx);
    for (var i = 0; i < normals.length; i += 3) {
      normals[i + 1] = 1;
    }
  }

  final int stations;
  final Float32List positions;
  final Float32List normals;
  late final Uint32List indices;

  /// Overrides both normals of a station (vertical ribbons).
  void setNormal(int station, Vector3 n) {
    final o = station * 6;
    normals[o] = normals[o + 3] = n.x;
    normals[o + 1] = normals[o + 4] = n.y;
    normals[o + 2] = normals[o + 5] = n.z;
  }

  void set(int station, Vector3 left, Vector3 right) {
    final o = station * 6;
    positions[o] = left.x;
    positions[o + 1] = left.y;
    positions[o + 2] = left.z;
    positions[o + 3] = right.x;
    positions[o + 4] = right.y;
    positions[o + 5] = right.z;
  }

  MeshData3D toMesh() => MeshData3D(
    positions: positions,
    normals: normals,
    indices: indices,
    dynamic: true,
  );
}

/// Many independent quads with fixed count whose corners move every frame
/// (dashed lane markings, kerb stripes).
class QuadBatchMesh {
  QuadBatchMesh(this.count)
    : positions = Float32List(count * 4 * 3),
      normals = Float32List(count * 4 * 3) {
    final idx = <int>[];
    for (var q = 0; q < count; q++) {
      final a = q * 4;
      // Corners: 0 back-left, 1 back-right, 2 front-right, 3 front-left.
      // cross(p3 - p0, p1 - p0) = +y.
      idx.addAll([a, a + 3, a + 1, a + 1, a + 3, a + 2]);
    }
    indices = Uint32List.fromList(idx);
    for (var i = 0; i < normals.length; i += 3) {
      normals[i + 1] = 1;
    }
  }

  final int count;
  final Float32List positions;
  final Float32List normals;
  late final Uint32List indices;

  void setQuad(int q, Vector3 bl, Vector3 br, Vector3 fr, Vector3 fl) {
    final o = q * 12;
    for (final (k, v) in [(0, bl), (1, br), (2, fr), (3, fl)]) {
      positions[o + k * 3] = v.x;
      positions[o + k * 3 + 1] = v.y;
      positions[o + k * 3 + 2] = v.z;
    }
  }

  /// Collapses a quad so it draws nothing.
  void hide(int q) {
    final o = q * 12;
    for (var k = 0; k < 12; k++) {
      positions[o + k] = 0;
    }
    positions[o + 1] = positions[o + 4] = positions[o + 7] = positions[o + 10] =
        -50;
  }

  MeshData3D toMesh() => MeshData3D(
    positions: positions,
    normals: normals,
    indices: indices,
    dynamic: true,
  );
}
