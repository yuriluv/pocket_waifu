import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/api_config.dart';
import '../models/oauth_account.dart';
import '../providers/settings_provider.dart';
import '../services/oauth_account_service.dart';
import '../utils/ui_feedback.dart';
import 'empty_state_view.dart';

class OAuthAccountsTab extends StatelessWidget {
  const OAuthAccountsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = context.watch<SettingsProvider>();
    final accounts = settingsProvider.oauthAccounts;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Codex / Gemini CLI 계정을 등록하고, API 프리셋에서 계정 기반 OAuth 연결을 사용할 수 있습니다. Gemini CLI는 본인 Google OAuth Desktop client ID/secret이 필요합니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showOAuthAccountLoginDialog(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('OAuth 계정 추가'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.read<SettingsProvider>().reloadOAuthAccounts();
                  if (!context.mounted) return;
                  context.showInfoSnackBar('OAuth 계정 목록을 새로고침했습니다.');
                },
                icon: const Icon(Icons.refresh),
                label: const Text('새로고침'),
              ),
            ],
          ),
        ),
        Expanded(
          child: accounts.isEmpty
              ? const EmptyStateView(
                  icon: Icons.verified_user_outlined,
                  title: '등록된 OAuth 계정이 없습니다',
                  subtitle: 'Codex 또는 Gemini CLI 계정을 먼저 연결하세요',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return _OAuthAccountCard(account: account);
                  },
                ),
        ),
      ],
    );
  }
}

Future<void> showOAuthPresetTemplateDialog(
  BuildContext context, {
  ApiConfig? existingConfig,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _OAuthPresetTemplateDialog(existingConfig: existingConfig),
  );
}

Future<void> showOAuthAccountLoginDialog(
  BuildContext context, {
  OAuthAccount? existingAccount,
}) {
  return _showOAuthAccountLoginDialog(
    context,
    existingAccount: existingAccount,
  );
}

class _OAuthAccountCard extends StatelessWidget {
  const _OAuthAccountCard({required this.account});

  final OAuthAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expiryText = account.expiresAt == null
        ? '만료 정보 없음'
        : account.isExpiringSoon
            ? '곧 만료됨'
            : '유효';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    account.provider.displayName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.displayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (account.email != null && account.email!.isNotEmpty)
              Text(account.email!, style: theme.textTheme.bodyMedium),
            if (account.displayName != null && account.displayName!.isNotEmpty)
              Text(account.displayName!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              '토큰 상태: $expiryText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: account.isExpiringSoon
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (account.cloudProjectId != null && account.cloudProjectId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Google Cloud Project: ${account.cloudProjectId}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showOAuthAccountMetadataDialog(
                    context,
                    account: account,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('이름/메타데이터'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showOAuthAccountLoginDialog(
                    context,
                    existingAccount: account,
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 로그인'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteOAuthAccount(context, account),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('삭제'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDeleteOAuthAccount(
  BuildContext context,
  OAuthAccount account,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('OAuth 계정 삭제'),
      content: Text(
        '"${account.displayLabel}" 계정을 삭제하면 이 계정을 참조하는 프리셋의 OAuth 연결도 해제됩니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  await context.read<SettingsProvider>().removeOAuthAccount(account.id);
  if (!context.mounted) return;
  context.showInfoSnackBar('OAuth 계정을 삭제했습니다.');
}

Future<void> _showOAuthAccountMetadataDialog(
  BuildContext context, {
  required OAuthAccount account,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _OAuthAccountMetadataDialog(account: account),
  );
}

Future<void> _showOAuthAccountLoginDialog(
  BuildContext context, {
  OAuthAccount? existingAccount,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _OAuthAccountLoginDialog(existingAccount: existingAccount),
  );
}

class _OAuthAccountMetadataDialog extends StatefulWidget {
  const _OAuthAccountMetadataDialog({required this.account});

  final OAuthAccount account;

  @override
  State<_OAuthAccountMetadataDialog> createState() => _OAuthAccountMetadataDialogState();
}

class _OAuthAccountMetadataDialogState extends State<_OAuthAccountMetadataDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _projectController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.account.label);
    _projectController = TextEditingController(
      text: widget.account.cloudProjectId ?? '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('OAuth 계정 메타데이터'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: '표시 이름',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.account.provider == OAuthAccountProvider.geminiGca) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _projectController,
                decoration: const InputDecoration(
                  labelText: 'Google Cloud Project (optional)',
                  border: OutlineInputBorder(),
                  helperText: '일부 GCA 계정은 프로젝트 ID가 필요합니다.',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<SettingsProvider>().updateOAuthAccountMetadata(
      accountId: widget.account.id,
      label: _labelController.text.trim(),
      cloudProjectId: widget.account.provider == OAuthAccountProvider.geminiGca
          ? _projectController.text.trim()
          : null,
    );
    if (!mounted) return;
    context.showInfoSnackBar('OAuth 계정 정보를 저장했습니다.');
    Navigator.pop(context);
  }
}

class _OAuthAccountLoginDialog extends StatefulWidget {
  const _OAuthAccountLoginDialog({this.existingAccount});

  final OAuthAccount? existingAccount;

  @override
  State<_OAuthAccountLoginDialog> createState() => _OAuthAccountLoginDialogState();
}

class _OAuthAccountLoginDialogState extends State<_OAuthAccountLoginDialog> {
  late OAuthAccountProvider _provider;
  late final TextEditingController _labelController;
  late final TextEditingController _projectController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  late final TextEditingController _callbackController;

  OAuthAuthorizationSession? _session;
  bool _starting = false;
  bool _completing = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAccount;
    _provider = existing?.provider ?? OAuthAccountProvider.codex;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _projectController = TextEditingController(text: existing?.cloudProjectId ?? '');
    _clientIdController = TextEditingController(
      text: existing?.oauthClientId ?? '',
    );
    _clientSecretController = TextEditingController(
      text: existing?.oauthClientSecret ?? '',
    );
    _callbackController = TextEditingController();
  }

  @override
  void dispose() {
    final session = _session;
    if (session != null) {
      unawaited(session.dispose());
    }
    _labelController.dispose();
    _projectController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _callbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingAccount != null;
    return AlertDialog(
      title: Text(isEdit ? 'OAuth 계정 다시 로그인' : 'OAuth 계정 추가'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<OAuthAccountProvider>(
                initialValue: _provider,
                decoration: const InputDecoration(
                  labelText: '제공자',
                  border: OutlineInputBorder(),
                ),
                items: OAuthAccountProvider.values
                    .map(
                      (provider) => DropdownMenuItem<OAuthAccountProvider>(
                        value: provider,
                        child: Text(provider.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.existingAccount == null
                    ? (value) {
                        if (value != null) {
                          setState(() => _provider = value);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: '표시 이름 (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_provider == OAuthAccountProvider.geminiGca) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _projectController,
                  decoration: const InputDecoration(
                    labelText: 'Google Cloud Project (optional)',
                    border: OutlineInputBorder(),
                    helperText: '일부 GCA 계정은 프로젝트 ID가 필요합니다.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Google OAuth Client ID',
                    border: OutlineInputBorder(),
                    helperText: 'Google Cloud Console -> Desktop app OAuth client ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientSecretController,
                  decoration: const InputDecoration(
                    labelText: 'Google OAuth Client Secret',
                    border: OutlineInputBorder(),
                    helperText: 'Desktop app client secret',
                  ),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _starting ? null : _startLogin,
                    icon: const Icon(Icons.login),
                    label: Text(_session == null ? '로그인 시작' : '브라우저 다시 열기'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _session == null ? null : _copyAuthUrl,
                    icon: const Icon(Icons.copy),
                    label: const Text('URL 복사'),
                  ),
                ],
              ),
              if (_session != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  _session!.authUrl.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _callbackController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Callback URL 또는 Authorization Code',
                    border: const OutlineInputBorder(),
                    helperText: _session!.supportsAutomaticCallback
                        ? '자동 수신이 안 되면 브라우저 주소창의 callback URL 또는 code를 붙여넣으세요.'
                        : '브라우저에서 완료 후 callback URL 또는 code를 붙여넣으세요.',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _completing ? null : _pasteAndComplete,
                  icon: const Icon(Icons.paste),
                  label: const Text('붙여넣기 후 완료'),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_starting || _completing) ? null : () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: (_session == null || _completing) ? null : _completeWithCurrentInput,
          child: _completing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('OAuth 완료'),
        ),
      ],
    );
  }

  Future<void> _startLogin() async {
    setState(() {
      _starting = true;
      _error = null;
      _status = 'OAuth 세션을 준비하는 중...';
    });
    try {
      final previousSession = _session;
      if (previousSession != null) {
        await previousSession.dispose();
      }
      final session = await OAuthAccountService.instance.beginAuthorization(
        provider: _provider,
        clientId: _provider == OAuthAccountProvider.geminiGca
            ? _clientIdController.text.trim()
            : null,
        clientSecret: _provider == OAuthAccountProvider.geminiGca
            ? _clientSecretController.text.trim()
            : null,
      );
      final launched = await OAuthAccountService.instance.openAuthorizationUrl(session);
      if (!mounted) return;
      setState(() {
        _session = session;
        _starting = false;
        _status = launched
            ? '브라우저를 열었습니다. 로그인을 완료하면 자동으로 감지하거나, callback URL을 붙여넣을 수 있습니다.'
            : '브라우저를 자동으로 열지 못했습니다. 위 URL을 복사해서 직접 여세요.';
      });
      unawaited(_waitForAutomaticCallback(session));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _status = null;
      });
    }
  }

  Future<void> _waitForAutomaticCallback(OAuthAuthorizationSession session) async {
    final callback = await session.waitForCallback();
    if (!mounted || _session?.id != session.id || callback == null || callback.isEmpty) {
      return;
    }
    _callbackController.text = callback;
    await _complete(callback);
  }

  Future<void> _copyAuthUrl() async {
    final session = _session;
    if (session == null) return;
    await Clipboard.setData(ClipboardData(text: session.authUrl.toString()));
    if (!mounted) return;
    context.showInfoSnackBar('OAuth URL을 복사했습니다.');
  }

  Future<void> _pasteAndComplete() async {
    final data = await Clipboard.getData('text/plain');
    final pasted = data?.text?.trim() ?? '';
    if (pasted.isNotEmpty) {
      _callbackController.text = pasted;
    }
    await _completeWithCurrentInput();
  }

  Future<void> _completeWithCurrentInput() async {
    await _complete(_callbackController.text.trim());
  }

  Future<void> _complete(String input) async {
    final session = _session;
    if (session == null) {
      return;
    }
    if (input.trim().isEmpty) {
      setState(() {
        _error = 'Callback URL 또는 authorization code를 입력하세요.';
      });
      return;
    }

    setState(() {
      _completing = true;
      _error = null;
      _status = '토큰을 교환하는 중...';
    });

    try {
      final settingsProvider = context.read<SettingsProvider>();
      await OAuthAccountService.instance.completeAuthorization(
        session: session,
        callbackOrCode: input,
        label: _labelController.text.trim(),
        cloudProjectId: _provider == OAuthAccountProvider.geminiGca
            ? _projectController.text.trim()
            : null,
        replaceAccountId: widget.existingAccount?.id,
      );
      await settingsProvider.reloadOAuthAccounts();
      if (!mounted) return;
      context.showInfoSnackBar('OAuth 계정을 저장했습니다.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _status = null;
      });
    }
  }
}

class _OAuthPresetTemplateDialog extends StatefulWidget {
  const _OAuthPresetTemplateDialog({this.existingConfig});

  final ApiConfig? existingConfig;

  @override
  State<_OAuthPresetTemplateDialog> createState() => _OAuthPresetTemplateDialogState();
}

class _OAuthPresetTemplateDialogState extends State<_OAuthPresetTemplateDialog> {
  late OAuthAccountProvider _provider;
  String? _selectedAccountId;
  late final TextEditingController _nameController;
  late final TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingConfig;
    if (existing?.format == ApiFormat.googleCodeAssist) {
      _provider = OAuthAccountProvider.geminiGca;
    } else {
      _provider = OAuthAccountProvider.codex;
    }
    _selectedAccountId = existing?.oauthAccountId;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _modelController = TextEditingController(
      text: existing?.modelName ??
          (_provider == OAuthAccountProvider.codex ? 'gpt-5.3-codex' : 'gemini-2.5-pro'),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final accounts = settingsProvider.oauthAccounts
        .where((account) => account.provider == _provider)
        .toList(growable: false);
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }
    if (_selectedAccountId != null &&
        accounts.every((account) => account.id != _selectedAccountId)) {
      _selectedAccountId = accounts.isEmpty ? null : accounts.first.id;
    }

    return AlertDialog(
      title: Text(widget.existingConfig == null ? 'OAuth 프리셋 추가' : 'OAuth 프리셋 편집'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<OAuthAccountProvider>(
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: 'OAuth 제공자',
                border: OutlineInputBorder(),
              ),
              items: OAuthAccountProvider.values
                  .map(
                    (provider) => DropdownMenuItem<OAuthAccountProvider>(
                      value: provider,
                      child: Text(provider.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _provider = value;
                  _selectedAccountId = null;
                  if (widget.existingConfig == null) {
                    _modelController.text = value == OAuthAccountProvider.codex
                        ? 'gpt-5.3-codex'
                        : 'gemini-2.5-pro';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            if (accounts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_provider.displayName} 계정이 없습니다.'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showOAuthAccountLoginDialog(context),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('OAuth 계정 추가'),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: '연결할 OAuth 계정',
                  border: OutlineInputBorder(),
                ),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.displayLabel),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _selectedAccountId = value),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '프리셋 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: _provider == OAuthAccountProvider.codex ? 'Codex 모델' : 'Gemini 모델',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: accounts.isEmpty ? null : _save,
          child: Text(widget.existingConfig == null ? '추가' : '저장'),
        ),
      ],
    );
  }

  void _save() {
    final accountId = _selectedAccountId;
    if (accountId == null || accountId.isEmpty) {
      context.showErrorSnackBar('OAuth 계정을 선택하세요.');
      return;
    }
    final model = _modelController.text.trim();
    if (model.isEmpty) {
      context.showErrorSnackBar('모델명을 입력하세요.');
      return;
    }
    final settingsProvider = context.read<SettingsProvider>();
    final account = settingsProvider.getOAuthAccountById(accountId);
    if (account == null) {
      context.showErrorSnackBar('선택한 OAuth 계정을 찾을 수 없습니다.');
      return;
    }

    final baseConfig = _provider == OAuthAccountProvider.codex
        ? ApiConfig.codexOAuth(
            oauthAccountId: account.id,
            modelName: model,
            name: _nameController.text.trim().isEmpty
                ? '${account.displayLabel} Codex'
                : _nameController.text.trim(),
          )
        : ApiConfig.geminiCodeAssistOAuth(
            oauthAccountId: account.id,
            modelName: model,
            name: _nameController.text.trim().isEmpty
                ? '${account.displayLabel} Gemini'
                : _nameController.text.trim(),
            cloudProjectId: account.cloudProjectId,
          );

    final config = baseConfig.copyWith(
      id: widget.existingConfig?.id,
      createdAt: widget.existingConfig?.createdAt,
      isDefault: widget.existingConfig?.isDefault ?? false,
    );

    if (widget.existingConfig == null) {
      settingsProvider.addApiConfig(config);
    } else {
      settingsProvider.updateApiConfig(config);
    }
    context.showInfoSnackBar('OAuth 프리셋을 저장했습니다.');
    Navigator.pop(context);
  }
}
