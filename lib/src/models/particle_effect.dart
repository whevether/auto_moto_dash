/// Mutually exclusive motion / particle backgrounds.
enum ParticleEffect {
  /// Car exterior wind rush (default).
  windRush,

  /// Black-hole / wormhole transit.
  blackHole,

  /// Sparse star tunnel.
  starTunnel,

  /// Perspective road / race-track rush.
  roadTrack,

  /// Colored ion sparks and short arcs.
  ionStorm,
}

extension ParticleEffectX on ParticleEffect {
  String get label => switch (this) {
        ParticleEffect.windRush => '风驰',
        ParticleEffect.blackHole => '黑洞穿越',
        ParticleEffect.starTunnel => '星门隧道',
        ParticleEffect.roadTrack => '道路赛道',
        ParticleEffect.ionStorm => '离子风暴',
      };
}