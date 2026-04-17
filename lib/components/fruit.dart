import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:pixel_adventure/components/custom_hitbox.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

class Fruit extends SpriteAnimationComponent
    with HasGameRef<PixelAdventure>, CollisionCallbacks{
  final String fruit;
  Fruit({
    this.fruit = 'Apple',
    position,
    size,
  }) : super(
      position: position,
      size: size,
    );

  final double stepTime = 0.05;
  final hitBox = CustomHitbox(
    offsetX: 10,
      offsetY: 10,
      width: 12,
      height: 12
  );
  
  @override
  FutureOr<void> onLoad() {
    debugMode = false;
    priority = -1;

    add(
      RectangleHitbox(
        position: Vector2(hitBox.offsetX, hitBox.offsetY),
        size: Vector2(hitBox.width, hitBox.height),
        collisionType: CollisionType.passive,
      )
    );

    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Items/Fruits/$fruit.png'),
      SpriteAnimationData.sequenced(
        amount: 17,
        stepTime: stepTime,
        textureSize: Vector2.all(32)
      )
    );
    return super.onLoad();
  }

  void collidedWithPlayer() async{
    animation = SpriteAnimation.fromFrameData(
        game.images.fromCache('Items/Fruits/Collected.png'),
        SpriteAnimationData.sequenced(
            amount: 6,
            stepTime: stepTime,
            textureSize: Vector2.all(32),
            loop: false
        )
    );

    await animationTicker?.completed;
    removeFromParent();
  }
}