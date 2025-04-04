import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

class PlayerFish extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  static const double _speed = 200.0;
  
  bool _movingUp = false;
  bool _movingDown = false;
  bool _movingLeft = false;
  bool _movingRight = false;
  
  // Effetto di invulnerabilità temporanea dopo aver subito un danno
  bool _isInvulnerable = false;
  double _invulnerabilityTimer = 0;
  final double _invulnerabilityDuration = 0.5; // Mezzo secondo di invulnerabilità
  
  PlayerFish() : super(size: Vector2(80, 60), position: Vector2(100, 300)) {
    developer.log('PlayerFish: costruttore chiamato');
    anchor = Anchor.center;
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('PlayerFish: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica lo sprite PNG
      developer.log('PlayerFish: caricamento immagine PNG');
      // Utilizziamo un percorso completo per evitare problemi con Flutter Web
      final spriteImage = await gameRef.images.load('pesce_mio.png');
      sprite = Sprite(spriteImage);
      developer.log('PlayerFish: immagine PNG caricata con successo');
      
      // Aggiungi hitbox per il rilevamento delle collisioni
      developer.log('PlayerFish: aggiunta hitbox');
      add(RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.6),
        position: Vector2(size.x * 0.1, size.y * 0.2),
      )..collisionType = CollisionType.active);
      
      developer.log('PlayerFish: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in PlayerFish.onLoad: $e\n$stackTrace');
    }
    return;
  }
  
  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Gestisci il movimento in base ai flag di input
      if (_movingUp) position.y -= _speed * dt;
      if (_movingDown) position.y += _speed * dt;
      if (_movingLeft) position.x -= _speed * dt;
      if (_movingRight) position.x += _speed * dt;
      
      // Mantieni il pesce entro i confini del gioco
      position.clamp(
        Vector2(width / 2, height / 2),
        Vector2(gameRef.size.x - width / 2, gameRef.size.y - height / 2),
      );
      
      // Gestisci l'invulnerabilità temporanea
      if (_isInvulnerable) {
        _invulnerabilityTimer -= dt;
        
        // Effetto di lampeggiamento durante l'invulnerabilità
        opacity = _invulnerabilityTimer * 4 % 1 > 0.5 ? 0.5 : 1.0;
        
        if (_invulnerabilityTimer <= 0) {
          _isInvulnerable = false;
          opacity = 1.0; // Ripristina l'opacità normale
        }
      }
    } catch (e, stackTrace) {
      developer.log('Errore in PlayerFish.update: $e\n$stackTrace');
    }
  }
  
  void moveUp(bool isMoving) {
    _movingUp = isMoving;
  }
  
  void moveDown(bool isMoving) {
    _movingDown = isMoving;
  }
  
  void moveLeft(bool isMoving) {
    _movingLeft = isMoving;
  }
  
  void moveRight(bool isMoving) {
    _movingRight = isMoving;
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      
      // Se il giocatore è invulnerabile, ignora le collisioni
      if (_isInvulnerable) return;
      
      if (other is EnemyFish) {
        if (other.isDangerous) {
          // Il giocatore è stato colpito da un pesce pericoloso
          developer.log('PlayerFish: collisione con pesce pericoloso');
          gameRef.decreaseHealth(other.damageAmount);
          _activateInvulnerability();
          other.removeFromParent();
        } else {
          // Il giocatore ha mangiato un pesce sicuro
          developer.log('PlayerFish: collisione con pesce sicuro');
          gameRef.increaseScore();
          gameRef.increaseHealth(other.healAmount);
          other.removeFromParent();
        }
      } else if (other is OctopusEnemy) {
        // Il polipetto ora è amichevole e cura il giocatore
        developer.log('PlayerFish: collisione con polipetto amichevole');
        gameRef.increaseHealth(other.healAmount);
        other.removeFromParent();
      } else if (other is JellyfishEnemy) {
        // La medusa è pericolosa e toglie il 10% di vita
        developer.log('PlayerFish: collisione con medusa');
        gameRef.decreaseHealth(other.damageAmount);
        _activateInvulnerability();
        other.removeFromParent();
      } else if (other is ElectricEelEnemy) {
        // La murena elettrica è molto pericolosa e toglie il 25% di vita
        developer.log('PlayerFish: collisione con murena elettrica');
        gameRef.decreaseHealth(other.damageAmount);
        _activateInvulnerability();
        other.removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in PlayerFish.onCollision: $e\n$stackTrace');
    }
  }
  
  // Attiva l'invulnerabilità temporanea dopo aver subito un danno
  void _activateInvulnerability() {
    _isInvulnerable = true;
    _invulnerabilityTimer = _invulnerabilityDuration;
  }
}
