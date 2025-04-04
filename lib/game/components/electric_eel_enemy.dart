import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:pescivendolo_game/game/fish_game.dart';

class ElectricEelEnemy extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final double speed;
  final double sizeMultiplier;
  final double damageAmount = 25.0; // Toglie 25% di vita
  
  ElectricEelEnemy({
    required Vector2 position,
    required this.speed,
    required this.sizeMultiplier,
  }) : super(
      // La murena è 6-7 volte più grande di un pesce normale
      size: Vector2(70 * sizeMultiplier / 5, 50 * sizeMultiplier / 5),
      position: position
    ) {
    developer.log('ElectricEelEnemy: costruttore chiamato');
    anchor = Anchor.center;
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('ElectricEelEnemy: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica lo sprite della murena elettrica
      developer.log('ElectricEelEnemy: caricamento immagine murena-elettrica.png');
      final spriteImage = await gameRef.images.load('murena-elettrica.png');
      sprite = Sprite(spriteImage);
      developer.log('ElectricEelEnemy: immagine caricata con successo');
      
      // Aggiungi hitbox per il rilevamento delle collisioni
      developer.log('ElectricEelEnemy: aggiunta hitbox');
      add(RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.7),
        position: Vector2(size.x * 0.1, size.y * 0.15),
      )..collisionType = CollisionType.passive);
      
      developer.log('ElectricEelEnemy: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in ElectricEelEnemy.onLoad: $e\n$stackTrace');
    }
    return;
  }
  
  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Muovi la murena verso sinistra
      position.x -= speed * dt;
      
      // Aggiungi un leggero movimento sinusoidale per simulare il nuoto serpentino
      position.y += sin(gameRef.gameTime * 3 + position.x / 40) * 1.2;
      
      // Rimuovi se fuori dallo schermo
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ElectricEelEnemy.update: $e\n$stackTrace');
    }
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      
      // La collisione è gestita nel PlayerFish
    } catch (e, stackTrace) {
      developer.log('Errore in ElectricEelEnemy.onCollision: $e\n$stackTrace');
    }
  }
}
