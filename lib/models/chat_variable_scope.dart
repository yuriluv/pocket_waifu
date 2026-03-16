enum ChatVariableScope { mainChat, menu, newChat }

extension ChatVariableScopeX on ChatVariableScope {
  String get storageKey {
    return switch (this) {
      ChatVariableScope.mainChat => 'mainChat',
      ChatVariableScope.menu => 'menu',
      ChatVariableScope.newChat => 'newChat',
    };
  }

  String get label {
    return switch (this) {
      ChatVariableScope.mainChat => 'Main Chat',
      ChatVariableScope.menu => 'Menu',
      ChatVariableScope.newChat => 'New Chat',
    };
  }

  static ChatVariableScope fromStorageKey(String raw) {
    return switch (raw) {
      'menu' => ChatVariableScope.menu,
      'newChat' => ChatVariableScope.newChat,
      _ => ChatVariableScope.mainChat,
    };
  }
}
