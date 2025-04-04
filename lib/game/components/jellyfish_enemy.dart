import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:pescivendolo_game/game/fish_game.dart';

class JellyfishEnemy extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final double speed;
  final double sizeMultiplier;
  final double damageAmount = 10.0; // Toglie 10% di vita
  
  JellyfishEnemy({
    required Vector2 position,
    required this.speed,
    required this.sizeMultiplier,
  }) : super(
      // La medusa è 4-7 volte più grande di un pesce normale
      size: Vector2(70 * sizeMultiplier / 5, 50 * sizeMultiplier / 5),
      position: position
    ) {
    developer.log('JellyfishEnemy: costruttore chiamato');
    anchor = Anchor.center;
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('JellyfishEnemy: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica lo sprite della medusa
      developer.log('JellyfishEnemy: caricamento immagine medusa.png');
      final spriteImage = await gameRef.images.load('medusa.png');
      sprite = Sprite(spriteImage);
      developer.log('JellyfishEnemy: immagine caricata con successo');
      
      // Aggiungi hitbox per il rilevamento delle collisioni
      developer.log('JellyfishEnemy: aggiunta hitbox');
      add(RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.8),
        position: Vector2(size.x * 0.1, size.y * 0.1),
      )..collisionType = CollisionType.passive);
      
      developer.log('JellyfishEnemy: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in JellyfishEnemy.onLoad: $e\n$stackTrace');
    }
    return;
  }
  
  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Muovi la medusa verso sinistra (lentamente)
      position.x -= speed * dt;
      
      // Aggiungi un leggero movimento ondulatorio verticale
      position.y += sin(gameRef.gameTime * 2 + position.x / 50) * 0.5;
      
      // Rimuovi se fuori dallo schermo
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in JellyfishEnemy.update: $e\n$stackTrace');
    }
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      
      // La collisione è gestita nel PlayerFish
    } catch (e, stackTrace) {
      developer.log('Errore in JellyfishEnemy.onCollision: $e\n$stackTrace');
    }
  }
}
