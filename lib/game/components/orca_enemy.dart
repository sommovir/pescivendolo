import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';

/// Nemico "orca": compare solo dopo un po' di tempo di gioco, ha una
/// discreta velocità e insegue leggermente la posizione verticale del
/// giocatore mentre attraversa lo schermo. Il morso toglie molta vita.
///
/// È troppo grossa perché il solo contatto la distrugga: senza lo scudo di
/// invulnerabilità il giocatore non può farle nulla (si comporta come la
/// murena elettrica, resta e continua ad attaccare). Solo speronandola
/// ripetutamente mentre si è invulnerabili la si può abbattere, incassando
/// danno ad ogni speronata finché le sue HP non si esauriscono.
///
/// L'animazione alterna due sprite (bocca aperta / bocca chiusa) per dare
/// l'idea del morso mentre nuota.
class OrcaEnemy extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final double speed;
  final double sizeMultiplier;

  /// Danno per morso: più alto di qualunque altro nemico, l'orca è il
  /// predatore più pericoloso del gioco.
  final double damageAmount = 35.0;

  // --- HP: uccidibile solo speronandola ripetutamente con lo scudo attivo -
  static const double maxHp = 100.0;
  static const double shieldRamDamage = 30.0; // HP perse per ogni speronata a scudo attivo
  double hp = maxHp;
  bool get isDefeated => hp <= 0;

  /// Infligge danno all'orca (solo quando il giocatore la sperona mentre è
  /// invulnerabile per scudo). Ritorna true se questo colpo l'ha abbattuta.
  bool takeDamage(double amount) {
    hp = (hp - amount).clamp(0, maxHp);
    developer.log('OrcaEnemy: colpita per $amount, HP rimaste $hp');
    return isDefeated;
  }

  late Sprite _mouthOpenSprite;
  late Sprite _mouthClosedSprite;
  double _mouthAnimTimer = 0;
  bool _mouthOpen = true;
  static const double _mouthAnimInterval = 0.35;

  /// Quanto velocemente l'orca corregge la propria posizione Y verso il
  /// giocatore, in pixel al secondo. Volutamente basso: deve "andare
  /// leggermente" verso il player, non inseguirlo perfettamente.
  static const double _trackingSpeed = 35.0;

  OrcaEnemy({
    required Vector2 position,
    required this.speed,
    required this.sizeMultiplier,
  }) : super(
          // Sprite sorgente 900x600 (rapporto 3:2): manteniamo lo stesso
          // rapporto scalandolo in base a sizeMultiplier.
          size: Vector2(90 * sizeMultiplier / 5, 60 * sizeMultiplier / 5),
          position: position,
        ) {
    developer.log('OrcaEnemy: costruttore chiamato');
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    developer.log('OrcaEnemy: onLoad iniziato');
    try {
      await super.onLoad();

      final openImage = await gameRef.images.load('orca1.png');
      final closedImage = await gameRef.images.load('orca2.png');
      _mouthOpenSprite = Sprite(openImage);
      _mouthClosedSprite = Sprite(closedImage);
      sprite = _mouthOpenSprite;

      add(RectangleHitbox(
        size: Vector2(size.x * 0.75, size.y * 0.55),
        position: Vector2(size.x * 0.12, size.y * 0.2),
      )..collisionType = CollisionType.passive);

      developer.log('OrcaEnemy: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in OrcaEnemy.onLoad: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);

      // Movimento orizzontale da destra a sinistra
      position.x -= speed * dt;

      // Insegue leggermente la posizione verticale del giocatore
      if (gameRef.player.isMounted) {
        final diff = gameRef.player.position.y - position.y;
        final maxStep = _trackingSpeed * dt;
        position.y += diff.clamp(-maxStep, maxStep);
      }

      // Resta entro i confini verticali dello schermo
      position.y = position.y.clamp(size.y / 2, gameRef.size.y - size.y / 2);

      // Alterna bocca aperta/chiusa
      _mouthAnimTimer += dt;
      if (_mouthAnimTimer >= _mouthAnimInterval) {
        _mouthAnimTimer = 0;
        _mouthOpen = !_mouthOpen;
        sprite = _mouthOpen ? _mouthOpenSprite : _mouthClosedSprite;
      }

      // Rimuovi se fuori dallo schermo
      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in OrcaEnemy.update: $e\n$stackTrace');
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      // La collisione con il giocatore è gestita in PlayerFish.onCollision
    } catch (e, stackTrace) {
      developer.log('Errore in OrcaEnemy.onCollision: $e\n$stackTrace');
    }
  }
}
