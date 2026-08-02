import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';

enum TreasureTier { one, two, three }

/// Tesoro che entra da destra e scorre verso sinistra nella parte bassa
/// dello schermo, come fosse un pesce che avanza, con un leggero movimento
/// di galleggiamento verticale. Contiene un numero casuale di monete, in un
/// intervallo che dipende dal tier (raro = valore più alto).
class TreasurePickup extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final TreasureTier tier;
  late final int coinValue;

  /// True una volta raccolto: evita di assegnare le monete due volte se
  /// Flame registra più collisioni nello stesso frame prima della rimozione.
  bool collected = false;

  late final double _baseY;
  double _bobPhase = 0;
  late final double _bobAmplitude;
  late final double _driftSpeed;

  static const Map<TreasureTier, String> assetNames = {
    TreasureTier.one: 'tesoro1.png',
    TreasureTier.two: 'tesoro2.png',
    TreasureTier.three: 'tesoro3.png',
  };

  static const Map<TreasureTier, (int, int)> coinRanges = {
    TreasureTier.one: (5, 20),
    TreasureTier.two: (15, 50),
    TreasureTier.three: (70, 300),
  };

  TreasurePickup({required Vector2 position, required this.tier})
      : _baseY = position.y,
        super(size: Vector2.all(70), position: position) {
    final random = Random();
    final (min, max) = coinRanges[tier]!;
    coinValue = min + random.nextInt(max - min + 1);
    _bobAmplitude = 6 + random.nextDouble() * 8;
    // "Semi-statico" rispetto alla velocità di un vero nemico, ma comunque
    // visibilmente scorrevole da destra a sinistra.
    _driftSpeed = 35 + random.nextDouble() * 20;
    _bobPhase = random.nextDouble() * pi * 2;

    developer.log('TreasurePickup: costruttore chiamato (tier $tier, $coinValue monete)');
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    try {
      await super.onLoad();
      final image = await gameRef.images.load(assetNames[tier]!);
      sprite = Sprite(image);
      // Raggio di raccolta pari al disegno del tesoro: va toccato
      // realmente dal pesce, non raccolto a distanza.
      add(CircleHitbox(
        radius: size.x * 0.5,
        position: size / 2,
        anchor: Anchor.center,
      )..collisionType = CollisionType.passive);
    } catch (e, stackTrace) {
      developer.log('Errore in TreasurePickup.onLoad: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);

      _bobPhase += dt * 1.5;
      position.x -= _driftSpeed * dt;
      position.y = _baseY + sin(_bobPhase) * _bobAmplitude;

      if (position.x < -size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in TreasurePickup.update: $e\n$stackTrace');
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      // La raccolta è gestita in PlayerFish.onCollision
    } catch (e, stackTrace) {
      developer.log('Errore in TreasurePickup.onCollision: $e\n$stackTrace');
    }
  }
}
