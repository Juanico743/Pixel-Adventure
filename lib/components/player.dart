import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pixel_adventure/components/chicken.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/custom_hitbox.dart';
import 'package:pixel_adventure/components/saw.dart';
import 'package:pixel_adventure/components/utils.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

import 'angry_pig.dart';
import 'checkpoint.dart';
import 'fruit.dart';

enum PlayerState {idle, running, jumping, falling, hit, appearing, disappearing, doubleJump, wallJump}

class Player extends SpriteAnimationGroupComponent
    with HasGameRef<PixelAdventure>, KeyboardHandler, CollisionCallbacks {

  String character;
  Player({
    position,
    this.character = 'Virtual Guy'
  }) : super(position: position);

  final double stepTime = 0.05;
  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;
  late final SpriteAnimation disappearingAnimation;
  late final SpriteAnimation doubleJumpAnimation;
  late final SpriteAnimation wallJumpAnimation;

  final double _gravity = 9.8;
  final double _jumpForce = 260 ;
  final double _doubleJumpForce = 230;
  final double _terminalVelocity = 300;
  double horizontalMovement = 0;
  double moveSpeed = 100;
  double wallSlideSpeed = 20;
  double wallJumpFixedTime = 0;

  Vector2 startingPosition = Vector2.zero();
  Vector2 velocity = Vector2.zero();
  bool unlockedWallJump = true;
  bool unlockedDoubleJump = true;
  bool isWallSliding = false;
  bool isWallJumping = false;
  bool isInvincible = false;
  bool isOnGround = false;
  bool hasJumped = false;
  bool canJumpInAir = true;
  bool hasDoubleJumped = false;
  bool gotHit = false;
  bool reachedCheckpoint = false;
  List<CollisionBlock> collisionBlocks = [];
  CustomHitbox hitBox = CustomHitbox(
    offsetX: 10,
    offsetY: 4,
    width: 14,
    height: 28,
  );
  double fixedDeltaTime = 1 / 60;
  double accumulatedTime = 0;

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    // debugMode = true;

    startingPosition = Vector2(position.x, position.y);
    add(RectangleHitbox(
      position: Vector2(hitBox.offsetX, hitBox.offsetY),
      size: Vector2(hitBox.width, hitBox.height)
    ));
    return super.onLoad();
  }

  @override
  void update(double dt) {
    accumulatedTime += dt;
    while (accumulatedTime >= fixedDeltaTime) {
      if(!gotHit && !reachedCheckpoint){
        _updatePlayerState();
        _updatePlayerMovement(fixedDeltaTime);
        _checkHorizontalCollisions();
        _applyGravity(fixedDeltaTime);
        _checkVerticalCollisions();
      }
      accumulatedTime -= fixedDeltaTime;
    }


    super.update(dt);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if(!reachedCheckpoint) {
      if(other is Fruit) other.collidedWithPlayer();
      if(other is Saw) _respawn();
      if(other is Chicken) other.collidedWithPlayer();
      if (other is AngryPig) other.collidedWithPlayer();
      if(other is Checkpoint) _reachedCheckpoint();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalMovement = 0;
    final isLeftKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final isRightKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight);

    horizontalMovement += isLeftKeyPressed ? -1 : 0;
    horizontalMovement += isRightKeyPressed ? 1 : 0;

    hasJumped = event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space);

    return super.onKeyEvent(event, keysPressed);
  }

  void _loadAllAnimations() {
    idleAnimation = _spriteAnimation('Idle', 11);
    runningAnimation = _spriteAnimation('Run', 12);
    jumpingAnimation = _spriteAnimation('Jump', 1);
    fallingAnimation = _spriteAnimation('Fall', 1);
    hitAnimation = _spriteAnimation('Hit', 7)..loop = false;
    appearingAnimation = _specialSpriteAnimation('Appearing', 7);
    disappearingAnimation = _specialSpriteAnimation('Disappearing', 7);
    doubleJumpAnimation = _spriteAnimation('Double Jump', 6);
    wallJumpAnimation = _spriteAnimation('Wall Jump', 5);

    // list of all animations
    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      PlayerState.jumping: jumpingAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.hit: hitAnimation,
      PlayerState.appearing: appearingAnimation,
      PlayerState.disappearing: disappearingAnimation,
      PlayerState.doubleJump: doubleJumpAnimation,
      PlayerState.wallJump: wallJumpAnimation,
    };

    // Set current animations
    current = PlayerState.running;
  }

  SpriteAnimation _spriteAnimation(String state, int amount,) {
    return SpriteAnimation.fromFrameData(
        game.images.fromCache('Main Characters/$character/$state (32x32).png'),
        SpriteAnimationData.sequenced(
            amount: amount,
            stepTime: stepTime,
            textureSize: Vector2.all(32)
        )
    );
  }

  SpriteAnimation _specialSpriteAnimation(String state, int amount,) {
    return SpriteAnimation.fromFrameData(
        game.images.fromCache('Main Characters/$state (96x96).png'),
        SpriteAnimationData.sequenced(
          amount: amount,
          stepTime: stepTime,
          textureSize: Vector2.all(96),
          loop: false
         )
    );
  }

  void _updatePlayerState() {
    PlayerState playerState = PlayerState.idle;

    if(velocity.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (velocity.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    if (isOnGround) {
      isWallSliding = false;
      isWallJumping = false;
    }

    if (isWallSliding) {
      current = PlayerState.wallJump;
      return;
    }

    //check if moving , set running
    if (velocity.x != 0) playerState = PlayerState.running;

    // Check if Falling set to falling
    if (velocity.y > _gravity && !isOnGround) {
      playerState = PlayerState.falling;
      isWallJumping = false;
    }

    // Check if Jumping
    if (velocity.y < 0 && !isOnGround) {
      if (isWallJumping) {
        playerState = PlayerState.jumping;
      } else if (hasDoubleJumped) {
        playerState = PlayerState.doubleJump;
      } else {
        playerState = PlayerState.jumping;
      }
    }

    current = playerState;
  }

  void _updatePlayerMovement(double dt) {
    if(hasJumped) {
      if (isOnGround || canJumpInAir){
        // Normal Jump
        _playerJump(dt);
        canJumpInAir = false;
      } else if (isWallSliding) {
        _wallJump(dt);
      } else if (unlockedDoubleJump && !hasDoubleJumped) {
        // Double Jump
        hasDoubleJumped = true;
        velocity.y = -_doubleJumpForce;

        animationTicker?.reset();
        if (game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);
      }
      hasJumped = false;
    }

    // if (velocity.y > _gravity) isOnGround = false;

    if (wallJumpFixedTime > 0) {
      wallJumpFixedTime -= dt;
    } else {
      velocity.x = horizontalMovement * moveSpeed;
    }
    position.x += velocity.x * dt;
  }

  void _playerJump(double dt) {
    if(game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    isOnGround = false;
    hasJumped = false;
  }

  void _wallJump(double dt) {
    if (game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);

    velocity.y = -_jumpForce;
    velocity.x = (scale.x > 0) ? -moveSpeed * 1.5 : moveSpeed * 1.5;

    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    wallJumpFixedTime = 0.15;

    isWallSliding = false;
    isWallJumping = true;
    hasDoubleJumped = false;
    hasJumped = false;
  }

  void _checkHorizontalCollisions() {
    isWallSliding = false;
    for(final block in collisionBlocks) {
      // Handle Collisions
      if(!block.isPlatform){
        if(checkCollision(this, block)) {
          
          if (!isOnGround && unlockedWallJump) {
            _handleWallSliding(block);
          }
          
          if(velocity.x > 0) {
            velocity.x = 0;
            position.x = block.x - hitBox.offsetX - hitBox.width;
            break;
          }
          if(velocity.x < 0) {
            velocity.x = 0;
            position.x = block.x + block.width + hitBox.width + hitBox.offsetX;
            break;
          }
        }
      }
    }
  }

  void _applyGravity(double dt) {
    if (isWallSliding) {
      velocity.y = wallSlideSpeed;
    } else {
      velocity.y += _gravity;
      velocity.y = velocity.y.clamp(-_jumpForce, _terminalVelocity);
    }
    if (velocity.y > 0) isOnGround = false;
    position.y += velocity.y * dt;
  }

  void _checkVerticalCollisions() {
    for (final block in collisionBlocks) {
      if (block.isPlatform) {
        if (velocity.y > 0) {
          final playerHitbox = children.query<RectangleHitbox>().first;
          final hitboxRect = playerHitbox.toAbsoluteRect();

          double playerBottom = hitboxRect.bottom;
          double playerLeft = hitboxRect.left;
          double playerRight = hitboxRect.right;

          if (playerBottom <= block.y + (velocity.y * fixedDeltaTime) + 1 &&
              playerBottom >= block.y - 1) {

            if (playerRight > block.x && playerLeft < block.x + block.width) {
              velocity.y = 0;
              position.y = block.y - hitBox.height - hitBox.offsetY;
              isOnGround = true;
              hasDoubleJumped = false;
              canJumpInAir = true;
              break;
            }
          }
        }
      } else {
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            velocity.y = 0;
            position.y = block.y - hitBox.height - hitBox.offsetY;
            isOnGround = true;
            hasDoubleJumped = false;
            canJumpInAir = true;
            break;
          }
          if (velocity.y < 0) {
            velocity.y = 0;
            position.y = block.y + block.height - hitBox.offsetY;
            break;
          }
        }
      }
    }
  }

  void _respawn() async{
    if(game.playSounds) FlameAudio.play('hit.wav', volume: game.soundVolume);
    const canMoveDuration = Duration(milliseconds: 400);
    gotHit = true;
    current = PlayerState.hit;
    isWallSliding = false;

    await animationTicker?.completed;
    animationTicker?.reset();

    scale.x = 1;
    position = startingPosition - Vector2.all(32);
    current = PlayerState.appearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    velocity = Vector2.zero();
    position = startingPosition;
    _updatePlayerState();
    Future.delayed(canMoveDuration, () => gotHit = false);
  }

  void _reachedCheckpoint() async{
    if(game.playSounds) FlameAudio.play('disappear.wav', volume: game.soundVolume);
    reachedCheckpoint = true;
    if(scale.x > 0){
      position = position - Vector2.all(32);
    } else if (scale.x < 0) {
      position = position + Vector2(32, -32);
    }
    current = PlayerState.disappearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    reachedCheckpoint = false;
    position = Vector2.all(-640);

    const waitToChangeDuration =Duration(milliseconds: 350);
    Future.delayed(waitToChangeDuration, () => game.loadNextLevel());
  }

  void collidedWithEnemy() {
    if (isInvincible) return;
    _respawn();
  }

  void _handleWallSliding(CollisionBlock block) {
    double playerTop = position.y + hitBox.offsetY;
    double playerBottom = position.y + hitBox.offsetY + hitBox.height;

    double blockTop = block.y;
    double blockBottom = block.y + block.height;

    double overlapTop = playerTop > blockTop ? playerTop : blockTop;
    double overlapBottom = playerBottom < blockBottom ? playerBottom : blockBottom;

    double overlapHeight = overlapBottom - overlapTop;

    if (overlapHeight < (hitBox.height * 0.5)) {
      isWallSliding = false;
      return;
    }

    bool onLeftSideOfWall = (position.x + hitBox.offsetX + hitBox.width <= block.x + 5);
    bool onRightSideOfWall = (position.x + hitBox.offsetX >= block.x + block.width - 5);

    if (onLeftSideOfWall) {
      isWallSliding = horizontalMovement >= 0;
    } else if (onRightSideOfWall) {
      isWallSliding = horizontalMovement <= 0;
    }
  }


  
}