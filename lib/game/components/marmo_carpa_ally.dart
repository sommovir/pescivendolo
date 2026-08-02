import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/ally_manager.dart';
import 'package:pescivendolo_game/game/ally_rewards.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/boss_component.dart';
import 'package:pescivendolo_game/game/components/coin_pickup.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/player_fish.dart';
import 'package:pescivendolo_game/game/components/sapphire_fish.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';
import 'package:pescivendolo_game/game/components/treasure_pickup.dart';
import 'package:pescivendolo_game/game/components/whale_powerup.dart';

/// Alleato "Marmo Carpa": un pesce corazzato che avanza lentamente davanti
/// al giocatore, "mangiando" letteralmente tutto ciò che gli passa
/// attraverso (nemici, tesori/monetine, PesceZaffiro, polipetto, balena —
/// tutto tranne il giocatore stesso, che può nascondersi dietro di lui) e
/// convertendolo in punti e/o monete a seconda di cosa si tratta. Accumula
/// energia colpendo nemici e, a energia massima, scatena un attacco
/// "terra" che ripulisce lo schermo convertendo tutto in ricompense.
///
/// Usa lo sprite reale MarmoCarpa.webp quando disponibile; in caso di
/// mancato caricamento ricade su un placeholder disegnato via Canvas
/// (vedi [render]).
class MarmoCarpaAlly extends PositionComponent with CollisionCallbacks, HasGameRef<FishGame> {
  // --- Parametri tarabili -----------------------------------------------
  static const double maxHp = 5000.0;
  static const double advanceSpeed = 12.0; // px/s: avanza lentamente
  static const double maxEnergy = 100.0;
  static const double hpLostPerImpact = 15.0; // HP persi ad ogni nemico distrutto
  static const double hpLostAgainstBoss = 40.0; // HP persi colpendo un boss
  static const double bossImpactDamage = 120.0; // danno inflitto a un boss per contatto
  static const double bossUltimateDamage = 400.0; // danno inflitto a un boss dall'attacco terra

  // Dimensione del corpo: doppia rispetto alla versione precedente (192x144).
  static final Vector2 _bodySize = Vector2(384, 288);

  double hp = maxHp;
  double energy = 0.0;

  double _shakeCooldown = 0;
  double _ultimateFlashTimer = 0;

  Sprite? _sprite;

  final Paint _bodyPaint = Paint()..color = const Color(0xFF6B4226);
  final Paint _finPaint = Paint()..color = const Color(0xFF8B5A2B);
  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  MarmoCarpaAlly({required Vector2 position})
      : super(position: position, size: _bodySize, anchor: Anchor.center) {
    developer.log('MarmoCarpaAlly: costruttore chiamato');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Attivo, non passivo: TUTTI i nemici hanno hitbox passive (collidono
    // solo col player, che è l'unico componente attivo). Con Marmo Carpa
    // passivo anche lui, Flame scartava la coppia passivo-passivo e le
    // collisioni non venivano mai rilevate: era il motivo per cui sembrava
    // "non funzionare" e nulla gli sbatteva mai davvero contro.
    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.7),
      position: Vector2(size.x * 0.075, size.y * 0.15),
    )..collisionType = CollisionType.active);

    try {
      final image = await gameRef.images.load('MarmoCarpa.webp');
      _sprite = Sprite(image);
    } catch (e, stackTrace) {
      developer.log('MarmoCarpaAlly: sprite non disponibile, uso il placeholder: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);

      if (hp <= 0) {
        developer.log('MarmoCarpaAlly: distrutto');
        removeFromParent();
        return;
      }

      // Avanza lentamente verso destra, senza limiti: se esce del tutto
      // dallo schermo l'acquisto si considera consumato (vedi sotto).
      position.x += advanceSpeed * dt;
      if (position.x - size.x / 2 > gameRef.size.x) {
        developer.log('MarmoCarpaAlly: uscito dallo schermo, di nuovo acquistabile');
        AllyManager.consumePurchase(AllyType.marmoCarpa);
        removeFromParent();
        return;
      }

      if (_ultimateFlashTimer > 0) {
        _ultimateFlashTimer = max(0, _ultimateFlashTimer - dt);
      }
      if (_shakeCooldown > 0) {
        _shakeCooldown -= dt;
      }
    } catch (e, stackTrace) {
      developer.log('Errore in MarmoCarpaAlly.update: $e\n$stackTrace');
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      _handleImpact(other);
    } catch (e, stackTrace) {
      developer.log('Errore in MarmoCarpaAlly.onCollision: $e\n$stackTrace');
    }
  }

  void _handleImpact(PositionComponent other) {
    // Il giocatore può nascondersi dietro di lui: non viene "mangiato".
    if (other is PlayerFish) return;

    // Suono di "masticazione", una volta per ogni contatto (throttle
    // interno all'AudioManager: evita spam se più cose vengono toccate
    // quasi nello stesso istante).
    AudioManager.playMarmoMagnaSound();

    // Il controllo sul boss va fatto per primo e indipendentemente dal tipo
    // concreto: un futuro nemico boss non erediterà necessariamente da
    // nessuna delle classi nemico esistenti.
    if (other is BossComponent) {
      developer.log('MarmoCarpaAlly: contatto con un boss, danno parziale');
      (other as BossComponent).takeAllySpecialDamage(bossImpactDamage);
      hp -= hpLostAgainstBoss;
      return;
    }

    final wasHostile = isHostileEnemy(other);
    final result = allyConsume(gameRef, other);
    if (!result.consumed) return; // non mangiabile (altri alleati, bolle, ecc.)

    // Solo i nemici veri e propri "pesano" su Marmo Carpa: mangiare
    // tesori/monetine/PesceZaffiro/creature amichevoli non gli costa HP.
    if (wasHostile) {
      hp -= hpLostPerImpact;
    }
    // L'energia sale con qualunque cosa dia punti (nemici, PesceZaffiro,
    // polipetto, balena); le monete pure no, come da progetto originale.
    if (result.points > 0) {
      energy = min(maxEnergy, energy + result.points * 2.5);
    }

    if (energy >= maxEnergy) {
      _triggerEarthAttack();
    }
  }

  /// Attacco terra: pulisce lo schermo da tutto ciò che Marmo Carpa
  /// "mangerebbe" comunque (nemici, tesori/monetine, PesceZaffiro,
  /// polipetto, balena), convertendolo in punti/monete con lo stesso
  /// feedback (testo fluttuante) di un contatto normale, così si vede
  /// bene tutto quello che l'attacco ha appena convertito in ricompense.
  /// I boss subiscono solo danno parziale, mai la distruzione istantanea.
  void _triggerEarthAttack() {
    developer.log('MarmoCarpaAlly: attacco terra! cleanup totale');
    energy = 0;
    _ultimateFlashTimer = 0.4;
    _shakeScreen();
    AudioManager.playMarmoMagnaSound();
    AudioManager.playSoundEffect(AudioManager.electroShockFile, volume: 1.0);
    gameRef.add(_EarthquakeEffect(quakeCenter: position.clone()));

    final candidates = <PositionComponent>[
      ...gameRef.children.whereType<EnemyFish>(),
      ...gameRef.children.whereType<JellyfishEnemy>(),
      ...gameRef.children.whereType<ElectricEelEnemy>(),
      ...gameRef.children.whereType<SwordfishEnemy>(),
      ...gameRef.children.whereType<OrcaEnemy>(),
      ...gameRef.children.whereType<OctopusEnemy>(),
      ...gameRef.children.whereType<WhalePowerup>(),
      ...gameRef.children.whereType<CoinPickup>(),
      ...gameRef.children.whereType<TreasurePickup>(),
      ...gameRef.children.whereType<SapphireFish>(),
    ];
    for (final target in candidates) {
      allyConsume(gameRef, target);
    }

    // I boss (quando esisteranno) subiscono solo danno parziale, mai la
    // distruzione istantanea: qualunque componente implementi
    // BossComponent viene riconosciuto qui a prescindere dal tipo
    // concreto, quindi non serve toccare questo file quando ne aggiungeremo uno.
    for (final component in gameRef.children) {
      if (component is BossComponent) {
        (component as BossComponent).takeAllySpecialDamage(bossUltimateDamage);
      }
    }
  }

  void _shakeScreen() {
    if (_shakeCooldown > 0) return;
    _shakeCooldown = 1.2;
    final random = Random();
    final viewfinder = gameRef.camera.viewfinder;
    viewfinder.add(
      MoveByEffect(
        Vector2(random.nextDouble() * 28 - 14, random.nextDouble() * 28 - 14),
        EffectController(duration: 0.05, alternate: true, repeatCount: 14),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final glow = _ultimateFlashTimer > 0
        ? (Paint()..color = Colors.orangeAccent.withOpacity(0.5 * (_ultimateFlashTimer / 0.4)))
        : null;

    final sprite = _sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size);
      if (glow != null) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), glow);
      }
    } else {
      _renderPlaceholderBody(canvas, glow);
    }

    super.render(canvas);
    _renderBars(canvas);
  }

  /// Corpo di riserva, usato solo se lo sprite non dovesse caricarsi.
  void _renderPlaceholderBody(Canvas canvas, Paint? glow) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.y * 0.15, size.x * 0.85, size.y * 0.7),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    // Coda
    final tailPath = Path()
      ..moveTo(size.x * 0.85, size.y * 0.2)
      ..lineTo(size.x, size.y * 0.02)
      ..lineTo(size.x, size.y * 0.98)
      ..lineTo(size.x * 0.85, size.y * 0.8)
      ..close();
    canvas.drawPath(tailPath, _finPaint);

    // Pinna dorsale
    final finPath = Path()
      ..moveTo(size.x * 0.35, size.y * 0.15)
      ..lineTo(size.x * 0.45, 0)
      ..lineTo(size.x * 0.55, size.y * 0.15)
      ..close();
    canvas.drawPath(finPath, _finPaint);

    // Occhio
    canvas.drawCircle(Offset(size.x * 0.15, size.y * 0.4), size.y * 0.09, _eyePaint);
    canvas.drawCircle(Offset(size.x * 0.15, size.y * 0.4), size.y * 0.045, _pupilPaint);

    if (glow != null) {
      canvas.drawRRect(bodyRect.inflate(6), glow);
    }
  }

  void _renderBars(Canvas canvas) {
    const barWidth = 100.0;
    const barHeight = 6.0;
    final barsY = -18.0;
    final barsX = (size.x - barWidth) / 2;

    // Barra HP
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barsX, barsY, barWidth, barHeight), const Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barsX, barsY, barWidth * (hp / maxHp).clamp(0.0, 1.0), barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.redAccent,
    );

    // Barra energia
    final energyY = barsY - 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barsX, energyY, barWidth, barHeight), const Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barsX, energyY, barWidth * (energy / maxEnergy).clamp(0.0, 1.0), barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.amber,
    );
  }
}

/// Effetto visivo del "terremoto" scatenato dall'attacco terra: un flash
/// ambrato su tutto lo schermo che sfuma rapidamente, più alcuni anelli
/// d'urto concentrici che si espandono da Marmo Carpa. Si rimuove da solo
/// a fine animazione.
class _EarthquakeEffect extends PositionComponent with HasGameRef<FishGame> {
  static const double _duration = 0.9;
  static const double _maxRadius = 750.0;

  final Vector2 quakeCenter;
  double _elapsed = 0;

  _EarthquakeEffect({required this.quakeCenter}) : super(position: Vector2.zero(), priority: 900);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _duration).clamp(0.0, 1.0);

    // Flash ambrato su tutto lo schermo: intenso all'inizio, sfuma in fretta.
    final flashOpacity = (1.0 - t * 3.5).clamp(0.0, 1.0) * 0.35;
    if (flashOpacity > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y),
        Paint()..color = const Color(0xFFB56A2E).withOpacity(flashOpacity),
      );
    }

    // Tre onde d'urto concentriche, sfalsate nel tempo.
    for (int i = 0; i < 3; i++) {
      final ringT = (t - i * 0.12).clamp(0.0, 1.0);
      if (ringT <= 0 || ringT >= 1) continue;
      final radius = ringT * _maxRadius;
      final opacity = (1 - ringT) * 0.55;
      canvas.drawCircle(
        Offset(quakeCenter.x, quakeCenter.y),
        radius,
        Paint()
          ..color = Colors.deepOrangeAccent.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - ringT) + 2,
      );
    }
  }
}
