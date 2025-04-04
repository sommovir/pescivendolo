import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

enum SwordfishState {
  peeking,    // Solo il naso visibile, trema
  charging,   // Sfreccia velocemente verso sinistra
  exiting     // Uscita dallo schermo
}

class SwordfishEnemy extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final double speed;
  final double sizeMultiplier;
  final double damageAmount = 35.0;  // Toglie 35% di vita se colpisce
  
  // Parametri specifici per il pesce spada
  final double chargeSpeed;        // Velocità di carica, molto alta
  final double peekingDuration;    // Durata della fase di "sbirciamento", tra 1 e 3 secondi
  
  // Timer e stato
  double _stateTimer = 0.0;
  SwordfishState _currentState = SwordfishState.peeking;
  
  // Random per il comportamento casuale
  final Random _random = Random();
  
  // Fattore di tremolio e posizione iniziale
  double _trembleIntensity = 2.0;
  bool _recentlyCollidedWithPlayer = false;
  bool _fullySpriteVisible = false;
  
  SwordfishEnemy({
    required Vector2 position,
    required this.speed,
    required this.sizeMultiplier,
    required this.chargeSpeed,
    required this.peekingDuration,
  }) : super(
      size: Vector2(120 * sizeMultiplier / 5, 40 * sizeMultiplier / 5),
      position: position
    ) {
    developer.log('SwordfishEnemy: costruttore chiamato');
    anchor = Anchor.centerRight; // Ancorato a destra per mostrare solo il naso inizialmente
  }
  
  @override
  Future<void> onLoad() async {
    developer.log('SwordfishEnemy: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Carica la sprite del pesce spada
      developer.log('SwordfishEnemy: caricamento immagine pesce_spada.png');
      final spriteImage = await gameRef.images.load('pesce_spada.png');
      sprite = Sprite(spriteImage);
      developer.log('SwordfishEnemy: immagine caricata con successo');
      
      // Inizialmente mostra solo il 20% dell'immagine (la spada) sporgente
      // Spostiamo la sprite fuori dallo schermo parzialmente
      position.x = gameRef.size.x - (size.x * 0.2);
      _fullySpriteVisible = false;
      
      // Aggiungi hitbox per il rilevamento delle collisioni
      // Utilizziamo una hitbox più piccola che copre solo la parte frontale (la spada)
      developer.log('SwordfishEnemy: aggiunta hitbox');
      add(RectangleHitbox(
        size: Vector2(size.x * 0.4, size.y * 0.5),
        position: Vector2(0, size.y * 0.25),  // Posizionata nella parte frontale
        collisionType: CollisionType.passive,
      ));
      
      // Aggiungi l'effetto di tremolio durante la fase di "sbirciamento"
      _addTrembleEffect();
      
      developer.log('SwordfishEnemy: onLoad completato con successo');
      return super.onLoad();
    } catch (e, stackTrace) {
      developer.log('ERRORE in SwordfishEnemy.onLoad: $e\n$stackTrace');
      rethrow;
    }
  }
  
  void _addTrembleEffect() {
    // Aggiungi un effetto di tremolio per simulare il pesce che si prepara all'attacco
    final effect = SequenceEffect(
      [
        MoveByEffect(
          Vector2(0, _trembleIntensity),
          EffectController(duration: 0.05),
        ),
        MoveByEffect(
          Vector2(0, -_trembleIntensity * 2),
          EffectController(duration: 0.1),
        ),
        MoveByEffect(
          Vector2(0, _trembleIntensity),
          EffectController(duration: 0.05),
        ),
      ],
      infinite: true,
    );
    
    add(effect);
  }
  
  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      switch (_currentState) {
        case SwordfishState.peeking:
          _updatePeeking(dt);
          break;
        case SwordfishState.charging:
          _updateCharging(dt);
          break;
        case SwordfishState.exiting:
          _updateExiting(dt);
          break;
      }
      
      // Rimuovi se esce completamente dallo schermo a sinistra
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in SwordfishEnemy.update: $e\n$stackTrace');
    }
  }
  
  void _updatePeeking(double dt) {
    // Durante la fase di sbirciamento, il pesce resta fermo ma trema
    _stateTimer += dt;
    
    // Quando il timer supera la durata di peeking, passa alla fase di carica
    if (_stateTimer >= peekingDuration) {
      _transitionToCharging();
    }
  }
  
  void _transitionToCharging() {
    developer.log('SwordfishEnemy: transizione a stato charging');
    _currentState = SwordfishState.charging;
    _stateTimer = 0;
    
    // Smetti il tremolio rimuovendo tutti gli effetti sequenziali
    removeWhere((component) => component is SequenceEffect);
    
    // Ora il pesce è completamente visibile
    _fullySpriteVisible = true;
    position.x = gameRef.size.x - size.x; // Sposta il pesce completamente nello schermo
    
    // Cambia l'ancoraggio per il movimento
    anchor = Anchor.center;
    
    // Riproduce un suono di carica
    AudioManager.playHurtSound(); // Possiamo usare questo suono temporaneamente
  }
  
  void _updateCharging(double dt) {
    // Durante la carica, il pesce si muove molto velocemente verso sinistra
    position.x -= chargeSpeed * dt;
    
    // Se il pesce supera il 75% dello schermo, passa allo stato di uscita
    if (position.x < gameRef.size.x * 0.25) {
      _currentState = SwordfishState.exiting;
    }
  }
  
  void _updateExiting(double dt) {
    // Continua a muoversi verso sinistra, ma a velocità normale
    position.x -= speed * dt;
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      
      // Gestiamo la collisione solo per il giocatore
      if (other == gameRef.player && _currentState == SwordfishState.charging) {
        developer.log('SwordfishEnemy: collisione con il giocatore!');
        // Applica danno solo durante la fase di carica e se non c'è stata una collisione recente
        if (!_recentlyCollidedWithPlayer) {
          gameRef.decreaseHealth(damageAmount);
          _recentlyCollidedWithPlayer = true;
          
          // Imposta un cooldown per evitare danni multipli in rapida successione
          Future.delayed(const Duration(milliseconds: 500), () {
            _recentlyCollidedWithPlayer = false;
          });
        }
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in SwordfishEnemy.onCollision: $e\n$stackTrace');
    }
  }
}
