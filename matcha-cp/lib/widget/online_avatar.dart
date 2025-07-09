import 'package:flutter/material.dart';

class OnlineAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final bool isOnline;
  final Color? backgroundColor;
  final Color? textColor;
  final Color onlineColor;

  const OnlineAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 25.0,
    this.isOnline = false,
    this.backgroundColor,
    this.textColor,
    this.onlineColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main avatar
        CircleAvatar(
          radius: radius,
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          backgroundColor: backgroundColor ?? Colors.grey[300],
          child: imageUrl == null && name != null
              ? Text(
                  name![0].toUpperCase(),
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        
        // Online status indicator
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
} 