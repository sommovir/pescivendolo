import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/ally_manager.dart';
import 'package:pescivendolo_game/game/attack_ability_manager.dart';
import 'package:pescivendolo_game/game/coin_manager.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

/// Matrice di conversione in scala di grigi (luminanza), usata per
/// "ingrigire" le card degli alleati finché non se ne possono permettere
/// l'acquisto.
const _greyscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Riga con il saldo monete e i box per comprare/attivare gli alleati,
/// posizionata vicino alla barra della vita (in alto a sinistra).
class AllyShopRow extends StatefulWidget {
  final FishGame game;

  const AllyShopRow({super.key, required this.game});

  @override
  State<AllyShopRow> createState() => _AllyShopRowState();
}

class _AllyShopRowState extends State<AllyShopRow> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Le monete si accumulano durante la partita (monetine, tesori, ecc.):
    // un refresh periodico tiene il saldo mostrato sempre aggiornato,
    // stesso approccio usato per il cronometro in GameHudOverlay.
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                '${CoinManager.coins}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _AllyShopBox(game: widget.game, type: AllyType.marmoCarpa, onChanged: _refresh),
            const SizedBox(width: 6),
            _AllyShopBox(game: widget.game, type: AllyType.exabiss, onChanged: _refresh),
            const SizedBox(width: 6),
            _AttackAbilityShopBox(onChanged: _refresh),
          ],
        ),
      ],
    );
  }
}

class _AllyShopBox extends StatelessWidget {
  final FishGame game;
  final AllyType type;
  final VoidCallback onChanged;

  static const double _cardSize = 84;

  static const Map<AllyType, String> _cardAssets = {
    AllyType.marmoCarpa: 'assets/images/marmocarpapiccolo.png',
    AllyType.exabiss: 'assets/images/exabisscardpiccolo.png',
  };

  const _AllyShopBox({required this.game, required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final info = AllyManager.allies[type]!;
    final owned = AllyManager.isOwned(type);
    final canAfford = CoinManager.coins >= info.cost;
    final greyedOut = !owned && !canAfford;

    final cardImage = Image.asset(
      _cardAssets[type]!,
      width: _cardSize,
      height: _cardSize,
      fit: BoxFit.cover,
    );

    return GestureDetector(
      onTap: () => _handleTap(context, owned),
      child: Container(
        width: _cardSize,
        height: _cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: owned ? Colors.greenAccent : Colors.white24, width: owned ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              greyedOut
                  ? Opacity(
                      opacity: 0.6,
                      child: ColorFiltered(colorFilter: _greyscaleFilter, child: cardImage),
                    )
                  : cardImage,

              // Fascia inferiore con prezzo o stato "posseduto"
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black.withOpacity(0.7),
                  child: owned
                      ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 11),
                            const SizedBox(width: 2),
                            Text(
                              '${info.cost}',
                              style: TextStyle(
                                color: canAfford ? Colors.amber : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, bool owned) {
    if (owned) return;

    final info = AllyManager.allies[type]!;
    final success = AllyManager.buy(type);
    if (success) {
      game.summonAlly(type);
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complimenti! Hai sbloccato ${info.displayName}!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monete insufficienti'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Card per l'abilità del fascio energetico: a differenza degli alleati,
/// "posseduto" mostra le munizioni rimaste (non un semplice segno di
/// spunta), perché si consumano e l'abilità torna acquistabile quando
/// finiscono.
class _AttackAbilityShopBox extends StatelessWidget {
  final VoidCallback onChanged;

  static const double _cardSize = 84;
  static const String _cardAsset = 'assets/images/Attack1.webp';

  const _AttackAbilityShopBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final owned = AttackAbilityManager.isOwned;
    final canAfford = CoinManager.coins >= AttackAbilityManager.cost;
    final greyedOut = !owned && !canAfford;

    final cardImage = Image.asset(
      _cardAsset,
      width: _cardSize,
      height: _cardSize,
      fit: BoxFit.cover,
    );

    return GestureDetector(
      onTap: () => _handleTap(context, owned),
      child: Container(
        width: _cardSize,
        height: _cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: owned ? Colors.lightBlueAccent : Colors.white24, width: owned ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              greyedOut
                  ? Opacity(
                      opacity: 0.6,
                      child: ColorFiltered(colorFilter: _greyscaleFilter, child: cardImage),
                    )
                  : cardImage,

              // Fascia inferiore con prezzo o munizioni rimaste
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black.withOpacity(0.7),
                  child: owned
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt, color: Colors.lightBlueAccent, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${AttackAbilityManager.ammo}/${AttackAbilityManager.maxAmmo}',
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 11),
                            const SizedBox(width: 2),
                            Text(
                              '${AttackAbilityManager.cost}',
                              style: TextStyle(
                                color: canAfford ? Colors.amber : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, bool owned) {
    if (owned) return;

    final success = AttackAbilityManager.buy();
    if (success) {
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complimenti! Fascio energetico pronto (${AttackAbilityManager.maxAmmo} colpi)!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monete insufficienti'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
