import 'dart:math' as math;

/// Kind of road the 3D world and [RoadProfile] generate.
enum RoadScenario {
  city,
  highway,
  rural;

  String get label => switch (this) {
    RoadScenario.city => '城市',
    RoadScenario.highway => '高速',
    RoadScenario.rural => '乡道',
  };
}

/// Deterministic procedural road: curvature and elevation as functions of
/// distance, plus the lane layout. Shared by `DriveSimulation` and the 3D
/// views so the simulated vehicle and the drawn road always agree.
class RoadProfile {
  RoadProfile({
    this.scenario = RoadScenario.highway,
    this.seed = 7,
  }) : _phase = math.Random(seed).nextDouble() * 1000;

  final RoadScenario scenario;
  final int seed;
  final double _phase;

  /// Width of one lane in metres.
  double get laneWidthM => switch (scenario) {
    RoadScenario.city => 3.3,
    RoadScenario.highway => 3.75,
    RoadScenario.rural => 3.4,
  };

  /// Lanes in the ego direction of travel.
  int get lanes => switch (scenario) {
    RoadScenario.city => 2,
    RoadScenario.highway => 3,
    RoadScenario.rural => 1,
  };

  /// Oncoming lanes (left of the ego carriageway, right-hand traffic).
  int get oncomingLanes => switch (scenario) {
    RoadScenario.city => 2,
    RoadScenario.highway => 3,
    RoadScenario.rural => 1,
  };

  /// Lane the ego vehicle starts in; the reference line is its centre.
  int get egoLane => switch (scenario) {
    RoadScenario.city => 1,
    RoadScenario.highway => 1,
    RoadScenario.rural => 0,
  };

  /// Gap between the carriageways (median / barrier) in metres.
  double get medianM => switch (scenario) {
    RoadScenario.city => 0.6,
    RoadScenario.highway => 3.0,
    RoadScenario.rural => 0.15,
  };

  /// Suggested cruising speed of traffic in km/h.
  double get trafficSpeedKmh => switch (scenario) {
    RoadScenario.city => 50,
    RoadScenario.highway => 110,
    RoadScenario.rural => 70,
  };

  /// Lateral position (relative to the reference line) of a same-direction
  /// lane centre. Lane 0 is the leftmost (fast) lane.
  double laneCenter(int lane) => (lane - egoLane) * laneWidthM;

  /// Lateral position of an oncoming lane centre (0 = next to the median).
  double oncomingLaneCenter(int lane) =>
      laneCenter(0) - laneWidthM / 2 - medianM - laneWidthM * (lane + 0.5);

  /// Left / right edge of the ego carriageway.
  double get carriagewayLeft => laneCenter(0) - laneWidthM / 2;
  double get carriagewayRight => laneCenter(lanes - 1) + laneWidthM / 2;

  /// Outer edge of the oncoming carriageway.
  double get oncomingLeft =>
      carriagewayLeft - medianM - laneWidthM * oncomingLanes;

  /// Nearest same-direction lane to a lateral offset.
  int laneAt(double lateralM) =>
      ((lateralM / laneWidthM).round() + egoLane).clamp(0, lanes - 1);

  double get _amplitude => switch (scenario) {
    RoadScenario.city => 0.010,
    RoadScenario.highway => 0.0022,
    RoadScenario.rural => 0.012,
  };

  /// Road curvature at distance [s] in 1/m (positive bends right).
  double curvatureAt(double s) {
    final x = s + _phase;
    final raw =
        0.65 * math.sin(2 * math.pi * x / 620) +
        0.35 * math.sin(2 * math.pi * x / 233 + 1.3);
    // Dead zone produces straights between bends.
    final shaped = raw.sign * math.max(0.0, raw.abs() - 0.3) / 0.7;
    return _amplitude * shaped;
  }

  double get _hill => switch (scenario) {
    RoadScenario.city => 1.5,
    RoadScenario.highway => 6,
    RoadScenario.rural => 9,
  };

  /// Road elevation at distance [s] in metres.
  double elevationAt(double s) {
    final x = s + _phase * 0.7;
    return _hill *
        (0.7 * math.sin(2 * math.pi * x / 900) +
            0.3 * math.sin(2 * math.pi * x / 310 + 0.4));
  }

  /// Road grade (dy/ds) at distance [s].
  double gradeAt(double s) {
    final x = s + _phase * 0.7;
    return _hill *
        (0.7 * 2 * math.pi / 900 * math.cos(2 * math.pi * x / 900) +
            0.3 * 2 * math.pi / 310 * math.cos(2 * math.pi * x / 310 + 0.4));
  }
}
