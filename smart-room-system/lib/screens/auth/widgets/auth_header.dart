import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Authentication Screen Header With Animation And Background
class AuthHeader extends StatelessWidget {
  final double height;
  final String animationPath;
  final String backgroundImagePath;

  const AuthHeader({Key? key, required this.height, required this.animationPath, required this.backgroundImagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage(backgroundImagePath), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.08), BlendMode.darken)),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.06),
            child: Lottie.asset(
              animationPath,
              fit: BoxFit.contain,
              repeat: true,
              height: height * 0.64, // 64% of header height
            ),
          ),
        ),
      ),
    );
  }
}
