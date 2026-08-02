import 'package:flame/components.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/ally_rewards.dart';
import 'package:pescivendolo_game/game/attack_ability_manager.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';

/// Fascio energetico sparato dal giocatore (abilità acquistabile, vedi
/// AttackAbilityManager): parte dritto davanti a lui e danneggia
/// istantaneamente tutto ciò che incontra sul suo cammino. Il danno viene
/// applicato subito allo spawn; l'animazione (fish_attack1→2→3) è solo
/// l'effetto visivo che segue.
class EnergyBeam extends SpriteAnimationComponent with HasGameRef<FishGame> {
  static const double reach = 500.0; // gittata del fascio
  static const double spriteHeight = 160.0; // deve combaciare con size.y qui sotto
  // Colpisce tutto lungo l'intera altezza dello sprite del fascio, non solo
  // una striscia stretta al centro: altrimenti un nemico visibilmente
  // dentro il raggio disegnato poteva non essere colpito.
  static const double verticalTolerance = spriteHeight / 2;

  final bool facingRight;
  final double _originY;
  final double _originX;

  EnergyBeam({required Vector2 origin, required this.facingRight})
      : _originX = origin.x,
        _originY = origin.y,
        super(
          position: origin.clone(),
          anchor: facingRight ? Anchor.centerLeft : Anchor.centerRight,
          size: Vector2(reach, spriteHeight),
          removeOnFinish: true,
        ) {
    if (!facingRight) {
      flipHorizontally();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final frames = await Future.wait([
        gameRef.images.load('fish_attack1.webp'),
        gameRef.images.load('fish_attack2.webp'),
        gameRef.images.load('fish_attack3.webp'),
      ]);
      animation = SpriteAnimation.spriteList(
        frames.map((img) => Sprite(img)).toList(),
        stepTime: 0.09,
        loop: false,
      );
    } catch (e, stackTrace) {
      developer.log('Errore in EnergyBeam.onLoad (sprite): $e\n$stackTrace');
      removeFromParent();
      return;
    }

    AudioManager.playSoundEffect(AudioManager.electroShockFile, volume: 0.6);
    _applyDamage();
  }

  void _applyDamage() {
    try {
      final damage = AttackAbilityManager.rollDamage();
      developer.log('EnergyBeam: sparato, danno=$damage, facingRight=$facingRight');

      final candidates = <PositionComponent>[
        ...gameRef.children.whereType<EnemyFish>(),
        ...gameRef.children.whereType<JellyfishEnemy>(),
        ...gameRef.children.whereType<ElectricEelEnemy>(),
        ...gameRef.children.whereType<SwordfishEnemy>(),
        ...gameRef.children.whereType<OrcaEnemy>(),
      ];

      for (final target in candidates) {
        if (!_inPath(target.position)) continue;

        if (target is OrcaEnemy) {
          // L'orca ha una vera barra HP: il fascio la danneggia sul serio,
          // non la uccide sempre in un colpo solo.
          final defeated = target.takeDamage(damage);
          if (defeated) {
            allyConsume(gameRef, target);
          }
          continue;
        }

        // Gli altri nemici non hanno una vera barra HP: qualunque colpo
        // del fascio li abbatte. allyConsume assegna la ricompensa
        // (punti/monete) e mostra il testo fluttuante, oltre a ricaricare
        // le munizioni se il bersaglio è pesce spada/murena/pesce rosso.
        allyConsume(gameRef, target);
      }
    } catch (e, stackTrace) {
      developer.log('Errore in EnergyBeam._applyDamage: $e\n$stackTrace');
    }
  }

  bool _inPath(Vector2 targetPosition) {
    final dx = facingRight ? targetPosition.x - _originX : _originX - targetPosition.x;
    if (dx < 0 || dx > reach) return false;
    return (targetPosition.y - _originY).abs() <= verticalTolerance;
  }
}
