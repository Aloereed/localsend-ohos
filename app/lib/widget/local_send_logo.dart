/*
 * @Author: 
 * @Date: 2025-01-13 10:02:55
 * @LastEditors: Please set LastEditors
 * @LastEditTime: 2025-01-13 10:50:28
 * @Description: file content
 */
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/assets.gen.dart';

class AloeChatAILogo extends StatelessWidget {
  final bool withText;

  const AloeChatAILogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    // final logo = ColorFiltered(
    //   colorFilter: ColorFilter.mode(
    //     Theme.of(context).colorScheme.primary,
    //     BlendMode.srcATop,
    //   ),
    //   child: Assets.img.logo512.image(
    //     width: 200,
    //     height: 200,
    //   ),
    // );
    final logo = Assets.img.logo512.image(
      width: 200,
      height: 200,
    );

    if (withText) {
      return Column(
        children: [
          logo,
          const Text(
            'AloeChat.AI',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return logo;
    }
  }
}
