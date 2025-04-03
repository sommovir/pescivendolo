import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';

class EnemyFish extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final bool isDangerous;
  final double _speed = 100.0;
  
  EnemyFish({
    required Vector2 position,
    required this.isDangerous,
  }) : super(
      size: isDangerous 
          ? Vector2(70, 50)  // Dimensione pesce pericoloso
          : Vector2(70, 40), // Dimensione pesce buono (meno alto)
      position: position
    ) {
    developer.log('EnemyFish: costruttore chiamato, pericoloso: $isDangerous');
    anchor = Anchor.center;
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('EnemyFish: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica lo sprite PNG appropriato in base al tipo di pesce
      final imageName = isDangerous ? 'enemy_fish.png' : 'good_fish.png';
      
      developer.log('EnemyFish: caricamento immagine PNG da $imageName');
      // Utilizziamo un percorso completo per evitare problemi con Flutter Web
      final spriteImage = await gameRef.images.load(imageName);
      sprite = Sprite(spriteImage);
      developer.log('EnemyFish: immagine PNG caricata con successo');
      
      // Aggiungi hitbox per il rilevamento delle collisioni
      developer.log('EnemyFish: aggiunta hitbox');
      add(RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.6),
        position: Vector2(size.x * 0.1, size.y * 0.2),
      )..collisionType = CollisionType.passive);
      
      developer.log('EnemyFish: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in EnemyFish.onLoad: $e\n$stackTrace');
    }
    return;
  }
  
  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Muovi da destra a sinistra
      position.x -= _speed * dt;
      
      // Rimuovi se fuori dallo schermo
      if (position.x < -size.x) {
        developer.log('EnemyFish: rimosso perché fuori dallo schermo');
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in EnemyFish.update: $e\n$stackTrace');
    }
  }
}
