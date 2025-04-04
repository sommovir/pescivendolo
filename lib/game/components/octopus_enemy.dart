import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';

class OctopusEnemy extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  // Il polipetto è sempre pericoloso
  final bool isDangerous = true;
  
  // Velocità maggiore rispetto ai pesci normali
  final double _speed = 180.0; // 80% più veloce dei pesci normali
  
  OctopusEnemy({
    required Vector2 position,
  }) : super(
      size: Vector2(60, 60), // Dimensione del polipetto
      position: position
    ) {
    developer.log('OctopusEnemy: costruttore chiamato');
    anchor = Anchor.center;
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('OctopusEnemy: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica lo sprite del polipetto
      developer.log('OctopusEnemy: caricamento immagine polipetto.png');
      final spriteImage = await gameRef.images.load('polipetto.png');
      sprite = Sprite(spriteImage);
      developer.log('OctopusEnemy: immagine caricata con successo');
      
      // Aggiungi hitbox per il rilevamento delle collisioni
      developer.log('OctopusEnemy: aggiunta hitbox');
      add(RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.8),
        position: Vector2(size.x * 0.1, size.y * 0.1),
      )..collisionType = CollisionType.passive);
      
      developer.log('OctopusEnemy: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in OctopusEnemy.onLoad: $e\n$stackTrace');
    }
    return;
  }
  
  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Muovi il polipetto verso sinistra più velocemente
      position.x -= _speed * dt;
      
      // Mantieni il polipetto sul fondale (parte bassa dello schermo)
      position.y = gameRef.size.y * 0.85; // Posiziona vicino al fondale
      
      // Rimuovi il polipetto se esce dallo schermo
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in OctopusEnemy.update: $e\n$stackTrace');
    }
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      
      // La collisione è gestita nel PlayerFish
    } catch (e, stackTrace) {
      developer.log('Errore in OctopusEnemy.onCollision: $e\n$stackTrace');
    }
  }
}
