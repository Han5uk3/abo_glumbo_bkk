import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Loader extends StatelessWidget {
  final Color? color;
  final double size;
  const Loader({super.key, this.color, this.size = 38.0});

  @override
  Widget build(BuildContext context) {
    return CupertinoActivityIndicator(color: color, radius: size / 2);
  }
}
