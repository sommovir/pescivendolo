import 'dart:math';
import 'package:pescivendolo_game/game/coin_manager.dart';

/// Gestisce l'abilità di attacco energetico acquistabile dal giocatore: un
/// fascio che danneggia tutto ciò che ha davanti. Come gli alleati e le
/// monete, è per-partita (si azzera a ogni game over/retry, vedi
/// [resetAll]): 30 colpi al momento dell'acquisto, poi va ricomprata.
class AttackAbilityManager {
  static const int cost = 800;
  static const int maxAmmo = 30;
  static const double beamDamageMin = 50.0;
  static const double beamDamageMax = 100.0;
  static const double cooldownSeconds = 0.5;

  static bool _owned = false;
  static int _ammo = 0;
  static final Random _random = Random();

  static bool get isOwned => _owned;
  static int get ammo => _ammo;

  static double rollDamage() => beamDamageMin + _random.nextDouble() * (beamDamageMax - beamDamageMin);

  static bool buy() {
    if (_owned) return false;
    if (!CoinManager.spendCoins(cost)) return false;
    _owned = true;
    _ammo = maxAmmo;
    return true;
  }

  static int _addAmmo(int amount) {
    if (!_owned || amount <= 0) return 0;
    final before = _ammo;
    _ammo = min(maxAmmo, _ammo + amount);
    return _ammo - before;
  }

  /// Pesce spada ucciso: ricarica completamente le munizioni. Ritorna
  /// quante munizioni sono state effettivamente guadagnate (0 se
  /// l'abilità non è posseduta o le munizioni erano già piene).
  static int onSwordfishKilled() {
    if (!_owned) return 0;
    final before = _ammo;
    _ammo = maxAmmo;
    return _ammo - before;
  }

  /// Murena elettrica uccisa: +10 munizioni.
  static int onEelKilled() => _addAmmo(10);

  /// Pesce rosso (nemico normale) preso: 30% di possibilità di +1 munizione.
  static int onDangerousFishCaught() {
    if (!_owned) return 0;
    if (_random.nextDouble() < 0.3) {
      return _addAmmo(1);
    }
    return 0;
  }

  /// Consuma un colpo se possibile. Ritorna true se si può sparare. Se le
  /// munizioni finiscono, l'abilità "scade": torna acquistabile dal negozio.
  static bool consumeShot() {
    if (!_owned || _ammo <= 0) return false;
    _ammo--;
    if (_ammo <= 0) {
      _owned = false;
    }
    return true;
  }

  static void resetAll() {
    _owned = false;
    _ammo = 0;
  }
}
