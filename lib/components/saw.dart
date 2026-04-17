import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

class Saw extends SpriteAnimationComponent with HasGameRef<PixelAdventure>{
  final bool hasDelay;
  final bool isVertical;
  final double offNeg;
  final double offPos;

  Saw({
    this.hasDelay = false,
    this.isVertical = false,
    this.offNeg = 0,
    this.offPos = 0,
    position,
    size,
  }) : super(
    position: position,
    size: size,
  );

  static const double sawSpeed = 0.03;
  static const moveSpeed = 50;
  static const tileSize = 16;
  double moveDirection = 1;
  double rangeNeg = 0;
  double rangePos = 0;

  // Wait Logic Variables
  bool isWaiting = false;
  double waitTimer = 0;
  final double waitTime = 1; // Seconds to pause at each end

  @override
  FutureOr<void> onLoad() {
    priority = -1;
    debugMode = false;
    add(CircleHitbox());

    if(isVertical) {
      rangeNeg = position.y - offNeg * tileSize;
      rangePos = position.y + offPos * tileSize;
    } else {
      rangeNeg = position.x - offNeg * tileSize;
      rangePos = position.x + offPos * tileSize;
    }

    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Traps/Saw/On (38x38).png'),
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: sawSpeed,
        textureSize: Vector2.all(38),
      ),
    );
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (isWaiting) {
      waitTimer += dt;
      if (waitTimer >= waitTime) {
        isWaiting = false;
        waitTimer = 0;
      }
    } else {
      // Only move if we aren't waiting
      if(isVertical) {
        _moveVertically(dt);
      } else {
        _moveHorizontally(dt);
      }
    }

    // Always call super.update at the very end to keep animation spinning
    super.update(dt);
  }

  void _moveVertically(double dt) {
    if(position.y >= rangePos) {
      moveDirection = -1;
      if (hasDelay) isWaiting = true;
    } else if (position.y <= rangeNeg) {
      moveDirection = 1;
      if (hasDelay) isWaiting = true;
    }
    position.y += moveDirection * moveSpeed * dt;
  }

  void _moveHorizontally(double dt) {
    if(position.x >= rangePos) {
      moveDirection = -1;
      if (hasDelay) isWaiting = true;
    } else if (position.x <= rangeNeg) {
      moveDirection = 1;
      if (hasDelay) isWaiting = true;
    }
    position.x += moveDirection * moveSpeed * dt;
  }
}