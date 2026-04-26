import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

// form for adding or editing a user account
class AddUserForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;
  final Future<SubsonicServer?> Function()? onAddServerPressed;
  // if initial, then we are editing
  final SubsonicAccount? initialAccount;

  const AddUserForm({
    super.key,
    required this.onSuccess,
    this.onCancel,
    this.onAddServerPressed,
    this.initialAccount,
  });

  @override
  State<AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends State<AddUserForm>
    with TickerProviderStateMixin {
  SubsonicServer? _selectedServer;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  late final FPopoverController _serverPopoverCtrl;

  bool get _isEditing => widget.initialAccount != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final provider = context.watch<SubsonicProvider>();

    final serverContainer = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isEditing
              ? colors.border.withValues(alpha: 0.5)
              : colors.border,
        ),
        borderRadius: BorderRadius.circular(12),
        color: _isEditing ? colors.muted : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server',
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedServer?.name ?? 'Select a server',
                  style: context.theme.typography.sm.copyWith(
                    color: _selectedServer != null
                        ? colors.foreground
                        : colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (!_isEditing)
            Icon(FIcons.chevronDown, size: 18, color: colors.mutedForeground),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isEditing)
          serverContainer
        else if (isMobile(context))
          GestureDetector(
            onTap: () => _openServerPicker(context, provider),
            child: serverContainer,
          )
        else
          FPopover(
            control: FPopoverControl.managed(controller: _serverPopoverCtrl),
            childAnchor: Alignment.bottomLeft,
            popoverAnchor: Alignment.topLeft,
            popoverBuilder: (ctx, ctrl) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.knownServers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No servers added yet.',
                          style: context.theme.typography.sm.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      )
                    else
                      ...provider.knownServers.map(
                        (server) => ListTile(
                          title: Text(
                            server.name,
                            style: context.theme.typography.sm.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                          subtitle: server.name != server.baseUrl
                              ? Text(
                                  server.baseUrl,
                                  style: context.theme.typography.xs.copyWith(
                                    color: colors.mutedForeground,
                                  ),
                                )
                              : null,
                          onTap: () {
                            setState(() => _selectedServer = server);
                            ctrl.hide();
                          },
                        ),
                      ),
                    if (widget.onAddServerPressed != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: FButton(
                          variant: FButtonVariant.outline,
                          onPress: () async {
                            ctrl.hide();
                            final server = await widget.onAddServerPressed!();
                            if (mounted && server != null) {
                              setState(() => _selectedServer = server);
                            }
                          },
                          child: const Text('+ Add New Server'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            child: GestureDetector(
              onTap: () => _serverPopoverCtrl.toggle(),
              child: serverContainer,
            ),
          ),
        const SizedBox(height: 16),
        FTextField(
          label: const Text('Username'),
          hint: 'username',
          control: FTextFieldControl.managed(controller: _usernameCtrl),
          autocorrect: false,
        ),
        const SizedBox(height: 16),
        FTextField.password(
          label: Text(_isEditing ? 'New Password' : 'Password'),
          control: FTextFieldControl.managed(controller: _passwordCtrl),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Text(
            _error!,
            style: context.theme.typography.sm.copyWith(color: colors.error),
          ),
          const SizedBox(height: 12),
        ],
        FButton(
          onPress: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save Changes' : 'Add Account'),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 8),
          FButton(
            variant: FButtonVariant.outline,
            onPress: widget.onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _serverPopoverCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _serverPopoverCtrl = FPopoverController(vsync: this);
    if (_isEditing) {
      _usernameCtrl.text = widget.initialAccount!.username;
      _passwordCtrl.text = widget.initialAccount!.password;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<SubsonicProvider>();
        final server = provider.knownServers.firstWhere(
          (s) => s.baseUrl == widget.initialAccount!.baseUrl,
          orElse: () => SubsonicServer(
            baseUrl: widget.initialAccount!.baseUrl,
            name: widget.initialAccount!.baseUrl,
          ),
        );
        setState(() => _selectedServer = server);
      });
    }
  }

  void _openServerPicker(BuildContext context, SubsonicProvider provider) {
    showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.5,
      builder: (sheetCtx) => _ServerPickerSheet(
        knownServers: List.unmodifiable(provider.knownServers),
        onSelected: (server) {
          setState(() => _selectedServer = server);
          Navigator.pop(sheetCtx);
        },
        onAddNew: widget.onAddServerPressed == null
            ? null
            : () {
                Navigator.pop(sheetCtx);
                widget.onAddServerPressed!().then((server) {
                  if (mounted && server != null) {
                    setState(() => _selectedServer = server);
                  }
                });
              },
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedServer == null) {
      setState(() => _error = 'Please select a server.');
      return;
    }
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }

    final password = _passwordCtrl.text;
    // in edit mode, if password is empty, keep existing password
    final effectivePassword = (_isEditing && password.isEmpty)
        ? widget.initialAccount!.password
        : password;

    if (effectivePassword.isEmpty) {
      setState(() => _error = 'Please enter a password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<SubsonicProvider>();
    String? error;

    if (_isEditing) {
      error = await provider.updateAccount(
        oldId: widget.initialAccount!.id,
        baseUrl: _selectedServer!.baseUrl,
        username: username,
        password: effectivePassword,
      );
    } else {
      error = await provider.addAccount(
        baseUrl: _selectedServer!.baseUrl,
        username: username,
        password: effectivePassword,
      );
    }

    if (!mounted) return;

    if (error == null) {
      widget.onSuccess();
    } else {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }
}

class _ServerPickerSheet extends StatelessWidget {
  final List<SubsonicServer> knownServers;
  final ValueChanged<SubsonicServer> onSelected;
  final VoidCallback? onAddNew;

  const _ServerPickerSheet({
    required this.knownServers,
    required this.onSelected,
    this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Material(
      color: const Color(0xFF101012),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Select Server',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ),
            if (knownServers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No servers added yet.',
                  style: context.theme.typography.sm.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: knownServers.length,
                  itemBuilder: (ctx, i) {
                    final server = knownServers[i];
                    return ListTile(
                      title: Text(
                        server.name,
                        style: context.theme.typography.sm.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                      subtitle: server.name != server.baseUrl
                          ? Text(
                              server.baseUrl,
                              style: context.theme.typography.xs.copyWith(
                                color: colors.mutedForeground,
                              ),
                            )
                          : null,
                      onTap: () => onSelected(server),
                    );
                  },
                ),
              ),
            if (onAddNew != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FButton(
                  variant: FButtonVariant.outline,
                  onPress: onAddNew,
                  child: const Text('+ Add New Server'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
