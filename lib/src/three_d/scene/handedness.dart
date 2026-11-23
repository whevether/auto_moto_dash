import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// The scene layer uses x right, y up, z forward (left-handed). three.js is
/// right-handed, so its backend mirrors x on upload (flutter_scene 0.24+
/// already matches the scene and must not be mirrored):
/// positions / normals / directions negate x, triangle winding flips and
/// matrices are conjugated by diag(-1, 1, 1). The rendered image is then
/// exactly what the left-handed scene describes.
abstract final class Handedness {
  static Float32List vec3Array(Float32List src) {
    final out = Float32List.fromList(src);
    for (var i = 0; i < out.length; i += 3) {
      out[i] = -out[i];
    }
    return out;
  }

  static Uint32List indices(Uint32List src) {
    final out = Uint32List.fromList(src);
    for (var i = 0; i + 2 < out.length; i += 3) {
      final t = out[i + 1];
      out[i + 1] = out[i + 2];
      out[i + 2] = t;
    }
    return out;
  }

  static Matrix4 matrix(Matrix4 m) {
    final r = m.clone();
    final s = r.storage;
    for (final i in const [1, 2, 3, 4, 8, 12]) {
      s[i] = -s[i];
    }
    return r;
  }

  static Float32List matrixStorage(Matrix4 m) => matrix(m).storage;

  static Vector3 vec(Vector3 v) => Vector3(-v.x, v.y, v.z);
}
