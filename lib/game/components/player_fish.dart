import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/coin_pickup.dart';
import 'package:pescivendolo_game/game/components/floating_score_text.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';
import 'package:pescivendolo_game/game/components/sapphire_fish.dart';
import 'package:pescivendolo_game/game/components/treasure_pickup.dart';
import 'package:pescivendolo_game/game/attack_ability_manager.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/coin_manager.dart';
import 'package:pescivendolo_game/game/enemy_danger.dart';
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
  
  // Immunità temporanea alla guarigione per evitare doppie cure
  bool _isHealingImmune = false;
  double _healingImmuneTimer = 0;
  final double _healingImmuneDuration = 0.3; // 0.3 secondi di immunità alla cura

  // Direzione verso cui il pesce è rivolto (usata dal fascio energetico per
  // sparare "davanti a lui"): resta quella dell'ultimo movimento
  // orizzontale, non cambia muovendosi solo in verticale.
  bool _facingRight = true;
  bool get facingRight => _facingRight;


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

      // Capovolge visivamente lo sprite quando cambia direzione: prima non
      // c'era alcun segnale visibile su dove fosse rivolto il pesce, e il
      // fascio energetico (che spara "davanti a lui" in base a questa
      // direzione) sembrava non colpire mai nulla perché sparava dal lato
      // sbagliato senza che si potesse notare.
      if (_movingLeft && !_movingRight) {
        if (_facingRight) flipHorizontallyAroundCenter();
        _facingRight = false;
      } else if (_movingRight && !_movingLeft) {
        if (!_facingRight) flipHorizontallyAroundCenter();
        _facingRight = true;
      }
      
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
      
      // Gestisci il timer di immunità alla guarigione
      if (_isHealingImmune) {
        _healingImmuneTimer -= dt;
        if (_healingImmuneTimer <= 0) {
          _isHealingImmune = false;
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
          _awardShieldKillPoints(other);
          _activateInvulnerability();
          _chargeAttackAbility(other.position, AttackAbilityManager.onDangerousFishCaught());
          other.removeFromParent();
        } else {
          // Il giocatore ha mangiato un pesce sicuro
          // Ignora se siamo immuni alla guarigione
          if (!_isHealingImmune) {
            developer.log('PlayerFish: collisione con pesce sicuro');
            gameRef.increaseScore();
            gameRef.increaseHealth(other.healAmount);
            // Offset laterale (e verticale) ben marcato in direzioni
            // opposte: altrimenti punti e cura comparirebbero sovrapposti
            // sullo stesso punto ed sarebbero illeggibili.
            _showPointsText(other.position, 1, offsetX: -34, offsetY: -8);
            _showHealText(other.position, other.healAmount, offsetX: 34, offsetY: 8);
            _activateHealingImmunity();
            other.removeFromParent();
          }
        }
      } else if (other is OctopusEnemy) {
        // Il polipetto ora è amichevole e cura il giocatore
        // Ignora se siamo immuni alla guarigione
        if (!_isHealingImmune) {
          developer.log('PlayerFish: collisione con polipetto amichevole');
          gameRef.increaseHealth(other.healAmount);
          _showHealText(other.position, other.healAmount);
          _activateHealingImmunity();
          other.removeFromParent();
        }
      } else if (other is JellyfishEnemy) {
        // La medusa è pericolosa e toglie il 10% di vita
        developer.log('PlayerFish: collisione con medusa');
        gameRef.decreaseHealth(other.damageAmount);
        _awardShieldKillPoints(other);
        _activateInvulnerability();
        other.removeFromParent();
      } else if (other is ElectricEelEnemy) {
        if (gameRef.isPlayerInvulnerable) {
          // Con lo scudo attivo il contatto la uccide davvero (unico modo:
          // senza scudo è una minaccia persistente che non muore mai).
          developer.log('PlayerFish: murena elettrica uccisa con lo scudo');
          _awardShieldKillPoints(other);
          _chargeAttackAbility(other.position, AttackAbilityManager.onEelKilled());
          other.removeFromParent();
        } else {
          // La murena elettrica è molto pericolosa e toglie parecchia vita
          developer.log('PlayerFish: collisione con murena elettrica');
          gameRef.decreaseHealth(other.damageAmount);
          _activateInvulnerability();
          // Senza scudo non viene rimossa: resta per continuare a usare i
          // suoi attacchi elettrici.
        }
      } else if (other is OrcaEnemy) {
        if (gameRef.isPlayerInvulnerable) {
          // Con lo scudo attivo il giocatore può speronarla: ogni contatto
          // le toglie HP, ma serve speronarla più volte per abbatterla.
          // Senza scudo è troppo grossa: il giocatore non può farle nulla.
          developer.log('PlayerFish: speronata orca con lo scudo');
          final defeated = other.takeDamage(OrcaEnemy.shieldRamDamage);
          if (defeated) {
            developer.log('PlayerFish: orca abbattuta!');
            _awardShieldKillPoints(other);
            other.removeFromParent();
          }
        } else {
          // L'orca è il nemico più pericoloso: un morso toglie molta vita.
          // Troppo grossa per essere distrutta da un semplice contatto:
          // resta e può continuare a mordere dopo la finestra di invulnerabilità.
          developer.log('PlayerFish: collisione con orca');
          gameRef.decreaseHealth(other.damageAmount);
          _activateInvulnerability();
        }
      } else if (other is SapphireFish) {
        // Pesce raro: molti più punti del normale e 50 monete
        if (!other.captured) {
          developer.log('PlayerFish: catturato PesceZaffiro!');
          other.captured = true;
          gameRef.increaseScore(other.scorePoints);
          CoinManager.addCoins(other.coinsReward);
          // Offset laterale (e verticale) ben marcato in direzioni opposte:
          // altrimenti monete e punti comparirebbero sovrapposti sullo
          // stesso punto ed sarebbero illeggibili.
          gameRef.add(FloatingScoreText(
            position: other.position.clone()
              ..x -= 34
              ..y -= 8,
            text: '+${other.coinsReward}',
          ));
          _showPointsText(other.position, other.scorePoints, offsetX: 34, offsetY: 8);
          other.removeFromParent();
        }
      } else if (other is CoinPickup) {
        if (!other.collected) {
          other.collected = true;
          developer.log('PlayerFish: monetina raccolta (+${other.value})');
          CoinManager.addCoins(other.value);
          AudioManager.playCoinSound();
          gameRef.add(FloatingScoreText(position: other.position.clone(), text: '+${other.value}'));
          other.removeFromParent();
        }
      } else if (other is TreasurePickup) {
        if (!other.collected) {
          other.collected = true;
          developer.log('PlayerFish: tesoro raccolto (+${other.coinValue})');
          CoinManager.addCoins(other.coinValue);
          if (other.tier == TreasureTier.three) {
            AudioManager.playBigTreasureSound();
          } else {
            AudioManager.playCoinSound();
          }
          gameRef.add(FloatingScoreText(position: other.position.clone(), text: '+${other.coinValue}'));
          other.removeFromParent();
        }
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
  
  // Attiva l'immunità temporanea alla guarigione per evitare cure multiple
  void _activateHealingImmunity() {
    _isHealingImmune = true;
    _healingImmuneTimer = _healingImmuneDuration;
  }

  // Assegna punti quando un nemico pericoloso viene ucciso mentre lo scudo
  // di invulnerabilità è attivo (altrimenti il danno viene solo ignorato,
  // senza alcuna ricompensa per il giocatore).
  void _awardShieldKillPoints(PositionComponent enemy) {
    if (gameRef.isPlayerInvulnerable) {
      final points = dangerPoints(enemy);
      developer.log('PlayerFish: nemico ucciso con lo scudo, +$points punti');
      gameRef.increaseScore(points);
      _showPointsText(enemy.position, points);
    }
  }

  // Testo blu "+Np" quando si guadagnano punti. [offsetX]/[offsetY]
  // spostano il testo, usato quando compare insieme ad un altro testo
  // fluttuante nello stesso punto (es. monete+punti, punti+cura) per
  // evitare che si sovrappongano.
  void _showPointsText(Vector2 position, int points, {double offsetX = 0, double offsetY = 0}) {
    gameRef.add(FloatingScoreText(
      position: position.clone()
        ..x += offsetX
        ..y += offsetY,
      text: '+${points}p',
      color: FloatingScoreText.pointsColor,
    ));
  }

  // Testo verde "+Nhp" quando si recupera vita. Vedi [_showPointsText] per
  // il significato di [offsetX]/[offsetY].
  void _showHealText(Vector2 position, double amount, {double offsetX = 0, double offsetY = 0}) {
    final formatted = amount < 1 ? amount.toStringAsFixed(1) : amount.round().toString();
    gameRef.add(FloatingScoreText(
      position: position.clone()
        ..x += offsetX
        ..y += offsetY,
      text: '+${formatted}hp',
      color: FloatingScoreText.healColor,
    ));
  }

  // Testo azzurro "⚡+N" quando un nemico ricarica le munizioni del fascio
  // energetico (vedi AttackAbilityManager). [gained] è già il risultato
  // della chiamata all'hook: se 0 (abilità non posseduta, munizioni già
  // piene, o tiro a vuoto sul 30%) non mostra nulla. Spostato sotto la
  // posizione base per non sovrapporsi a punti/cura mostrati insieme.
  void _chargeAttackAbility(Vector2 position, int gained) {
    if (gained <= 0) return;
    gameRef.add(FloatingScoreText(
      position: position.clone()..y += 28,
      text: '⚡+$gained',
      color: FloatingScoreText.ammoColor,
    ));
  }
}
