import 'package:flutter/material.dart';
import '../utils/avatar_helper.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarId;
  final double size;
  final VoidCallback? onTap;

  const AvatarWidget({
    this.avatarId,
    this.size = 48,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarAsset = AvatarHelper.getAvatarAsset(avatarId);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          color: Colors.grey[800],
        ),
        child: avatarAsset != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: Image.asset(
                  avatarAsset,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.6,
                color: Colors.white70,
              ),
      ),
    );
  }
} 