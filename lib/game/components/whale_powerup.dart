import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

enum WhaleState {
  swimming,    // Stato normale di nuoto
  healing,     // Sta curando il giocatore (quando il giocatore è sopra/vicino)
}

class WhalePowerup extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final double speed;
  final double sizeMultiplier;
  
  // Parametri per la cura e invulnerabilità
  final double healRate = 5.0;       // 5% al secondo
  final double detectionRadius = 100.0; // Raggio di rilevamento del giocatore
  
  // Timer e stato
  double _healTimer = 0.0;
  WhaleState _currentState = WhaleState.swimming;
  bool _playerInRange = false;
  bool _isHealing = false;     // Flag per tenere traccia dello stato di cura
  bool _isColliding = false;   // Flag per tracciare la collisione attiva con il giocatore
  
  // Random per il comportamento casuale
  final Random _random = Random();
  
  // Effetto visivo per quando il giocatore è in cura
  ParticleSystemComponent? _healParticles;
  
  WhalePowerup({
    required Vector2 position,
    required this.speed,
    required this.sizeMultiplier,
  }) : super(
      size: Vector2(200 * sizeMultiplier / 5, 80 * sizeMultiplier / 5),
      position: position
    ) {
    developer.log('WhalePowerup: costruttore chiamato');
    anchor = Anchor.center;
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('WhalePowerup: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica la sprite della balena
      developer.log('WhalePowerup: caricamento immagine balena.png');
      final spriteImage = await gameRef.images.load('balena.png');
      sprite = Sprite(spriteImage);
      developer.log('WhalePowerup: immagine caricata con successo');
      
      // Aggiungi effetto di movimento ondulatorio
      add(
        SequenceEffect(
          [
            MoveByEffect(
              Vector2(0, 5),
              EffectController(duration: 1.0, curve: Curves.easeInOut),
            ),
            MoveByEffect(
              Vector2(0, -10),
              EffectController(duration: 2.0, curve: Curves.easeInOut),
            ),
            MoveByEffect(
              Vector2(0, 5),
              EffectController(duration: 1.0, curve: Curves.easeInOut),
            ),
          ],
          infinite: true,
        ),
      );
      
      // Aggiungi hitbox per la collisione diretta - usiamo un rettangolo che copre
      // la maggior parte della balena, ma non tutto, per rendere la collisione più naturale
      add(
        RectangleHitbox(
          size: Vector2(size.x * 0.8, size.y * 0.7),
          position: Vector2(size.x * 0.1, size.y * 0.15),
          collisionType: CollisionType.passive,
        ),
      );
      
      // Flip orizzontale per far nuotare la balena da sinistra a destra
      flipHorizontally();
      
      developer.log('WhalePowerup: onLoad completato con successo');
      return super.onLoad();
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup.onLoad: $e\n$stackTrace');
      rethrow;
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    try {
      // La balena si muove da sinistra a destra (opposto agli altri nemici)
      position.x += speed * dt;
      
      // Aggiorna in base allo stato corrente
      switch (_currentState) {
        case WhaleState.swimming:
          _updateSwimming(dt);
          break;
        case WhaleState.healing:
          _updateHealing(dt);
          break;
      }
      
      // Rimuovi se esce completamente dallo schermo a destra
      if (position.x > gameRef.size.x + size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup.update: $e\n$stackTrace');
    }
  }
  
  void _checkPlayerInRange() {
    // Non usiamo più questa funzione, la collisione avviene solo con la hitbox
  }
  
  void _startHealing() {
    try {
      if (_currentState == WhaleState.healing) return; // Già in stato di cura
      
      developer.log('WhalePowerup: inizio cura');
      _currentState = WhaleState.healing;
      _isHealing = true;
      
      // Ripristina il timer di cura per cominciare subito
      _healTimer = 0.1;
      
      // Riproduci un suono di cura
      AudioManager.playEatSound(); // Per ora usiamo questo, poi potremmo creare un suono specifico
      
      // Aggiungi effetto di particelle di cura
      _addHealParticles();
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup._startHealing: $e\n$stackTrace');
    }
  }
  
  void _stopHealing() {
    try {
      if (_currentState != WhaleState.healing) return; // Non siamo in stato di cura
      
      developer.log('WhalePowerup: fine cura');
      _currentState = WhaleState.swimming;
      _isHealing = false;
      
      // Rimuovi l'effetto di particelle se presente
      if (_healParticles != null && _healParticles!.isMounted) {
        _healParticles!.removeFromParent();
        _healParticles = null;
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup._stopHealing: $e\n$stackTrace');
    }
  }
  
  void _updateSwimming(double dt) {
    // Nulla di speciale durante il nuoto normale
  }
  
  void _updateHealing(double dt) {
    try {
      // Verifica che siamo ancora in collisione e in stato di cura
      if (!_isColliding || !_isHealing) {
        _stopHealing();
        return;
      }
      
      // Incrementa il timer di cura
      _healTimer += dt;
      
      // Cura 5% al secondo
      if (_healTimer >= 0.1) { // Aggiorna ogni 0.1 secondi per una cura più fluida
        _healTimer = 0;
        
        // Se la vita è al 100%, attiva l'invulnerabilità
        if (gameRef.health >= 100.0) {
          if (!gameRef.isPlayerInvulnerable) {
            // Attiva l'invulnerabilità
            gameRef.activateInvulnerability();
          }
        } else {
          // Altrimenti cura il giocatore
          gameRef.increaseHealth(healRate * 0.1);
          
          // Aggiorna le particelle periodicamente per un effetto visivo continuo
          if (_random.nextDouble() < 0.2) { // 20% di probabilità ogni 0.1 secondi
            _addHealParticles();
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup._updateHealing: $e\n$stackTrace');
    }
  }
  
  void _addHealParticles() {
    try {
      if (_healParticles != null && _healParticles!.isMounted) {
        _healParticles!.removeFromParent();
      }
      
      _healParticles = ParticleSystemComponent(
        particle: Particle.generate(
          count: 20,
          lifespan: 1.0,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, -20),
            speed: Vector2(_random.nextDouble() * 40 - 20, _random.nextDouble() * -50 - 10),
            position: Vector2(size.x / 2, size.y / 2),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final color = Color.lerp(
                  Colors.lightGreen,
                  Colors.white,
                  particle.progress,
                )!.withOpacity(1 - particle.progress);
                
                canvas.drawCircle(
                  Offset.zero,
                  3 + _random.nextDouble() * 2 * (1 - particle.progress),
                  Paint()..color = color,
                );
              },
            ),
          ),
        ),
        position: Vector2(0, 0),
      );
      
      add(_healParticles!);
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup._addHealParticles: $e\n$stackTrace');
    }
  }
  
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    
    try {
      // Se collide direttamente con il giocatore, avvia la cura
      if (other == gameRef.player) {
        _isColliding = true;
        if (_currentState == WhaleState.swimming) {
          _startHealing();
        }
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup.onCollisionStart: $e\n$stackTrace');
    }
  }
  
  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    
    try {
      // Quando il giocatore esce dalla collisione, interrompi la cura
      if (other == gameRef.player) {
        _isColliding = false;
        if (_currentState == WhaleState.healing) {
          _stopHealing();
        }
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in WhalePowerup.onCollisionEnd: $e\n$stackTrace');
    }
  }
}
