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
  final double baseDamageAmount = 25.0;  // Danno normale per contatto (25%)
  final double shockDamageAmount = 50.0; // Danno della scarica elettrica (50%)
  
  // Parametri per il comportamento di scarica
  final double shockRadius = 300.0;       // Raggio della scarica elettrica (aumentato a 300)
  final double chargeDuration = 1.5;      // Durata della carica in secondi
  final double shockDuration = 0.8;       // Durata della scarica in secondi (aumentata)
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
  bool _isLandscapeMode = false;

  // Random per il comportamento casuale
  final Random _random = Random();
  
  // Getter per il danno da contatto, utilizzato da player_fish.dart nella collisione
  double get damageAmount => baseDamageAmount;
  
  // Variabile per il controllo delle collisioni ravvicinate
  bool _recentlyCollidedWithPlayer = false;
  
  ElectricEelEnemy({
    required Vector2 position,
    required this.speed,
    required this.sizeMultiplier,
  }) : super(
      // La murena è 6-7 volte più grande di un pesce normale
      size: Vector2(70 * sizeMultiplier / 5, 50 * sizeMultiplier / 5),
      position: position
    ) {
    print("[WARNING] ElectricEelEnemy: costruttore chiamato");
    developer.log('ElectricEelEnemy: costruttore chiamato');
    anchor = Anchor.center;
    
    // Imposta un tempo casuale prima della prima scarica (tra 3 e 7 secondi)
    _randomShockDelay = 3.0 + _random.nextDouble() * 4.0;
    
    developer.log('ElectricEelEnemy: shock delay impostato a $_randomShockDelay secondi');
  }
  
  Future<void> onLoad() async {
    try {
      developer.log('ElectricEelEnemy: onLoad chiamato');
      
      // Carica la sprite per la murena
      final spriteImage = await gameRef.images.load('murena-elettrica.png');
      sprite = Sprite(spriteImage);
      // Carica la sprite sheet per l'animazione della scarica elettrica
      final spritesheet = await gameRef.images.load('electrick_shock.png');
      developer.log('ElectricEelEnemy: dimensioni della spritesheet: ${spritesheet.width}x${spritesheet.height}');
      
      // Crea l'animazione della scarica elettrica
      final spriteSize = Vector2(spritesheet.width / 4, spritesheet.height.toDouble());
      
      final shockAnimation = SpriteAnimation.fromFrameData(
        spritesheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
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
      
      // Calcola la posizione corretta dell'animazione
      _shockAnimation.position = Vector2(size.x / 2, size.y / 2);
      _shockAnimation.opacity = 0;  // Inizialmente invisibile
      add(_shockAnimation);
      
      // Aggiungi hitbox per le collisioni
      add(
        RectangleHitbox(
          size: size,
          position: Vector2.zero(),
          collisionType: CollisionType.passive,
        ),
      );
      
      developer.log('ElectricEelEnemy: onLoad completato con successo');
      return super.onLoad();
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy.onLoad: $e\n$stackTrace');
      rethrow;
    }
  }
  
  void updateOrientation(bool isLandscape) {
    _isLandscapeMode = isLandscape;
    if (gameRef.player.isLoaded) {
      if (gameRef.player.position.x > gameRef.size.x - gameRef.player.size.x) {
        gameRef.player.position.x = gameRef.size.x - gameRef.player.size.x;
      }
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    try {
      // Aggiorna in base allo stato corrente
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
      
      // Rimuovi se esce completamente dallo schermo a sinistra
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy.update: $e\n$stackTrace');
    }
  }
  
  void _updateSwimming(double dt) {
    try {
      // Muovi la murena da destra a sinistra
      position.x -= speed * dt;
      
      // Movimento ondulatorio verticale
      position.y += sin(gameRef.gameTime * 3 + position.x / 40) * 1.2;
      
      // Controlla se è il momento di caricare la scarica elettrica
      _stateTimer += dt;
      if (_stateTimer >= _randomShockDelay) {
        _startCharging();
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._updateSwimming: $e\n$stackTrace');
    }
  }
  
  void _startCharging() {
    try {
      developer.log('ElectricEelEnemy: inizio carica');
      _currentState = EelState.charging;
      _stateTimer = 0;
      
      // Aggiungi un effetto visivo di tremore durante la carica
      add(
        SequenceEffect(
          [
            MoveEffect.by(
              Vector2(2, 0),
              EffectController(duration: 0.05),
            ),
            MoveEffect.by(
              Vector2(-4, 0),
              EffectController(duration: 0.05),
            ),
            MoveEffect.by(
              Vector2(4, 0),
              EffectController(duration: 0.05),
            ),
            MoveEffect.by(
              Vector2(-4, 0),
              EffectController(duration: 0.05),
            ),
            MoveEffect.by(
              Vector2(2, 0),
              EffectController(duration: 0.05),
            ),
          ],
          infinite: true,
        ),
      );
      
      // Mostra il raggio della scarica per effetto visivo
      _shockRadius = CircleComponent(
        radius: shockRadius,
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      add(_shockRadius!);
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._startCharging: $e\n$stackTrace');
    }
  }
  
  void _updateCharging(double dt) {
    try {
      // Rallenta durante la carica
      position.x -= speed * dt * 0.3;
      
      _stateTimer += dt;
      if (_stateTimer >= chargeDuration) {
        _triggerShock();
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._updateCharging: $e\n$stackTrace');
    }
  }
  
  void _triggerShock() {
    try {
      developer.log('ElectricEelEnemy: scossa elettrica attivata!');
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
      developer.log('ElectricEelEnemy: riproduzione audio della scarica');
      AudioManager.playSoundEffect('electro_shock.wav', volume: 2.0);
      
      // Applica il danno ai pesci vicini
      _applyShockDamage();
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._triggerShock: $e\n$stackTrace');
    }
  }
  
  void _updateShocking(double dt) {
    try {
      // Durante la scarica, si ferma quasi completamente
      position.x -= speed * dt * 0.1;
      
      _stateTimer += dt;
      if (_stateTimer >= shockDuration) {
        _enterCooldown();
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._updateShocking: $e\n$stackTrace');
    }
  }
  
  void _enterCooldown() {
    try {
      developer.log('ElectricEelEnemy: entro in cooldown');
      _currentState = EelState.cooldown;
      _stateTimer = 0;
      
      // Nascondi l'animazione della scarica
      _shockAnimation.opacity = 0;
      _shockAnimationVisible = false;
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._enterCooldown: $e\n$stackTrace');
    }
  }
  
  void _updateCooldown(double dt) {
    try {
      // Riprende a muoversi normalmente
      position.x -= speed * dt;
      position.y += sin(gameRef.gameTime * 3 + position.x / 40) * 1.2;
      
      _stateTimer += dt;
      if (_stateTimer >= cooldownDuration) {
        // Torna allo stato di nuoto e imposta un nuovo tempo casuale per la prossima scarica
        _currentState = EelState.swimming;
        _stateTimer = 0;
        _randomShockDelay = 3.0 + _random.nextDouble() * 4.0;
        developer.log('ElectricEelEnemy: torno a nuoto normale, prossima scarica tra $_randomShockDelay secondi');
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._updateCooldown: $e\n$stackTrace');
    }
  }
  
  void _applyShockDamage() {
    try {
      developer.log('ElectricEelEnemy: applico danno shock con raggio $shockRadius');
      
      // Aggiungi un effetto particellare per la scarica
      _addShockParticles();
      
      // Trova tutti i componenti entro il raggio di scarica
      final myPos = position + Vector2(size.x / 2, size.y / 2);
      var playerDamaged = false;
      
      // Verifica esplicitamente se il giocatore è nel raggio
      final distanceToPlayer = myPos.distanceTo(gameRef.player.position);
      developer.log('ElectricEelEnemy: distanza dal giocatore: $distanceToPlayer, raggio: $shockRadius');
      
      if (distanceToPlayer <= shockRadius) {
        developer.log('ElectricEelEnemy: GIOCATORE NEL RAGGIO! Applico danno: $shockDamageAmount');
        gameRef.damagePlayer(shockDamageAmount);
        playerDamaged = true;
      }
      
      // Controlla tutti gli altri componenti
      for (var component in gameRef.children) {
        if (component != this && component != gameRef.player && component is PositionComponent) {
          // Calcola la distanza tra la murena e il componente
          final distance = myPos.distanceTo(component.position);
          
          if (distance <= shockRadius) {
            developer.log('ElectricEelEnemy: componente nel raggio: ${component.toString()}');
            
            // Danneggia o uccidi altri pesci
            component.removeFromParent();
            
            // Incrementa il punteggio se uccidi un pesce nemico
            if (component.toString().contains('Enemy')) {
              gameRef.increaseScore(5);
            }
          }
        }
      }
      
      developer.log('ElectricEelEnemy: applicazione danno shock completata. Giocatore danneggiato: $playerDamaged');
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._applyShockDamage: $e\n$stackTrace');
    }
  }
  
  void _addShockParticles() {
    try {
      final center = Vector2(size.x / 2, size.y / 2);
      final particleComponent = ParticleSystemComponent(
        particle: Particle.generate(
          count: 20,
          lifespan: 0.5,
          generator: (i) => AcceleratedParticle(
            acceleration: getRandomVector() * 20,
            speed: getRandomVector() * 100,
            position: center.clone(),
            child: CircleParticle(
              radius: 2.0 + _random.nextDouble() * 2,
              paint: Paint()..color = Colors.lightBlueAccent,
            ),
          ),
        ),
      );
      
      add(particleComponent);
      
      // Rimuovi le particelle dopo un certo tempo
      Future.delayed(const Duration(milliseconds: 800), () {
        if (isMounted && particleComponent.isMounted) {
          particleComponent.removeFromParent();
        }
      });
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy._addShockParticles: $e\n$stackTrace');
    }
  }
  
  Vector2 getRandomVector() {
    return Vector2(
      _random.nextDouble() * 2 - 1, 
      _random.nextDouble() * 2 - 1,
    );
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    try {
      // Gestiamo la collisione solo per il giocatore
      if (other == gameRef.player) {
        developer.log('ElectricEelEnemy: collisione con il giocatore!');
        // Damage on contact (25%)
        if (!_recentlyCollidedWithPlayer) {
          gameRef.damagePlayer(baseDamageAmount);
          _recentlyCollidedWithPlayer = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            _recentlyCollidedWithPlayer = false;
          });
        }
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ElectricEelEnemy.onCollision: $e\n$stackTrace');
    }
  }
}
