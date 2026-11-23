import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

import 'imported_model.dart';

/// Loads a file referenced by a model (relative uri, already decoded).
typedef ModelResolver = Future<Uint8List> Function(String uri);

/// glTF 2.0 importer for `.glb` and `.gltf` (embedded, data-uri or external
/// buffers and images). Reads triangles / strips / fans with positions,
/// normals, TEXCOORD_0 and COLOR_0, node transforms, and PBR
/// metallic-roughness materials with a base colour texture.
abstract final class GltfImporter {
  static const _glbMagic = 0x46546C67;

  static bool isGlb(Uint8List b) =>
      b.length >= 12 &&
      ByteData.sublistView(b).getUint32(0, Endian.little) == _glbMagic;

  static Future<ImportedModel> parse(
    Uint8List bytes, {
    String name = 'model',
    ModelResolver? resolve,
    bool zUp = false,
  }) async {
    Map<String, dynamic> json;
    Uint8List? bin;
    if (isGlb(bytes)) {
      final d = ByteData.sublistView(bytes);
      var o = 12;
      json = const {};
      while (o + 8 <= bytes.length) {
        final len = d.getUint32(o, Endian.little);
        final type = d.getUint32(o + 4, Endian.little);
        final chunk = Uint8List.sublistView(bytes, o + 8, o + 8 + len);
        if (type == 0x4E4F534A) {
          json = jsonDecode(utf8.decode(chunk)) as Map<String, dynamic>;
        } else if (type == 0x004E4942) {
          bin = chunk;
        }
        o += 8 + len;
      }
    } else {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }
    final asset = json['asset'] as Map<String, dynamic>?;
    final version = asset?['version']?.toString() ?? '2.0';
    if (!version.startsWith('2')) {
      throw FormatException('glTF $version is not supported (need 2.x)');
    }

    Future<Uint8List> load(String uri) async {
      if (uri.startsWith('data:')) {
        return UriData.parse(uri).contentAsBytes();
      }
      if (resolve == null) {
        throw FormatException('External file "$uri" needs a resolver');
      }
      return resolve(Uri.decodeFull(uri));
    }

    final buffers = <Uint8List>[];
    for (final b in (json['buffers'] as List? ?? const [])) {
      final uri = (b as Map)['uri'] as String?;
      buffers.add(uri == null ? (bin ?? Uint8List(0)) : await load(uri));
    }
    final views = (json['bufferViews'] as List? ?? const []).cast<Map>();
    final accessors = (json['accessors'] as List? ?? const []).cast<Map>();

    Uint8List view(int i) {
      final v = views[i];
      final buf = buffers[v['buffer'] as int];
      final off = (v['byteOffset'] as int?) ?? 0;
      return Uint8List.sublistView(buf, off, off + (v['byteLength'] as int));
    }

    List<double> readAccessor(int i) {
      final a = accessors[i];
      final count = a['count'] as int;
      final comps = switch (a['type']) {
        'SCALAR' => 1,
        'VEC2' => 2,
        'VEC3' => 3,
        'VEC4' => 4,
        'MAT2' => 4,
        'MAT3' => 9,
        'MAT4' => 16,
        _ => throw FormatException('Accessor type ${a['type']}'),
      };
      final ct = a['componentType'] as int;
      final size = switch (ct) {
        5120 || 5121 => 1,
        5122 || 5123 => 2,
        5125 || 5126 => 4,
        _ => throw FormatException('Component type $ct'),
      };
      final out = List<double>.filled(count * comps, 0);
      final bv = a['bufferView'] as int?;
      if (bv == null) return out;
      final data = view(bv);
      final d = ByteData.sublistView(data);
      final stride = (views[bv]['byteStride'] as int?) ?? comps * size;
      final base = (a['byteOffset'] as int?) ?? 0;
      final norm = a['normalized'] == true;
      for (var e = 0; e < count; e++) {
        for (var c = 0; c < comps; c++) {
          final o = base + e * stride + c * size;
          double v;
          switch (ct) {
            case 5120:
              final x = d.getInt8(o);
              v = norm ? (x / 127).clamp(-1, 1).toDouble() : x.toDouble();
            case 5121:
              final x = d.getUint8(o);
              v = norm ? x / 255 : x.toDouble();
            case 5122:
              final x = d.getInt16(o, Endian.little);
              v = norm ? (x / 32767).clamp(-1, 1).toDouble() : x.toDouble();
            case 5123:
              final x = d.getUint16(o, Endian.little);
              v = norm ? x / 65535 : x.toDouble();
            case 5125:
              v = d.getUint32(o, Endian.little).toDouble();
            default:
              v = d.getFloat32(o, Endian.little);
          }
          out[e * comps + c] = v;
        }
      }
      return out;
    }

    // Images and materials.
    final images = <int, ImportedImage>{};
    final imageList = (json['images'] as List? ?? const []).cast<Map>();
    Future<ImportedImage?> image(int i) async {
      if (images.containsKey(i)) return images[i];
      final im = imageList[i];
      Uint8List bytes;
      String key;
      if (im['bufferView'] != null) {
        bytes = Uint8List.fromList(view(im['bufferView'] as int));
        key = '$name#image$i';
      } else {
        final uri = im['uri'] as String;
        bytes = await load(uri);
        key = uri.startsWith('data:') ? '$name#image$i' : '$name|$uri';
      }
      return images[i] = ImportedImage(
        key,
        bytes,
        mimeType: im['mimeType'] as String?,
      );
    }

    final textures = (json['textures'] as List? ?? const []).cast<Map>();
    final materials = <ImportedMaterial>[];
    for (final m in (json['materials'] as List? ?? const []).cast<Map>()) {
      final pbr = (m['pbrMetallicRoughness'] as Map?) ?? const {};
      final f = ((pbr['baseColorFactor'] as List?) ?? const [1, 1, 1, 1])
          .map((e) => (e as num).toDouble())
          .toList();
      ImportedImage? img;
      final tex = pbr['baseColorTexture'] as Map?;
      if (tex != null && ((tex['texCoord'] as int?) ?? 0) == 0) {
        final t = textures[tex['index'] as int];
        final src = t['source'] as int?;
        if (src != null) img = await image(src);
      }
      final ef = ((m['emissiveFactor'] as List?) ?? const [0, 0, 0])
          .map((e) => (e as num).toDouble())
          .toList();
      final ext = (m['extensions'] as Map?) ?? const {};
      final es =
          ((ext['KHR_materials_emissive_strength'] as Map?)?['emissiveStrength']
                  as num?)
              ?.toDouble() ??
          1;
      // Emission driven by a texture (dash graphics, reflections) is not
      // supported; a flat glow over the whole part would look wrong.
      final lit = m['emissiveTexture'] == null && ef.any((e) => e > 0);
      // Transmissive glass: tinted and see-through.
      final transmission =
          ((ext['KHR_materials_transmission'] as Map?)?['transmissionFactor']
                  as num?)
              ?.toDouble() ??
          0;
      final glass = transmission > 0;
      materials.add(
        ImportedMaterial(
          name: (m['name'] as String?) ?? '',
          color: glass && pbr['baseColorFactor'] == null
              ? const Color(0xFF1C242A)
              : colorFromLinear(f),
          metallic: ((pbr['metallicFactor'] as num?) ?? 1).toDouble(),
          roughness: ((pbr['roughnessFactor'] as num?) ?? 1).toDouble(),
          emissive: lit
              ? colorFromLinear(ef)
              : const ImportedMaterial().emissive,
          emissiveStrength: lit ? es : 0,
          opacity: glass
              ? (1 - 0.8 * transmission).clamp(0.15, 0.99)
              : (m['alphaMode'] == 'BLEND' ? f[3].clamp(0.05, 0.99) : 1),
          doubleSided: m['doubleSided'] == true || glass,
          image: img,
        ),
      );
    }
    const fallback = ImportedMaterial(metallic: 0, roughness: 0.6);

    // Node traversal: one accumulator per (part name, material).
    final nodes = (json['nodes'] as List? ?? const []).cast<Map>();
    final meshes = (json['meshes'] as List? ?? const []).cast<Map>();
    final parts = <(String, int), MeshAccumulator>{};

    Matrix4 local(Map n) {
      final m = n['matrix'] as List?;
      if (m != null) {
        return Matrix4.fromList([for (final e in m) (e as num).toDouble()]);
      }
      final t = (n['translation'] as List?)?.cast<num>();
      final r = (n['rotation'] as List?)?.cast<num>();
      final s = (n['scale'] as List?)?.cast<num>();
      return Matrix4.compose(
        t == null
            ? Vector3.zero()
            : Vector3(t[0].toDouble(), t[1].toDouble(), t[2].toDouble()),
        r == null
            ? Quaternion.identity()
            : Quaternion(
                r[0].toDouble(),
                r[1].toDouble(),
                r[2].toDouble(),
                r[3].toDouble(),
              ),
        s == null
            ? Vector3.all(1)
            : Vector3(s[0].toDouble(), s[1].toDouble(), s[2].toDouble()),
      );
    }

    void addPrimitive(Map prim, Matrix4 world, String part) {
      final mode = (prim['mode'] as int?) ?? 4;
      if (mode < 4) return; // points / lines
      final attrs = prim['attributes'] as Map;
      final pi = attrs['POSITION'] as int?;
      if (pi == null) return;
      final pos = readAccessor(pi);
      final ni = attrs['NORMAL'] as int?;
      final nor = ni == null ? null : readAccessor(ni);
      final ti = attrs['TEXCOORD_0'] as int?;
      final uv = ti == null ? null : readAccessor(ti);
      final ci = attrs['COLOR_0'] as int?;
      final col = ci == null ? null : readAccessor(ci);
      final colComps = ci == null
          ? 0
          : (accessors[ci]['type'] == 'VEC3' ? 3 : 4);
      final n = pos.length ~/ 3;
      var idx = prim['indices'] == null
          ? List<int>.generate(n, (i) => i)
          : [for (final v in readAccessor(prim['indices'] as int)) v.toInt()];
      if (mode == 5) {
        idx = [
          for (var i = 0; i + 2 < idx.length; i++)
            ...(i.isEven
                ? [idx[i], idx[i + 1], idx[i + 2]]
                : [idx[i + 1], idx[i], idx[i + 2]]),
        ];
      } else if (mode == 6) {
        idx = [
          for (var i = 1; i + 1 < idx.length; i++) ...[
            idx[0],
            idx[i],
            idx[i + 1],
          ],
        ];
      }
      final matIndex = (prim['material'] as int?) ?? -1;
      final acc = parts.putIfAbsent((part, matIndex), MeshAccumulator.new);
      final base = acc.vertexCount;
      if (nor == null) acc.hasNormals = false;
      if (uv != null) acc.hasUvs = true;
      if (col != null) acc.hasColors = true;
      final normalMat = world.getNormalMatrix();
      final flip = world.determinant() < 0;
      for (var i = 0; i < n; i++) {
        final p = world.transformed3(
          Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]),
        );
        acc.positions.addAll([p.x, p.y, p.z]);
        if (nor != null) {
          final q =
              (normalMat * Vector3(nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2]))
                ..normalize();
          acc.normals.addAll([q.x, q.y, q.z]);
        } else {
          acc.normals.addAll(const [0, 1, 0]);
        }
        if (uv != null) {
          acc.uvs.addAll([uv[i * 2], uv[i * 2 + 1]]);
        } else {
          acc.uvs.addAll(const [0, 0]);
        }
        if (col != null) {
          acc.colors.addAll([
            col[i * colComps],
            col[i * colComps + 1],
            col[i * colComps + 2],
            colComps == 4 ? col[i * colComps + 3] : 1,
          ]);
        } else {
          acc.colors.addAll(const [1, 1, 1, 1]);
        }
      }
      for (var t = 0; t + 2 < idx.length; t += 3) {
        if (flip) {
          acc.indices.addAll([
            base + idx[t],
            base + idx[t + 2],
            base + idx[t + 1],
          ]);
        } else {
          acc.indices.addAll([
            base + idx[t],
            base + idx[t + 1],
            base + idx[t + 2],
          ]);
        }
      }
    }

    void visit(int i, Matrix4 parent, String part, int depth) {
      if (depth > 64) return;
      final n = nodes[i];
      final world = parent * local(n);
      final nodeName = n['name'] as String?;
      final here = (nodeName != null && nodeName.isNotEmpty) ? nodeName : part;
      final mi = n['mesh'] as int?;
      if (mi != null) {
        final mesh = meshes[mi];
        final meshPart = here.isNotEmpty
            ? here
            : ((mesh['name'] as String?) ?? 'mesh$mi');
        for (final prim in (mesh['primitives'] as List).cast<Map>()) {
          addPrimitive(prim, world, meshPart);
        }
      }
      for (final c in (n['children'] as List? ?? const [])) {
        visit(c as int, world, here, depth + 1);
      }
    }

    final scenes = (json['scenes'] as List? ?? const []).cast<Map>();
    final sceneIndex = (json['scene'] as int?) ?? 0;
    List<int> roots;
    if (scenes.isNotEmpty) {
      roots = [
        for (final r in (scenes[sceneIndex]['nodes'] as List? ?? const []))
          r as int,
      ];
    } else {
      final children = <int>{
        for (final n in nodes)
          for (final c in (n['children'] as List? ?? const [])) c as int,
      };
      roots = [
        for (var i = 0; i < nodes.length; i++)
          if (!children.contains(i)) i,
      ];
    }
    for (final r in roots) {
      visit(r, Matrix4.identity(), '', 0);
    }

    return ImportedModel([
      for (final MapEntry(key: (part, mat), value: acc) in parts.entries)
        if (acc.indices.isNotEmpty)
          ImportedPart(
            part.isEmpty ? 'mesh' : part,
            acc.build(zUp: zUp),
            mat >= 0 && mat < materials.length ? materials[mat] : fallback,
          ),
    ], source: name);
  }
}
