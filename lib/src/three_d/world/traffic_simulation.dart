import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';

/// Intelligent Driver Model parameters.
class IdmParams {
  const IdmParams({
    this.desiredSpeed = 30,
    this.timeHeadway = 1.4,
    this.minGap = 2.5,
    this.maxAccel = 1.4,
    this.comfortDecel = 2.2,
  });
  final double desiredSpeed, timeHeadway, minGap, maxAccel, comfortDecel;

  /// IDM acceleration for speed [v], bumper gap [gap] and approach rate
  /// [dv] (own speed minus leader speed). Pass `gap = double.infinity` for
  /// a free road.
  double accel(double v, double gap, double dv) {
    final free = 1 - math.pow(v / desiredSpeed, 4);
    if (!gap.isFinite) return maxAccel * free;
    final sStar =
        minGap +
        math.max(
          0.0,
          v * timeHeadway + v * dv / (2 * math.sqrt(maxAccel * comfortDecel)),
        );
    final g = math.max(gap, 0.1);
    return (maxAccel * (free - (sStar / g) * (sStar / g))).clamp(
      -9.0,
      maxAccel,
    );
  }
}

/// Body width of a traffic vehicle (metres, mirrors excluded).
double vehicleWidthM(TrafficVehicleKind kind) => switch (kind) {
  TrafficVehicleKind.sedan => 1.84,
  TrafficVehicleKind.suv => 1.93,
  TrafficVehicleKind.pickup => 2.0,
  TrafficVehicleKind.van => 2.0,
  TrafficVehicleKind.truck => 2.45,
  TrafficVehicleKind.bus => 2.55,
  TrafficVehicleKind.motorcycle => 0.8,
};

/// Footprint of the ego vehicle for collision checks.
class EgoFootprint {
  const EgoFootprint({this.lengthM = 4.7, this.widthM = 1.9});
  const EgoFootprint.motorcycle() : lengthM = 2.15, widthM = 0.8;
  final double lengthM, widthM;
}

/// Minimum bumper-to-bumper gap kept between bodies (metres).
const double minBumperGapM = 0.6;

/// Minimum side clearance kept between bodies (metres).
const double minSideGapM = 0.25;

bool _spansOverlap((double, double) a, (double, double) b, double margin) =>
    a.$1 < b.$2 + margin && b.$1 < a.$2 + margin;

/// A simulated surrounding vehicle in road coordinates.
class SimVehicle {
  SimVehicle({
    required this.id,
    required this.kind,
    required this.color,
    required this.lane,
    required this.s,
    required this.v,
    required this.params,
    required this.oncoming,
    required this.lateral,
  }) : targetLateral = lateral;

  final int id;
  TrafficVehicleKind kind;
  Color color;

  /// Lane index: same-direction lanes, or oncoming lanes when [oncoming].
  int lane;
  double s, v, accel = 0;
  IdmParams params;
  final bool oncoming;

  /// Lateral position (from reference lane centre) and lane-change target.
  double lateral, targetLateral;
  double laneChangeCooldown = 0;
  double blockedTime = 0;
  double signalTimer = 0;
  int signalDir = 0;

  double get length => kind.lengthM;
  double get width => vehicleWidthM(kind);

  /// Lateral extent swept by the body, including an unfinished lane change
  /// (the vehicle blocks both lanes until it has moved over).
  (double, double) get span {
    final h = width / 2;
    return (
      math.min(lateral, targetLateral) - h,
      math.max(lateral, targetLateral) + h,
    );
  }

  bool get braking => accel < -0.8 || v < 0.3;
  bool get leftIndicator => signalDir < 0;
  bool get rightIndicator => signalDir > 0;
}

/// Surrounding traffic: IDM car following, MOBIL lane changes, oncoming
/// flow, recycling around the ego vehicle.
class TrafficSimulation {
  TrafficSimulation(this.road, {this.density = 1, int seed = 3})
    : _rng = math.Random(seed);

  final RoadProfile road;

  /// 0..1.5, scales the number of vehicles.
  double density;
  final math.Random _rng;
  final List<SimVehicle> vehicles = [];
  int _nextId = 1;

  static const behind = 70.0;
  static const ahead = 320.0;

  /// MOBIL politeness and threshold.
  static const politeness = 0.3;
  static const changeThreshold = 0.25;
  static const safeDecel = 3.5;

  static const _palette = [
    Color(0xFFE8E8E8),
    Color(0xFF1C1C1C),
    Color(0xFF8A9096),
    Color(0xFF2B4C7E),
    Color(0xFF8E1B1B),
    Color(0xFFC0C4C8),
    Color(0xFF3E5641),
    Color(0xFF5B5F63),
    Color(0xFFD9C9A3),
    Color(0xFF14365C),
  ];

  int get _targetSame => ((road.lanes * 7) * density).round();
  int get _targetOncoming => ((road.oncomingLanes * 4) * density).round();

  TrafficVehicleKind _randomKind() {
    final r = _rng.nextDouble();
    final heavy = road.scenario == RoadScenario.highway ? 0.18 : 0.1;
    if (r < heavy * 0.6) return TrafficVehicleKind.truck;
    if (r < heavy) {
      return road.scenario == RoadScenario.city
          ? TrafficVehicleKind.bus
          : TrafficVehicleKind.van;
    }
    if (r < heavy + 0.06) return TrafficVehicleKind.motorcycle;
    if (r < heavy + 0.14) return TrafficVehicleKind.pickup;
    if (r < heavy + 0.4) return TrafficVehicleKind.suv;
    if (r < heavy + 0.47) return TrafficVehicleKind.van;
    return TrafficVehicleKind.sedan;
  }

  IdmParams _params(TrafficVehicleKind kind, int lane) {
    final base = road.trafficSpeedKmh / 3.6;
    final heavy =
        kind == TrafficVehicleKind.truck || kind == TrafficVehicleKind.bus;
    // Faster in left lanes on multi-lane roads.
    final laneBias = road.lanes > 1 ? (road.lanes - 1 - lane) * 0.06 : 0.0;
    final v0 =
        base * (heavy ? 0.82 : 0.92 + _rng.nextDouble() * 0.2 + laneBias);
    return IdmParams(
      desiredSpeed: v0,
      timeHeadway: 1.1 + _rng.nextDouble() * 0.8,
      maxAccel: heavy ? 0.8 : 1.2 + _rng.nextDouble() * 0.8,
      comfortDecel: heavy ? 1.6 : 2.2,
    );
  }

  double _laneLateral(int lane, bool oncoming) =>
      oncoming ? road.oncomingLaneCenter(lane) : road.laneCenter(lane);

  SimVehicle _spawn(double s, int lane, bool oncoming) {
    final kind = _randomKind();
    final params = _params(kind, lane);
    return SimVehicle(
      id: _nextId++,
      kind: kind,
      color: _palette[_rng.nextInt(_palette.length)],
      lane: lane,
      s: s,
      v: params.desiredSpeed * (0.8 + _rng.nextDouble() * 0.2),
      params: params,
      oncoming: oncoming,
      lateral: _laneLateral(lane, oncoming),
    );
  }

  /// Fills the road around the ego when empty.
  void _populate(_Ego ego) {
    final same = vehicles.where((v) => !v.oncoming).length;
    for (var i = same; i < _targetSame; i++) {
      final lane = _rng.nextInt(road.lanes);
      final s = ego.s - behind + _rng.nextDouble() * (ahead + behind);
      if (_spawnOk(s, lane, false, 14, ego)) {
        vehicles.add(_spawn(s, lane, false));
      }
    }
    final onc = vehicles.where((v) => v.oncoming).length;
    for (var i = onc; i < _targetOncoming; i++) {
      final lane = _rng.nextInt(road.oncomingLanes);
      final s = ego.s + _rng.nextDouble() * ahead;
      if (_spawnOk(s, lane, true, 25, ego)) vehicles.add(_spawn(s, lane, true));
    }
  }

  /// Whether a vehicle may appear at [s] in [lane] without touching anyone.
  bool _spawnOk(double s, int lane, bool oncoming, double gap, _Ego ego) {
    final lat = _laneLateral(lane, oncoming);
    final span = (lat - 1.3, lat + 1.3);
    if (_spansOverlap(span, ego.span, minSideGapM) &&
        (s - ego.s).abs() < gap + ego.length) {
      return false;
    }
    return vehicles.every(
      (v) =>
          v.oncoming != oncoming ||
          !_spansOverlap(v.span, span, 0) ||
          (v.s - s).abs() > gap + v.length,
    );
  }

  /// Nearest body ahead in the direction of travel whose lateral extent
  /// overlaps [span]. The ego is an obstacle for both directions; for
  /// oncoming vehicles its speed counts as closing speed.
  (double gap, double leaderV) _leader(
    double s,
    (double, double) span,
    bool oncoming,
    SimVehicle? self,
    double selfLength,
    _Ego ego,
  ) {
    var best = double.infinity, bestV = 0.0;
    final dir = oncoming ? -1.0 : 1.0;
    for (final o in vehicles) {
      if (identical(o, self) || o.oncoming != oncoming) continue;
      if (!_spansOverlap(o.span, span, minSideGapM)) continue;
      final d = (o.s - s) * dir;
      final gap = d - (o.length + selfLength) / 2;
      if (d > 0 && gap < best) {
        best = gap;
        bestV = o.v;
      }
    }
    if (_spansOverlap(ego.span, span, minSideGapM)) {
      final d = (ego.s - s) * dir;
      final gap = d - (ego.length + selfLength) / 2;
      if (d > 0 && gap < best) {
        best = gap;
        bestV = ego.v * dir;
      }
    }
    return (best, bestV);
  }

  /// Nearest same-direction body behind [s] overlapping [span].
  (double gap, SimVehicle? follower) _follower(
    double s,
    (double, double) span,
    SimVehicle self,
  ) {
    var best = double.infinity;
    SimVehicle? who;
    for (final o in vehicles) {
      if (identical(o, self) || o.oncoming) continue;
      if (!_spansOverlap(o.span, span, minSideGapM)) continue;
      final d = s - o.s;
      final gap = d - (o.length + self.length) / 2;
      if (d > 0 && gap < best) {
        best = gap;
        who = o;
      }
    }
    return (best, who);
  }

  /// Advances traffic by [dt] seconds around the ego at [egoS] (m) driving at
  /// [egoSpeed] (m/s, negative when reversing) with lateral offset
  /// [egoLateral]. Traffic treats the ego body as a solid obstacle.
  void tick(
    double dt, {
    required double egoS,
    required double egoSpeed,
    required double egoLateral,
    double egoLength = 4.7,
    double egoWidth = 1.9,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    dt = math.min(dt, 0.1);
    final ego = _Ego(egoS, egoSpeed, egoLength, egoLateral, egoWidth);
    _populate(ego);

    for (final v in vehicles) {
      final (gap, lv) = _leader(v.s, v.span, v.oncoming, v, v.length, ego);
      v.accel = v.params.accel(v.v, gap, v.v - lv);
    }
    for (final v in vehicles) {
      if (!v.oncoming && road.lanes > 1) _mobil(v, ego);
      v.v = math.max(0, v.v + v.accel * dt);
      v.s += v.v * dt * (v.oncoming ? -1 : 1);
      // Smooth lateral motion toward the target lane (≈ 3.5 s change); the
      // manoeuvre pauses (and is eventually abandoned) when someone is
      // alongside.
      final dl = v.targetLateral - v.lateral;
      if (dl.abs() > 1e-6) {
        final next = v.lateral + dl.sign * math.min(dl.abs(), 1.1 * dt);
        if (_lateralBlocked(v, next, ego)) {
          v.blockedTime += dt;
          if (v.blockedTime > 1.5) {
            v.lane = road.laneAt(v.lateral);
            v.targetLateral = road.laneCenter(v.lane);
            v.signalDir = 0;
            v.blockedTime = 0;
          }
        } else {
          v.lateral = next;
          v.blockedTime = 0;
        }
      }
      if ((v.targetLateral - v.lateral).abs() < 0.05 && v.signalTimer <= 0) {
        v.signalDir = 0;
      }
      v.signalTimer -= dt;
      v.laneChangeCooldown -= dt;
    }
    _enforceSeparation(ego);

    // Recycle vehicles that left the window to the far end.
    for (final v in vehicles) {
      final rel = v.s - egoS;
      if (rel < -behind || rel > ahead + 40) {
        final front = v.oncoming || rel < 0;
        final lane = _rng.nextInt(v.oncoming ? road.oncomingLanes : road.lanes);
        final s = front
            ? egoS + ahead - _rng.nextDouble() * 30
            : egoS - behind + 5;
        if (!_spawnOk(s, lane, v.oncoming, 20, ego)) continue;
        final n = _spawn(s, lane, v.oncoming);
        if (!front) n.v = math.max(n.v, egoSpeed + 2);
        v
          ..kind = n.kind
          ..color = n.color
          ..lane = lane
          ..s = s
          ..v = n.v
          ..params = n.params
          ..lateral = n.lateral
          ..targetLateral = n.lateral
          ..blockedTime = 0
          ..signalDir = 0;
      }
    }
  }

  /// Whether moving [v] sideways to [lateral] would bring it into contact
  /// with a body it is not already touching.
  bool _lateralBlocked(SimVehicle v, double lateral, _Ego ego) {
    final h = v.width / 2;
    final next = (lateral - h, lateral + h);
    final now = (v.lateral - h, v.lateral + h);
    bool hits((double, double) other, double s, double length) {
      if ((s - v.s).abs() >= (length + v.length) / 2 + minBumperGapM) {
        return false;
      }
      return _spansOverlap(next, other, minSideGapM) &&
          !_spansOverlap(now, other, minSideGapM);
    }

    for (final o in vehicles) {
      if (identical(o, v) || o.oncoming != v.oncoming) continue;
      final oh = o.width / 2;
      if (hits((o.lateral - oh, o.lateral + oh), o.s, o.length)) return true;
    }
    return hits(ego.span, ego.s, ego.length);
  }

  /// Hard constraint: no two bodies (ego included) may overlap. Each vehicle
  /// is kept behind whatever is ahead of it in its direction of travel.
  void _enforceSeparation(_Ego ego) {
    for (final oncoming in [false, true]) {
      final dir = oncoming ? -1.0 : 1.0;
      final list = vehicles.where((v) => v.oncoming == oncoming).toList()
        ..sort((a, b) => oncoming ? a.s.compareTo(b.s) : b.s.compareTo(a.s));
      for (var i = 0; i < list.length; i++) {
        final v = list[i];
        final h = v.width / 2;
        final body = (v.lateral - h, v.lateral + h);
        void keepBehind(
          double s,
          double length,
          double speed,
          (double, double) span,
        ) {
          if (!_spansOverlap(body, span, 0.05)) return;
          final d = (s - v.s) * dir;
          final need = (length + v.length) / 2 + minBumperGapM;
          if (d < 0 || d >= need) return;
          v.s = s - dir * need;
          v.v = math.min(v.v, math.max(0, speed));
          v.accel = math.min(v.accel, 0);
        }

        for (var j = 0; j < i; j++) {
          final o = list[j];
          final oh = o.width / 2;
          keepBehind(o.s, o.length, o.v, (o.lateral - oh, o.lateral + oh));
        }
        keepBehind(ego.s, ego.length, ego.v * dir, ego.span);
      }
    }
  }

  void _mobil(SimVehicle v, _Ego ego) {
    if (v.laneChangeCooldown > 0 ||
        (v.targetLateral - v.lateral).abs() > 0.05) {
      return;
    }
    v.laneChangeCooldown = 1 + _rng.nextDouble();
    var bestGain = changeThreshold;
    var bestLane = -1;
    for (final dir in [-1, 1]) {
      final lane = v.lane + dir;
      if (lane < 0 || lane >= road.lanes) continue;
      final c = road.laneCenter(lane);
      final span = (c - v.width / 2, c + v.width / 2);
      final (gap, lv) = _leader(v.s, span, false, v, v.length, ego);
      if (gap < 4) continue;
      final aNew = v.params.accel(v.v, gap, v.v - lv);
      // Safety: new follower must not brake harder than safeDecel.
      final (fGap, follower) = _follower(v.s, span, v);
      if (fGap < 3) continue;
      // The ego as new follower: never cut in close in front of it.
      if (_spansOverlap(ego.span, span, minSideGapM)) {
        final d = v.s - ego.s;
        final egoGap = d.abs() - (ego.length + v.length) / 2;
        if (egoGap < 6) continue;
        if (d > 0) {
          final egoAfter = const IdmParams(desiredSpeed: 40)
              .accel(math.max(ego.v, 0), egoGap, ego.v - v.v);
          if (egoAfter < -safeDecel * 0.6) continue;
        }
      }
      var followerCost = 0.0;
      if (follower != null) {
        final aAfter = follower.params.accel(
          follower.v,
          fGap,
          follower.v - v.v,
        );
        if (aAfter < -safeDecel) continue;
        followerCost = follower.accel - aAfter;
      }
      // Keep-right bias (right-hand traffic).
      final bias = dir > 0 ? 0.1 : -0.05;
      final gain = aNew - v.accel - politeness * followerCost + bias;
      if (gain > bestGain) {
        bestGain = gain;
        bestLane = lane;
      }
    }
    if (bestLane >= 0) {
      v.signalDir = bestLane > v.lane ? 1 : -1;
      v.signalTimer = 1.2;
      v.lane = bestLane;
      v.targetLateral = road.laneCenter(bestLane);
      v.laneChangeCooldown = 6;
    }
  }

  /// Converts to the host-facing model in ego coordinates (approximate on
  /// curves: z is the along-road distance).
  List<TrafficVehicle> snapshot({
    required double egoS,
    required double egoLateral,
    bool night = false,
  }) => [
    for (final v in vehicles)
      TrafficVehicle(
        id: v.id,
        kind: v.kind,
        xM: v.lateral - egoLateral,
        zM: v.s - egoS,
        headingDeg: v.oncoming ? 180 : 0,
        speedKmh: v.v * 3.6,
        color: v.color,
        braking: v.braking,
        leftIndicator: v.leftIndicator,
        rightIndicator: v.rightIndicator,
        headlights: night,
      ),
  ];
}

class _Ego {
  _Ego(this.s, this.v, this.length, this.lateral, this.width);
  final double s, v, length, lateral, width;
  (double, double) get span => (lateral - width / 2, lateral + width / 2);
}
