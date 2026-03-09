abstract class AvatarUtils {
  static const Map<String, String> avatarLabels = {
    'avatar_fox': 'Fox',
    'avatar_bunny': 'Bunny',
    'avatar_bear': 'Bear',
    'avatar_owl': 'Owl',
    'avatar_cat': 'Cat',
    'avatar_dog': 'Dog',
    'avatar_panda': 'Panda',
    'avatar_penguin': 'Penguin',
    'avatar_lion': 'Lion',
    'avatar_elephant': 'Elephant',
    'avatar_giraffe': 'Giraffe',
    'avatar_dolphin': 'Dolphin',
  };

  static List<String> get allSeeds => avatarLabels.keys.toList(growable: false);

  static String getLabel(String seed) => avatarLabels[seed] ?? 'Avatar';
}
