import 'package:flutter/material.dart';
import '../theme/tokens.dart';

const List<String> kEmojiList = [
  '😀', '😁', '😂', '🤣', '😃', '😄', '😅', '😆', '😉', '😊',
  '😋', '😎', '😍', '😘', '🥰', '😗', '😙', '😚', '🙂', '🤗',
  '🤩', '🤔', '🤨', '😐', '😑', '😶', '🙄', '😏', '😣', '😥',
  '😮', '🤐', '😯', '😪', '😫', '🥱', '😴', '😌', '😛', '😜',
  '😝', '🤤', '😒', '😓', '😔', '😕', '🙃', '🤑', '😲', '☹️',
  '🙁', '😖', '😞', '😟', '😤', '😢', '😭', '😦', '😧', '😨',
  '😩', '🤯', '😬', '😰', '😱', '🥵', '🥶', '😳', '🤪', '😵',
  '😡', '😠', '🤬', '😷', '🤒', '🤕', '🤢', '🤮', '🥳', '🥴',
  '🥺', '🤠', '🤡', '🤫', '🤭', '🧐', '🤓', '😈', '👿', '👻',
  '💀', '👽', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽',
  '🙀', '😿', '😾', '👍', '👎', '👏', '🙌', '🙏', '🤝', '💪',
  '✌️', '🤞', '🤟', '🤙', '👌', '👋', '🤲', '❤️', '🧡', '💛',
  '💚', '💙', '💜', '🖤', '🤍', '💔', '💕', '💖',
];

typedef EmojiTap = void Function(String emoji);

class EmojiPanel extends StatelessWidget {
  final EmojiTap onPick;

  const EmojiPanel({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: neuBox(d: 6, b: 14, radius: 20),
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: kEmojiList.length,
        itemBuilder: (context, i) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onPick(kEmojiList[i]),
            child: Center(
              child: Text(kEmojiList[i], style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}
