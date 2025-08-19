class AvatarHelper {
  // Preset avatar options (20 avatars like Netflix) - using local assets
  static const Map<String, String> avatarAssets = {
    'avatar_1': 'assets/avatars/avatar_1.png',
    'avatar_2': 'assets/avatars/avatar_2.png',
    'avatar_3': 'assets/avatars/avatar_3.png',
    'avatar_4': 'assets/avatars/avatar_4.png',
    'avatar_5': 'assets/avatars/avatar_5.png',
    'avatar_6': 'assets/avatars/avatar_6.png',
    'avatar_7': 'assets/avatars/avatar_7.png',
    'avatar_8': 'assets/avatars/avatar_8.png',
    'avatar_9': 'assets/avatars/avatar_9.png',
    'avatar_10': 'assets/avatars/avatar_10.png',
    'avatar_11': 'assets/avatars/avatar_11.png',
    'avatar_12': 'assets/avatars/avatar_12.png',
    'avatar_13': 'assets/avatars/avatar_13.png',
    'avatar_14': 'assets/avatars/avatar_14.png',
    'avatar_15': 'assets/avatars/avatar_15.png',
    'avatar_16': 'assets/avatars/avatar_16.png',
    'avatar_17': 'assets/avatars/avatar_17.png',
    'avatar_18': 'assets/avatars/avatar_18.png',
    'avatar_19': 'assets/avatars/avatar_19.png',
    'avatar_20': 'assets/avatars/avatar_20.png',
  };

  // Get avatar asset path from avatarId
  static String? getAvatarAsset(String? avatarId) {
    if (avatarId == null) return null;
    return avatarAssets[avatarId];
  }

  // Get all avatar options for selection
  static List<Map<String, String>> getAvatarOptions() {
    return [
      {'id': 'avatar_1', 'name': 'Smiley', 'asset': avatarAssets['avatar_1']!},
      {'id': 'avatar_2', 'name': 'Cool', 'asset': avatarAssets['avatar_2']!},
      {'id': 'avatar_3', 'name': 'Happy', 'asset': avatarAssets['avatar_3']!},
      {'id': 'avatar_4', 'name': 'Wink', 'asset': avatarAssets['avatar_4']!},
      {'id': 'avatar_5', 'name': 'Surprised', 'asset': avatarAssets['avatar_5']!},
      {'id': 'avatar_6', 'name': 'Silly', 'asset': avatarAssets['avatar_6']!},
      {'id': 'avatar_7', 'name': 'Wise', 'asset': avatarAssets['avatar_7']!},
      {'id': 'avatar_8', 'name': 'Friendly', 'asset': avatarAssets['avatar_8']!},
      {'id': 'avatar_9', 'name': 'Cheerful', 'asset': avatarAssets['avatar_9']!},
      {'id': 'avatar_10', 'name': 'Playful', 'asset': avatarAssets['avatar_10']!},
      {'id': 'avatar_11', 'name': 'Calm', 'asset': avatarAssets['avatar_11']!},
      {'id': 'avatar_12', 'name': 'Energetic', 'asset': avatarAssets['avatar_12']!},
      {'id': 'avatar_13', 'name': 'Mysterious', 'asset': avatarAssets['avatar_13']!},
      {'id': 'avatar_14', 'name': 'Adventurous', 'asset': avatarAssets['avatar_14']!},
      {'id': 'avatar_15', 'name': 'Creative', 'asset': avatarAssets['avatar_15']!},
      {'id': 'avatar_16', 'name': 'Bold', 'asset': avatarAssets['avatar_16']!},
      {'id': 'avatar_17', 'name': 'Gentle', 'asset': avatarAssets['avatar_17']!},
      {'id': 'avatar_18', 'name': 'Dynamic', 'asset': avatarAssets['avatar_18']!},
      {'id': 'avatar_19', 'name': 'Charming', 'asset': avatarAssets['avatar_19']!},
      {'id': 'avatar_20', 'name': 'Unique', 'asset': avatarAssets['avatar_20']!},
    ];
  }
} 