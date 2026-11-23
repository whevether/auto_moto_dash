import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const _kit = 'assets/models/kenney_car_kit';

Uint8List _read(String p) => File(p).readAsBytesSync();

Future<Uint8List> Function(String) _dirResolver(String dir) =>
    (uri) async => _read('$dir/$uri');

/// Share of triangles whose winding agrees with the vertex normals
/// (`cross(b - a, c - a)` outward in the scene frame).
double _windingAgreement(MeshData3D m) {
  var ok = 0, n = 0;
  final p = m.positions, nor = m.normals, idx = m.indices;
  Vector3 v(Float32List l, int i) =>
      Vector3(l[i * 3], l[i * 3 + 1], l[i * 3 + 2]);
  for (var t = 0; t + 2 < idx.length; t += 3) {
    final a = v(p, idx[t]);
    final f = (v(p, idx[t + 1]) - a).cross(v(p, idx[t + 2]) - a);
    if (f.length2 < 1e-14) continue;
    n++;
    if (f.dot(v(nor, idx[t]) + v(nor, idx[t + 1]) + v(nor, idx[t + 2])) > 0) {
      ok++;
    }
  }
  return n == 0 ? 1 : ok / n;
}

Vector3 _centre(ImportedPart p) {
  final b = p.bounds;
  return (b.min + b.max) / 2;
}

void main() {
  group('importers', () {
    test('glb: Kenney sedan parts, texture, frame and winding', () async {
      final m = await ModelLoader.parse(
        _read('$_kit/sedan.glb'),
        ModelFormat.glb,
        name: 'sedan',
        resolve: _dirResolver(_kit),
      );
      expect(m.parts.length, 5);
      expect(m.parts.where((p) => p.isWheel).length, 4);
      final size = m.bounds.max - m.bounds.min;
      expect(size.x, closeTo(1.5, 0.02));
      expect(size.z, closeTo(2.55, 0.02));
      expect(m.images.length, 1);
      expect(m.parts.first.mesh.uvs, isNotNull);
      // Scene frame: front +z, left -x.
      final fl = m.parts.firstWhere((p) => p.name == 'wheel-front-left');
      expect(_centre(fl).z, greaterThan(0.3));
      expect(_centre(fl).x, lessThan(-0.2));
      for (final p in m.parts) {
        expect(_windingAgreement(p.mesh), greaterThan(0.95), reason: p.name);
      }
    });

    test('obj + mtl matches the glb', () async {
      final m = await ModelLoader.parse(
        _read('test/fixtures/sedan.obj'),
        ModelFormat.obj,
        name: 'sedan.obj',
        resolve: _dirResolver('test/fixtures'),
      );
      expect(m.parts.where((p) => p.isWheel).length, 4);
      expect(m.images.single.bytes.length, greaterThan(1000));
      final fr = m.parts.firstWhere((p) => p.name == 'wheel-front-right');
      expect(_centre(fr).x, greaterThan(0.2));
      expect(_centre(fr).z, greaterThan(0.3));
      final size = m.bounds.max - m.bounds.min;
      expect(size.z, closeTo(2.55, 0.05));
      for (final p in m.parts) {
        expect(_windingAgreement(p.mesh), greaterThan(0.95), reason: p.name);
      }
    });

    test('gltf with a data-uri buffer, colours and a node transform', () async {
      final pos = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
      final col = Float32List.fromList([1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1]);
      final bytes = Uint8List.fromList([
        ...pos.buffer.asUint8List(),
        ...col.buffer.asUint8List(),
      ]);
      final gltf = {
        'asset': {'version': '2.0'},
        'buffers': [
          {
            'byteLength': bytes.length,
            'uri':
                'data:application/octet-stream;base64,${base64Encode(bytes)}',
          },
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
          {'buffer': 0, 'byteOffset': 36, 'byteLength': 48},
        ],
        'accessors': [
          {'bufferView': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
          {'bufferView': 1, 'componentType': 5126, 'count': 3, 'type': 'VEC4'},
        ],
        'materials': [
          {
            'pbrMetallicRoughness': {
              'baseColorFactor': [0.5, 0.5, 0.5, 1],
              'metallicFactor': 0,
            },
          },
        ],
        'meshes': [
          {
            'primitives': [
              {
                'attributes': {'POSITION': 0, 'COLOR_0': 1},
                'material': 0,
              },
            ],
          },
        ],
        'nodes': [
          {
            'name': 'body',
            'mesh': 0,
            'translation': [0, 2, 0],
          },
        ],
        'scenes': [
          {
            'nodes': [0],
          },
        ],
      };
      final m = await ModelLoader.parse(
        Uint8List.fromList(utf8.encode(jsonEncode(gltf))),
        ModelFormat.gltf,
      );
      final part = m.parts.single;
      expect(part.name, 'body');
      expect(part.mesh.colors, isNotNull);
      expect(part.material.metallic, 0);
      expect(m.bounds.min.y, closeTo(2, 1e-6));
      expect(m.bounds.min.x, closeTo(-1, 1e-6)); // x mirrored
      expect(_windingAgreement(part.mesh), 1);
    });

    test('stl binary and ascii (z-up)', () async {
      final b = ByteData(84 + 50);
      b.setUint32(80, 1, Endian.little);
      final v = <double>[0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0];
      for (var i = 0; i < 12; i++) {
        b.setFloat32(84 + i * 4, v[i], Endian.little);
      }
      final bin = await ModelLoader.parse(
        b.buffer.asUint8List(),
        ModelFormat.stl,
      );
      expect(bin.triangleCount, 1);
      // z-up triangle at z = 0 lies flat: height 0, up normal.
      expect(bin.bounds.max.y - bin.bounds.min.y, closeTo(0, 1e-6));
      expect(bin.parts.single.mesh.normals[1], closeTo(1, 1e-6));
      const ascii = '''solid t
facet normal 0 0 1
 outer loop
  vertex 0 0 0
  vertex 1 0 0
  vertex 0 1 0
 endloop
endfacet
endsolid t''';
      final a = await ModelLoader.parse(
        Uint8List.fromList(utf8.encode(ascii)),
        ModelFormat.stl,
      );
      expect(a.triangleCount, 1);
      expect(_windingAgreement(a.parts.single.mesh), 1);
    });

    test('format detection and relative paths', () {
      expect(ModelFormat.of('a/b/Car.GLB'), ModelFormat.glb);
      expect(ModelFormat.of('car.obj?v=2'), ModelFormat.obj);
      expect(ModelFormat.of('car.fbx'), isNull);
      expect(
        ModelLoader.resolveRelative('a/b/car.gltf', '../tex/c.png'),
        'a/tex/c.png',
      );
    });
  });

  group('imported vehicles in the scene', () {
    late VehicleModelSet set;
    setUpAll(() async {
      set = VehicleModelSet('test', const {});
      for (final (kind, file) in [
        (TrafficVehicleKind.sedan, 'sedan'),
        (TrafficVehicleKind.suv, 'suv'),
        (EgoVehicleModel.sedan, 'sedan'),
      ]) {
        set.add(
          kind,
          await ModelLoader.parse(
            _read('$_kit/$file.glb'),
            ModelFormat.glb,
            name: file,
            resolve: _dirResolver(_kit),
          ),
        );
      }
    });

    test('fitted to the footprint with round wheels and lamps', () {
      final p = proportionsForTraffic(TrafficVehicleKind.sedan);
      final f = set.modelsFor(TrafficVehicleKind.sedan).first.fit(p);
      final b = Aabb3.minMax(
        Vector3.all(double.infinity),
        Vector3.all(double.negativeInfinity),
      );
      for (final part in f.body) {
        b.hull(boundsOf(part.mesh.positions));
      }
      expect(b.max.z - b.min.z, closeTo(p.length, 0.15));
      expect(b.max.x - b.min.x, lessThanOrEqualTo(p.width + 0.01));
      expect(f.wheels.length, 4);
      for (final w in f.wheels) {
        final wb = boundsOf(w.mesh.positions);
        // Round: equal height and length.
        expect(wb.max.y - wb.min.y, closeTo(wb.max.z - wb.min.z, 0.02));
        // Touches the ground.
        expect(w.pivot!.y - f.wheelRadius, closeTo(0, 0.03));
      }
      expect(f.headLamps.triangleCount, greaterThan(0));
      expect(f.tailLamps.triangleCount, greaterThan(0));
      final head = boundsOf(f.headLamps.positions);
      expect(head.max.z, greaterThan(p.length / 2 - 0.6));
      final tail = boundsOf(f.tailLamps.positions);
      expect(tail.min.z, lessThan(-p.length / 2 + 0.6));
    });

    DriveScene scene(CameraMode mode, TimeOfDay3D time) => DriveScene(
      style: DashStyle.classic,
      road: RoadProfile(),
      mode: mode,
      timeOfDay: time,
      egoModel: EgoVehicleModel.sedan,
      models: set,
    );

    test('ego and traffic use the imported model with its texture', () {
      final s = scene(CameraMode.exterior, TimeOfDay3D.day);
      final slots = s.model.materials
          .map((m) => m.textureSlot)
          .whereType<String>()
          .toSet();
      expect(slots, contains(set.images.first.key));
      expect(s.ego!.imported, isTrue);
      expect(
        s.model.materials
            .where((m) => m.textureSlot == set.images.first.key)
            .every((m) => !m.textureEmissive),
        isTrue,
      );
    });

    test('camera mode switches at runtime', () {
      const t = DashTelemetry(speedKmh: 60, gear: Gear.drive);
      final s = scene(CameraMode.driver, TimeOfDay3D.day);
      s.update(1 / 30, t);
      expect(s.model.nodes[s.rig!.root].visible, isTrue);
      expect(s.model.nodes[s.ego!.root].visible, isFalse);
      final inside = s.model.camera.position.clone();

      s.mode = CameraMode.exterior;
      s.update(1 / 30, t);
      expect(s.model.nodes[s.rig!.root].visible, isFalse);
      expect(s.model.nodes[s.ego!.root].visible, isTrue);
      final outside = s.model.camera.position.clone();
      expect(outside.distanceTo(inside), greaterThan(3));
      // Camera looks at the vehicle from outside its body.
      final half = s.ego!.proportions.length / 2;
      expect(outside.xz.length, greaterThan(half));

      s.orbitBy(yaw: 1.2);
      s.update(1 / 30, t);
      expect(s.model.camera.position.distanceTo(outside), greaterThan(1));

      s.mode = CameraMode.chase;
      s.update(1 / 30, t);
      expect(s.model.camera.position.z, lessThan(-5));
    });

    test('night: lamps lit and beams visible from outside only', () {
      const t = DashTelemetry(speedKmh: 60, gear: Gear.drive);
      final s = scene(CameraMode.exterior, TimeOfDay3D.night);
      for (var i = 0; i < 5; i++) {
        s.update(1 / 30, t);
      }
      final e = s.ego!;
      expect(s.model.materials[e.head].emissiveStrength, greaterThan(1));
      expect(s.model.materials[e.tail].emissiveStrength, greaterThan(1));
      expect(s.model.nodes[e.beams!].visible, isTrue);
      final lit = s.model.lights.where((l) => l.intensity > 0).length;
      expect(lit, greaterThanOrEqualTo(3)); // two headlights + tail glow

      s.mode = CameraMode.driver;
      s.update(1 / 30, t);
      expect(s.model.nodes[e.beams!].visible, isFalse);
      // Road is still lit by the headlights from the driver's seat.
      expect(s.model.lights.where((l) => l.intensity > 0).length, 2);

      final day = scene(CameraMode.exterior, TimeOfDay3D.day)
        ..update(1 / 30, t);
      expect(day.model.nodes[day.ego!.beams!].visible, isFalse);
      expect(day.model.materials[day.ego!.head].emissiveStrength, lessThan(1));
    });
  });
}
