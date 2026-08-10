/// Mutually exclusive motion / particle backgrounds.
enum ParticleEffect {
  /// Car exterior wind rush (default).
  windRush,

  /// Black-hole / wormhole transit.
  blackHole,

  /// Dense star tunnel.
  starTunnel,

  /// Perspective cyber grid rush.
  cyberGrid,

  /// Colored ion sparks and short arcs.
  ionStorm,
}

extension ParticleEffectX on ParticleEffect {
  String get label => switch (this) {
        ParticleEffect.windRush => '风驰',
        ParticleEffect.blackHole => '黑洞穿越',
        ParticleEffect.starTunnel => '星门隧道',
        ParticleEffect.cyberGrid => '科技网格',
        ParticleEffect.ionStorm => '离子风暴',
      };
}