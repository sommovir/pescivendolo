import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

enum EelState {
  swimming,    // Stato normale di nuoto
  charging,    // Stato di carica della scarica elettrica
  shocking,    // Stato di scarica elettrica attiva
  cooldown     // Periodo di recupero dopo la scarica
}

class ElectricEelEnemy extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final double speed;
  final double sizeMultiplier;
  final double baseDamageAmount = 25.0;  // Danno normale per contatto
  final double shockDamageAmount = 50.0; // Danno della scarica elettrica (50%)
  
  // Parametri per il comportamento di scarica
  final double shockRadius = 150.0;       // Raggio della scarica elettrica
  final double chargeDuration = 1.5;      // Durata della carica in secondi
  final double shockDuration = 0.6;       // Durata della scarica in secondi (pari alla durata del suono)
  final double cooldownDuration = 5.0;    // Tempo di recupero tra scariche
  
  // Timer per gli stati
  double _stateTimer = 0.0;
  double _randomShockDelay = 0.0;
  
  // Stato corrente
  EelState _currentState = EelState.swimming;
  
  // Componenti per l'effetto visivo della scarica
  late SpriteAnimationComponent _shockAnimation;
  CircleComponent? _shockRadius;
  bool _shockAnimationVisible = false;

  // Random per il comportamento casuale
  final Random _random = Random();
  
  // Getter per il danno da contatto, utilizzato da player_fish.dart nella collisione
  double get damageAmount => baseDamageAmount;
  
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
    
    // Imposta un tempo casuale prima della prima scarica (tra 3 e 7 secondi)
    _randomShockDelay = 3.0 + _random.nextDouble() * 4.0;
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
      
      // Carica la sprite sheet per l'animazione della scarica elettrica
      final shockSpriteSheet = await gameRef.images.load('sprites/electrick_shock.png');
      
      // Crea l'animazione della scarica elettrica
      // Assumiamo che la sprite sheet contenga 4 frame in orizzontale
      final spriteSize = Vector2(shockSpriteSheet.width / 4, shockSpriteSheet.height.toDouble());
      final shockAnimation = SpriteAnimation.fromFrameData(
        shockSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,               // 4 frame nella sprite sheet
          stepTime: 0.1,           // 0.1 secondi per frame
          textureSize: spriteSize,
          loop: true,
        ),
      );
      
      // Crea il componente per l'animazione della scarica
      _shockAnimation = SpriteAnimationComponent(
        animation: shockAnimation,
        size: Vector2(shockRadius * 2, shockRadius * 2),
        anchor: Anchor.center,
      );
      _shockAnimation.position = size / 2;
      _shockAnimation.opacity = 0;  // Inizialmente invisibile
      add(_shockAnimation);
      
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
      
      switch (_currentState) {
        case EelState.swimming:
          _updateSwimming(dt);
          break;
        case EelState.charging:
          _updateCharging(dt);
          break;
        case EelState.shocking:
          _updateShocking(dt);
          break;
        case EelState.cooldown:
          _updateCooldown(dt);
          break;
      }
      
      // Rimuovi se fuori dallo schermo
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ElectricEelEnemy.update: $e\n$stackTrace');
    }
  }
  
  void _updateSwimming(double dt) {
    // Muovi la murena verso sinistra
    position.x -= speed * dt;
    
    // Aggiungi un leggero movimento sinusoidale per simulare il nuoto serpentino
    position.y += sin(gameRef.gameTime * 3 + position.x / 40) * 1.2;
    
    // Conta il tempo fino al cambio di stato (inizio carica)
    _stateTimer += dt;
    if (_stateTimer >= _randomShockDelay) {
      _startCharging();
    }
  }
  
  void _startCharging() {
    _currentState = EelState.charging;
    _stateTimer = 0;
    
    // Aggiungi un effetto di tremore alla murena
    add(
      SequenceEffect([
        MoveByEffect(
          Vector2(2, 0),
          EffectController(duration: 0.05),
        ),
        MoveByEffect(
          Vector2(-4, 0),
          EffectController(duration: 0.05),
        ),
        MoveByEffect(
          Vector2(4, 0),
          EffectController(duration: 0.05),
        ),
        MoveByEffect(
          Vector2(-4, 0),
          EffectController(duration: 0.05),
        ),
        MoveByEffect(
          Vector2(2, 0),
          EffectController(duration: 0.05),
        ),
      ], 
      infinite: true,
      ),
    );
    
    // Mostra un indicatore visivo del raggio
    _shockRadius = CircleComponent(
      radius: shockRadius,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.blueAccent.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    add(_shockRadius!);
    
    // Non riproduciamo un suono di carica separato
  }
  
  void _updateCharging(double dt) {
    // Rallenta durante la carica
    position.x -= speed * dt * 0.3;
    
    _stateTimer += dt;
    if (_stateTimer >= chargeDuration) {
      _triggerShock();
    }
  }
  
  void _triggerShock() {
    _currentState = EelState.shocking;
    _stateTimer = 0;
    
    // Rimuovi l'effetto tremore
    removeWhere((component) => component is SequenceEffect);
    
    // Rimuovi l'indicatore del raggio
    if (_shockRadius != null) {
      _shockRadius!.removeFromParent();
      _shockRadius = null;
    }
    
    // Mostra l'animazione della scarica
    _shockAnimation.opacity = 1.0;
    _shockAnimationVisible = true;
    
    // Riproduci il suono di scarica elettrica
    AudioManager.playSoundEffect('electro_shock.wav', volume: 1.0);
    
    // Applica il danno ai pesci vicini
    _applyShockDamage();
  }
  
  void _updateShocking(double dt) {
    // Durante la scarica, si ferma quasi completamente
    position.x -= speed * dt * 0.1;
    
    _stateTimer += dt;
    if (_stateTimer >= shockDuration) {
      _enterCooldown();
    }
  }
  
  void _enterCooldown() {
    _currentState = EelState.cooldown;
    _stateTimer = 0;
    
    // Nascondi l'animazione della scarica
    _shockAnimation.opacity = 0;
    _shockAnimationVisible = false;
  }
  
  void _updateCooldown(double dt) {
    // Riprende a muoversi normalmente
    position.x -= speed * dt;
    position.y += sin(gameRef.gameTime * 3 + position.x / 40) * 1.2;
    
    _stateTimer += dt;
    if (_stateTimer >= cooldownDuration) {
      // Torna allo stato di nuoto e imposta un nuovo tempo casuale per la prossima scarica
      _currentState = EelState.swimming;
      _stateTimer = 0;
      _randomShockDelay = 3.0 + _random.nextDouble() * 4.0;
    }
  }
  
  void _applyShockDamage() {
    try {
      // Aggiungi un effetto particellare per la scarica
      _addShockParticles();
      
      // Trova tutti i componenti entro il raggio di scarica
      for (var component in gameRef.children) {
        if (component != this && component is PositionComponent) {
          // Calcola la distanza tra la murena e il componente
          final distance = position.distanceTo(component.position);
          
          if (distance <= shockRadius) {
            // Applica danni o effetti in base al tipo di componente
            if (component == gameRef.player) {
              // Danneggia il giocatore del 50%
              gameRef.damagePlayer(shockDamageAmount);
            } else if (component is SpriteComponent && 
                       (component.toString().contains('Enemy') || 
                        component.toString().contains('Fish'))) {
              // "Friggi" altri pesci nell'area
              component.add(OpacityEffect.fadeOut(
                LinearEffectController(0.5),
                onComplete: () => component.removeFromParent(),
              ));
              
              // Se sono pesci buoni, aumenta il punteggio
              if (component.toString().contains('GoodFish')) {
                gameRef.increaseScore(5);
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ElectricEelEnemy._applyShockDamage: $e\n$stackTrace');
    }
  }
  
  void _addShockParticles() {
    final particleComponent = ParticleSystemComponent(
      particle: Particle.generate(
        count: 50,
        lifespan: 1,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, 0),
          speed: Vector2.random(_random) * 100 - Vector2.all(50),
          position: position.clone(),
          child: CircleParticle(
            radius: 2 + _random.nextDouble() * 3,
            paint: Paint()..color = Colors.lightBlueAccent.withOpacity(0.7 + _random.nextDouble() * 0.3),
          ),
        ),
      ),
    );
    
    gameRef.add(particleComponent);
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      
      // Se è il giocatore e non siamo in fase di scarica, applica il danno normale
      if (other == gameRef.player && _currentState != EelState.shocking) {
        gameRef.damagePlayer(baseDamageAmount);
      }
      
    } catch (e, stackTrace) {
      developer.log('Errore in ElectricEelEnemy.onCollision: $e\n$stackTrace');
    }
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Se necessario, puoi aggiungere rendering personalizzato qui
  }
}
