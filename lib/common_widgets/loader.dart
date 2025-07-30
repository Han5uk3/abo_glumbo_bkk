import 'package:flutter/cupertino.dart';

class Loader extends StatelessWidget {
  final Color? color;
  final double size;
  const Loader({super.key, this.color, this.size = 28.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoActivityIndicator(color: color, radius: size),
    );
  }
}
