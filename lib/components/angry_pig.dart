import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:pixel_adventure/components/player.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

enum PigState { idle, walk, run, hit1, hit2 }

class AngryPig extends SpriteAnimationGroupComponent
    with HasGameRef<PixelAdventure>, CollisionCallbacks {
  final double offNeg;
  final double offPos;

  AngryPig({
    super.position,
    super.size,
    this.offNeg = 0,
    this.offPos = 0,
  });

  static const stepTime = 0.05;
  static const tileSize = 16;
  static const walkSpeed = 50.0;
  static const runSpeed = 150.0;
  static const bounceHeight = 260.0;
  final textureSize = Vector2(36, 30);

  Vector2 velocity = Vector2.zero();
  double rangeNeg = 0;
  double rangePos = 0;
  double moveDirection = -1;

  bool isAngry = false;
  bool isHurt = false;
  bool isTransitioning = false;
  int health = 2;

  late final Player player;
  late final SpriteAnimation _idleAnimation;
  late final SpriteAnimation _walkAnimation;
  late final SpriteAnimation _runAnimation;
  late final SpriteAnimation _hit1Animation;
  late final SpriteAnimation _hit2Animation;

  @override
  FutureOr<void> onLoad() {
    debugMode = false;
    priority = -1;
    player = game.player;

    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: Vector2(24, 28),
    ));

    _loadAllAnimations();
    _calculateRange();
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (health > 0 && !isTransitioning && !isHurt) {
      _updateState();
      _movement(dt);
    }
    super.update(dt);
  }

  void _loadAllAnimations() {
    _idleAnimation = _spriteAnimation('Idle', 9)..loop = false;
    _walkAnimation = _spriteAnimation('Walk', 16);
    _runAnimation = _spriteAnimation('Run', 12);
    _hit1Animation = _spriteAnimation('Hit 1', 5)..loop = false;
    _hit2Animation = _spriteAnimation('Hit 2', 5)..loop = false;

    animations = {
      PigState.idle: _idleAnimation,
      PigState.walk: _walkAnimation,
      PigState.run: _runAnimation,
      PigState.hit1: _hit1Animation,
      PigState.hit2: _hit2Animation,
    };

    current = PigState.idle;
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Enemies/AngryPig/$state (36x30).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: textureSize,
      ),
    );
  }

  void _calculateRange() {
    rangeNeg = position.x - offNeg * tileSize;
    rangePos = position.x + offPos * tileSize + size.x;
  }

  void _movement(double dt) {
    double speed = isAngry ? runSpeed : walkSpeed;
    velocity.x = moveDirection * speed;

    // Boundary Check
    if (moveDirection > 0 && position.x >= rangePos) {
      position.x = rangePos;
      _turnAround();
    } else if (moveDirection < 0 && position.x <= rangeNeg) {
      position.x = rangeNeg;
      _turnAround();
    }

    position.x += velocity.x * dt;
  }

  void _turnAround() async {
    isTransitioning = true;
    velocity.x = 0;

    moveDirection *= -1;
    flipHorizontallyAroundCenter();

    if (!isAngry) {
      current = PigState.idle;
      animationTicker?.reset();
      await animationTicker?.completed;
    }

    if (health > 0) {
      isTransitioning = false;
    }
  }

  void _updateState() {
    current = isAngry ? PigState.run : PigState.walk;
  }

  void collidedWithPlayer() async {

    if (player.velocity.y > 0 && player.y + player.height > position.y && !player.isWallSliding) {
      if (game.playSounds) FlameAudio.play('bounce.wav', volume: game.soundVolume);
      player.velocity.y = -260;
      health--;
      isHurt = true;
      isTransitioning = false;
      velocity.x = 0;

      player.isInvincible = true;
      Future.delayed(const Duration(milliseconds: 10), () {
        player.isInvincible = false;
      });

      if (health == 1) {
        current = PigState.hit1;
        animationTicker?.reset();
        await animationTicker?.completed;
        isAngry = true;
        isHurt = false;
      } else {
        current = PigState.hit2;
        animationTicker?.reset();
        await animationTicker?.completed;
        removeFromParent();
      }
    } else {
      player.collidedWithEnemy();
    }
  }
}