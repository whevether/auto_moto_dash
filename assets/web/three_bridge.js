// auto_moto_dash 3D web bridge: owns the three.js (r187) scene so Dart only
// sends per-frame deltas. Loaded with dynamic import() from Dart.
import * as THREE from './three/three.module.js';

const lin = (c) => new THREE.Color().setRGB(c[0], c[1], c[2], THREE.SRGBColorSpace);

class Bridge {
  constructor(canvas) {
    this.canvas = canvas;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(50, 1, 0.05, 900);
    this.geometries = [];
    this.materials = [];
    this.nodes = [];
    this.lights = [];
    this.textures = {};
    this.sun = new THREE.DirectionalLight(0xffffff, 3);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    const s = this.sun.shadow.camera;
    s.left = -40; s.right = 40; s.top = 40; s.bottom = -40; s.near = 1; s.far = 200;
    this.sun.shadow.bias = -0.0004;
    this.hemi = new THREE.HemisphereLight(0xffffff, 0x444444, 1);
    this.scene.add(this.sun, this.sun.target, this.hemi);
    this.sky = this._makeSky();
    this.scene.add(this.sky);
    this.scene.fog = new THREE.FogExp2(0xbbccdd, 0.004);
  }

  _makeSky() {
    const geo = new THREE.SphereGeometry(800, 32, 16);
    const mat = new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false, fog: false,
      uniforms: {
        zenith: { value: new THREE.Color() }, horizon: { value: new THREE.Color() },
        ground: { value: new THREE.Color() }, sunDir: { value: new THREE.Vector3(0, 1, 0) },
        sunColor: { value: new THREE.Color(1, 0.95, 0.85) },
      },
      vertexShader: 'varying vec3 vDir; void main(){ vDir = normalize(position); vec4 p = modelViewMatrix * vec4(position,1.0); gl_Position = projectionMatrix * p; gl_Position.z = gl_Position.w; }',
      fragmentShader: 'uniform vec3 zenith; uniform vec3 horizon; uniform vec3 ground; uniform vec3 sunDir; uniform vec3 sunColor; varying vec3 vDir; void main(){ float h = vDir.y; vec3 c = h > 0.0 ? mix(horizon, zenith, pow(h, 0.6)) : mix(horizon, ground, pow(-h, 0.4)); float s = max(dot(normalize(vDir), normalize(sunDir)), 0.0); c += sunColor * (pow(s, 600.0) * 4.0 + pow(s, 8.0) * 0.25); gl_FragColor = vec4(c, 1.0); }',
    });
    const m = new THREE.Mesh(geo, mat);
    m.frustumCulled = false;
    m.renderOrder = -1;
    return m;
  }

  // model: { meshes:[{positions,normals,indices,dynamic}], materials:[...], nodes:[...], lights:[...], quality }
  attach(model) {
    const high = model.quality === 'high';
    this.renderer.shadowMap.enabled = model.quality !== 'low';
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, model.quality === 'low' ? 1 : 2));
    for (const m of model.meshes) {
      const g = new THREE.BufferGeometry();
      const pos = new THREE.BufferAttribute(m.positions, 3);
      const nor = new THREE.BufferAttribute(m.normals, 3);
      if (m.dynamic) { pos.setUsage(THREE.DynamicDrawUsage); nor.setUsage(THREE.DynamicDrawUsage); }
      g.setAttribute('position', pos);
      g.setAttribute('normal', nor);
      // Planar UVs from x/y extents for textured screens.
      g.setIndex(new THREE.BufferAttribute(m.indices, 1));
      g.computeBoundingSphere();
      if (m.uvs) g.setAttribute('uv', new THREE.BufferAttribute(m.uvs, 2));
      if (m.colors) g.setAttribute('color', new THREE.BufferAttribute(m.colors, 4));
      this.geometries.push(g);
    }
    for (const d of model.materials) this.materials.push(this._material(d));
    for (const n of model.nodes) {
      let o;
      if (n.mesh != null && n.material != null) {
        o = new THREE.Mesh(this.geometries[n.mesh], this.materials[n.material]);
        o.castShadow = n.castsShadow && high;
        o.receiveShadow = true;
        if (this.geometries[n.mesh].attributes.position.usage === THREE.DynamicDrawUsage) o.frustumCulled = false;
      } else {
        o = new THREE.Group();
      }
      o.name = n.name || '';
      o.matrixAutoUpdate = false;
      o.matrix.fromArray(n.transform);
      o.visible = n.visible;
      this.nodes.push(o);
      (n.parent < 0 ? this.scene : this.nodes[n.parent]).add(o);
    }
    for (const l of model.lights) {
      let light;
      if (l.kind === 'spot') {
        light = new THREE.SpotLight(lin(l.color), l.intensity, l.range, l.coneRad, l.penumbra, 2);
        light.castShadow = l.castsShadow && high;
        const t = new THREE.Object3D();
        t.position.set(l.direction[0], l.direction[1], l.direction[2]);
        this.nodes[l.node].add(t);
        light.target = t;
      } else {
        light = new THREE.PointLight(lin(l.color), l.intensity, l.range, 2);
      }
      this.nodes[l.node].add(light);
      this.lights.push(light);
    }
  }

  _material(d) {
    const params = {
      color: lin(d.color), transparent: d.opacity < 1, opacity: d.opacity,
      side: d.doubleSided ? THREE.DoubleSide : THREE.FrontSide,
      polygonOffset: d.depthLayer > 0, polygonOffsetFactor: -d.depthLayer, polygonOffsetUnits: -d.depthLayer * 2,
      depthWrite: d.opacity >= 1,
      vertexColors: !!d.vertexColors,
    };
    let m;
    if (d.unlit) {
      m = new THREE.MeshBasicMaterial(params);
    } else {
      m = new THREE.MeshPhysicalMaterial({
        ...params, metalness: d.metallic, roughness: d.roughness,
        clearcoat: d.clearcoat, clearcoatRoughness: 0.08,
        emissive: lin(d.emissive), emissiveIntensity: d.emissiveStrength,
      });
    }
    m.userData.slot = d.textureSlot || null;
    m.userData.texEmissive = d.textureEmissive !== false;
    return m;
  }

  _syncMaterial(m, d) {
    m.color.copy(lin(d.color));
    m.opacity = d.opacity;
    if (m.isMeshBasicMaterial) {
      if (d.emissiveStrength > 0) m.color.lerp(lin(d.emissive), Math.min(1, d.emissiveStrength));
    } else {
      m.metalness = d.metallic; m.roughness = d.roughness;
      m.emissive.copy(lin(d.emissive)); m.emissiveIntensity = d.emissiveStrength;
    }
  }

  // frame: { meshes:[{i,positions,normals}], nodes:[{i,m,v}], materials:[{i,...}], lights:[...], env, camera }
  apply(f) {
    for (const u of f.meshes) {
      const g = this.geometries[u.i];
      g.attributes.position.array.set(u.positions); g.attributes.position.needsUpdate = true;
      g.attributes.normal.array.set(u.normals); g.attributes.normal.needsUpdate = true;
    }
    for (const u of f.nodes) {
      const o = this.nodes[u.i];
      o.matrix.fromArray(u.m);
      o.visible = u.v;
      o.matrixWorldNeedsUpdate = true;
    }
    for (const u of f.materials) this._syncMaterial(this.materials[u.i], u);
    for (const u of f.lights) {
      const l = this.lights[u.i];
      l.color.copy(lin(u.color)); l.intensity = u.intensity; l.distance = u.range;
      if (l.isSpotLight) { l.angle = u.coneRad; l.target.position.set(u.direction[0], u.direction[1], u.direction[2]); }
    }
    if (f.env) this._env(f.env);
    const c = f.camera;
    this.camera.position.set(c.position[0], c.position[1], c.position[2]);
    this.camera.up.set(c.up[0], c.up[1], c.up[2]);
    this.camera.lookAt(c.target[0], c.target[1], c.target[2]);
    this.camera.fov = c.fovRad * 180 / Math.PI;
    this.camera.near = c.near; this.camera.far = c.far;
    this._resize();
    this.sky.position.copy(this.camera.position);
    // Shadow frustum follows the camera.
    const d = this._sunDir || new THREE.Vector3(0, 1, 0);
    this.sun.target.position.copy(this.camera.position);
    this.sun.position.copy(this.camera.position).addScaledVector(d, 80);
    this.renderer.render(this.scene, this.camera);
  }

  _env(e) {
    this._sunDir = new THREE.Vector3(e.sunDirection[0], e.sunDirection[1], e.sunDirection[2]).normalize();
    this.sun.color.copy(lin(e.sunColor)); this.sun.intensity = e.sunIntensity;
    this.sun.castShadow = e.shadows && this.renderer.shadowMap.enabled;
    this.hemi.color.copy(lin(e.zenith)); this.hemi.groundColor.copy(lin(e.ground));
    this.hemi.intensity = e.ambientIntensity;
    const u = this.sky.material.uniforms;
    u.zenith.value.copy(lin(e.zenith)); u.horizon.value.copy(lin(e.horizon));
    u.ground.value.copy(lin(e.ground)); u.sunDir.value.copy(this._sunDir);
    u.sunColor.value.setScalar(e.night ? 0.3 : 1);
    this.scene.fog.color.copy(lin(e.fogColor)); this.scene.fog.density = e.fogDensity;
    this.renderer.toneMappingExposure = e.exposure;
  }

  _resize() {
    const w = this.canvas.clientWidth | 0, h = this.canvas.clientHeight | 0;
    if (w === 0 || h === 0) return;
    if (w !== this._w || h !== this._h) {
      this._w = w; this._h = h;
      this.renderer.setSize(w, h, false);
    }
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  // rgba: Uint8Array, premultiplied=false
  updateTexture(slot, rgba, width, height) {
    let t = this.textures[slot];
    if (!t || t.image.width !== width || t.image.height !== height) {
      if (t) t.dispose();
      t = new THREE.DataTexture(new Uint8Array(width * height * 4), width, height, THREE.RGBAFormat);
      t.colorSpace = THREE.SRGBColorSpace;
      t.flipY = false; // mesh UVs use v = 0 at the top edge

      t.minFilter = THREE.LinearFilter;
      t.generateMipmaps = false;
      this.textures[slot] = t;
      for (const m of this.materials) {
        if (m.userData.slot !== slot) continue;
        m.map = t;
        if (m.userData.texEmissive && m.emissiveMap !== undefined && !m.isMeshBasicMaterial) { m.emissiveMap = t; m.emissive.setScalar(1); }
        m.needsUpdate = true;
      }
    }
    t.image.data.set(rgba);
    t.needsUpdate = true;
  }

  dispose() {
    for (const g of this.geometries) g.dispose();
    for (const m of this.materials) m.dispose();
    for (const t of Object.values(this.textures)) t.dispose();
    this.renderer.dispose();
  }
}

export function create(canvas) { return new Bridge(canvas); }
export const revision = THREE.REVISION;
