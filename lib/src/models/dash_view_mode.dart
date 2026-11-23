/// How `AutoMotoDashboard` presents the instruments.
enum DashViewMode {
  /// The instrument cluster on its own (default).
  cluster,

  /// First-person driver view: windscreen, road, traffic and the cluster in
  /// the cabin. Requires a `cockpitBuilder` (e.g. from `auto_moto_dash_3d.dart`);
  /// falls back to [cluster] without one.
  cockpit;

  String get label => switch (this) {
    DashViewMode.cluster => '仪表视图',
    DashViewMode.cockpit => '座舱视角',
  };
}
