import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'dart:developer' as developer;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pescivendolo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final FishGame game;
  
  @override
  void initState() {
    super.initState();
    game = FishGame();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // Cattura tutti i tocchi/clic sull'intero schermo
        onTapDown: (_) {
          developer.log('Utente ha interagito con lo schermo');
          AudioManager.setUserInteracted();
        },
        // Assicurati che il GestureDetector copra l'intera area
        behavior: HitTestBehavior.translucent,
        child: GameWidget<FishGame>(
          game: game,
          overlayBuilderMap: {
            'gameOver': (context, game) => GameOverOverlay(game: game),
            'startGame': (context, game) => StartGameOverlay(game: game),
          },
          initialActiveOverlays: const ['startGame'],
        ),
      ),
    );
  }
}

class StartGameOverlay extends StatelessWidget {
  final FishGame game;

  const StartGameOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade300,
            Colors.blue.shade900,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Titolo del gioco
            const Text(
              'PESCIVENDOLO',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black,
                    offset: Offset(5.0, 5.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Sottotitolo
            const Text(
              'L\'avventura sottomarina',
              style: TextStyle(
                fontSize: 24,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 5.0,
                    color: Colors.black,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            
            // Istruzioni
            Container(
              padding: const EdgeInsets.all(20),
              width: 400,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Text(
                    'Istruzioni:',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '• Usa i tasti WASD o le frecce direzionali per muoverti',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '• Mangia i pesci verdi (sicuri) per guadagnare punti',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '• Evita i pesci rossi (pericolosi) e i polipetti',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '• Hai 3 vite, non sprecarle!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            
            // Pulsante START GAME
            ElevatedButton(
              onPressed: () {
                // Imposta il flag di interazione utente
                AudioManager.setUserInteracted();
                
                // Avvia il gioco
                game.startGame();
                game.overlays.remove('startGame');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('START GAME'),
            ),
            
            // Versione
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final FishGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Punteggio: ${game.score}',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Impostiamo il flag di interazione utente
                AudioManager.setUserInteracted();
                
                // Rimuoviamo l'overlay prima di resettare il gioco
                // Questo evita la doppia rimozione che potrebbe causare problemi
                game.overlays.remove('gameOver');
                
                // Resettiamo il gioco dopo un breve ritardo per assicurarci
                // che l'overlay sia stato completamente rimosso
                Future.delayed(const Duration(milliseconds: 100), () {
                  // Reset game
                  game.reset();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('RIPROVA'),
            ),
          ],
        ),
      ),
    );
  }
}
