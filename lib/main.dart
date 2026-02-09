import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/catch_goose_game.dart';
import 'game/catch_goose_3d_game.dart';
import 'game/shared/game_scene_bridge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catch Goose',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB83B2E)),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GameSceneBridge _sceneBridge = GameSceneBridge();
  late final CatchGoose3DGame _game3d;
  late final CatchGooseGame _game2d;

  @override
  void initState() {
    super.initState();
    _game3d = CatchGoose3DGame(sceneBridge: _sceneBridge);
    _game2d = CatchGooseGame(
      sceneBridge: _sceneBridge,
      showBinBackground: false,
      showSlotSprite: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: true,
            child: GameWidget<CatchGoose3DGame>(game: _game3d),
          ),
          GameWidget<CatchGooseGame>(
            game: _game2d,
            overlayBuilderMap: {
              'result': (context, game) => _ResultOverlay(game: game),
            },
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.game});

  final CatchGooseGame game;

  @override
  Widget build(BuildContext context) {
    final title = game.isWin ? '过关成功' : game.resultMessage;

    return ColoredBox(
      color: const Color(0x66000000),
      child: Center(
        child: Container(
          width: 290,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6E6CC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB47334), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7B2D1F),
                ),
              ),
              const SizedBox(height: 16),
              if (game.hasNextLevel && game.isWin)
                FilledButton(
                  onPressed: game.nextLevel,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD53B2D),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('下一关'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: game.restartLevel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B2D1F),
                  side: const BorderSide(color: Color(0xFFB47334), width: 1.6),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(game.isWin ? '重玩本关' : '重新挑战'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
