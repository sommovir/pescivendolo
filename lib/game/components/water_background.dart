import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'dart:math' as math;

class WaterBackground extends StatelessWidget {
  final Widget child;

  const WaterBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sfondo con gradiente migliorato
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade200,
                Colors.blue.shade400,
                Colors.blue.shade600,
                Colors.blue.shade900,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
        
        // Effetto bolle d'acqua
        Positioned.fill(
          child: BubbleEffect(),
        ),
        
        // Contenuto principale
        child,
      ],
    );
  }
}

class BubbleEffect extends StatelessWidget {
  final int numberOfBubbles;

  BubbleEffect({this.numberOfBubbles = 30});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(
        numberOfBubbles,
        (index) => _Bubble(
          size: math.Random().nextDouble() * 20 + 5,
          position: math.Random().nextDouble(),
          speed: math.Random().nextDouble() * 0.5 + 0.5,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double position;
  final double speed;

  const _Bubble({
    required this.size,
    required this.position,
    required this.speed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Definizione dell'animazione
    final tween = MovieTween()
      ..tween('y', Tween<double>(begin: screenHeight + size, end: -size),
          duration: Duration(seconds: (20 * (1.0 / speed)).round()))
      ..tween('opacity', Tween<double>(begin: 0.0, end: 0.7),
          duration: const Duration(seconds: 2), curve: Curves.easeIn)
      ..tween('opacity', Tween<double>(begin: 0.7, end: 0.0),
          begin: const Duration(seconds: 2), 
          end: Duration(seconds: (20 * (1.0 / speed)).round()), 
          curve: Curves.easeOut);

    return PlayAnimationBuilder<Movie>(
      tween: tween,
      duration: Duration(seconds: (20 * (1.0 / speed)).round()),
      builder: (context, value, child) {
        return Positioned(
          left: screenWidth * position,
          top: value.get('y'),
          child: Opacity(
            opacity: value.get('opacity'),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      onCompleted: () {
        // Ricomincia l'animazione
      },
    );
  }
}
