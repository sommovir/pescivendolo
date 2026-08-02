import 'package:flame/components.dart';
import 'package:pescivendolo_game/game/attack_ability_manager.dart';
import 'package:pescivendolo_game/game/coin_manager.dart';
import 'package:pescivendolo_game/game/enemy_danger.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/components/coin_pickup.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/floating_score_text.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';
import 'package:pescivendolo_game/game/components/sapphire_fish.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/treasure_pickup.dart';
import 'package:pescivendolo_game/game/components/whale_powerup.dart';

/// Vero per qualunque nemico "ostile" (quelli che infliggono danno al
/// giocatore). Usato dagli alleati per decidere se un contatto va trattato
/// come combattimento (costa HP all'alleato) o come semplice raccolta.
bool isHostileEnemy(Component c) =>
    c is EnemyFish || c is JellyfishEnemy || c is ElectricEelEnemy || c is SwordfishEnemy || c is OrcaEnemy;

/// Monete guadagnate distruggendo un nemico ostile: più è pericoloso, più
/// monete rende, oltre ai punti (sempre assegnati tramite [dangerPoints]).
int allyCoinsFor(Component enemy) {
  if (enemy is OrcaEnemy) return 15;
  if (enemy is SwordfishEnemy) return 8;
  if (enemy is ElectricEelEnemy) return 5;
  if (enemy is JellyfishEnemy) return 3;
  if (enemy is EnemyFish) return enemy.isDangerous ? 2 : 1;
  return 0;
}

/// Esito di un tentativo di "mangiare" qualcosa con [allyConsume]: se
/// [consumed] è false, [other] non era un bersaglio valido (o era già
/// stato consumato da un altro contatto nello stesso frame) e nessuna
/// ricompensa è stata assegnata.
typedef AllyConsumeResult = ({bool consumed, int points, int coins});

const AllyConsumeResult _notConsumed = (consumed: false, points: 0, coins: 0);

/// Prova a far "mangiare" [other] da un alleato (Marmo Carpa, Exabiss):
/// se è un bersaglio valido lo consuma (lo rimuove, assegna punti/monete al
/// giocatore e mostra il testo fluttuante colorato accanto ad esso) e
/// ritorna l'esito con quanto guadagnato. Centralizzato qui perché ogni
/// alleato che "mangia" nemici/tesori/pesci deve trattarli sempre allo
/// stesso identico modo, con le stesse ricompense che vedrebbe il
/// giocatore.
///
/// NON gestisce boss (vanno controllati a parte da chi chiama, con
/// BossComponent.takeAllySpecialDamage) né il giocatore stesso.
AllyConsumeResult allyConsume(FishGame game, PositionComponent other) {
  if (other is CoinPickup) {
    if (other.collected) return _notConsumed;
    other.collected = true;
    _grant(game, other.position, points: 0, coins: other.value);
    other.removeFromParent();
    return (consumed: true, points: 0, coins: other.value);
  }

  if (other is TreasurePickup) {
    if (other.collected) return _notConsumed;
    other.collected = true;
    _grant(game, other.position, points: 0, coins: other.coinValue);
    other.removeFromParent();
    return (consumed: true, points: 0, coins: other.coinValue);
  }

  if (other is SapphireFish) {
    if (other.captured) return _notConsumed;
    other.captured = true;
    _grant(game, other.position, points: other.scorePoints, coins: other.coinsReward);
    other.removeFromParent();
    return (consumed: true, points: other.scorePoints, coins: other.coinsReward);
  }

  if (other is OctopusEnemy) {
    const points = 2, coins = 2;
    _grant(game, other.position, points: points, coins: coins);
    other.removeFromParent();
    return (consumed: true, points: points, coins: coins);
  }

  if (other is WhalePowerup) {
    const points = 6, coins = 10;
    _grant(game, other.position, points: points, coins: coins);
    other.removeFromParent();
    return (consumed: true, points: points, coins: coins);
  }

  if (isHostileEnemy(other)) {
    final points = dangerPoints(other);
    final coins = allyCoinsFor(other);
    final position = other.position;
    _grant(game, position, points: points, coins: coins);
    other.removeFromParent();
    _maybeChargeAttackAbility(game, other, position);
    return (consumed: true, points: points, coins: coins);
  }

  return _notConsumed; // giocatore, altri alleati, bolle, effetti, ecc.
}

/// Se il giocatore possiede l'abilità del fascio energetico, alcuni tipi di
/// nemico ricaricano le sue munizioni quando vengono distrutti (da un
/// alleato o dal fascio stesso): pesce spada = ricarica completa, murena =
/// +10, pesce rosso normale = 30% di +1. Mostra un testo fluttuante
/// azzurro dedicato quando succede davvero, staccato dagli altri testi
/// (punti/monete) per non sovrapporsi.
void _maybeChargeAttackAbility(FishGame game, Component enemy, Vector2 position) {
  int gained = 0;
  if (enemy is SwordfishEnemy) {
    gained = AttackAbilityManager.onSwordfishKilled();
  } else if (enemy is ElectricEelEnemy) {
    gained = AttackAbilityManager.onEelKilled();
  } else if (enemy is EnemyFish && enemy.isDangerous) {
    gained = AttackAbilityManager.onDangerousFishCaught();
  }

  if (gained > 0) {
    game.add(FloatingScoreText(
      position: position.clone()..y += 28,
      text: '⚡+$gained',
      color: FloatingScoreText.ammoColor,
    ));
  }
}

void _grant(FishGame game, Vector2 position, {required int points, required int coins}) {
  if (points > 0) {
    game.increaseScore(points);
    game.add(FloatingScoreText(
      position: position.clone()..x -= (coins > 0 ? 20 : 0),
      text: '+${points}p',
      color: FloatingScoreText.pointsColor,
    ));
  }
  if (coins > 0) {
    CoinManager.addCoins(coins);
    game.add(FloatingScoreText(
      position: position.clone()..x += (points > 0 ? 20 : 0),
      text: '+$coins',
      color: FloatingScoreText.coinColor,
    ));
  }
}
