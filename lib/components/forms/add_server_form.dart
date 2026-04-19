import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

// form for adding a new server
class AddServerForm extends StatefulWidget {
  final ValueChanged<SubsonicServer> onSuccess;
  final VoidCallback? onCancel;

  const AddServerForm({super.key, required this.onSuccess, this.onCancel});

  @override
  State<AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<AddServerForm> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FTextField(
          label: const Text('Server URL'),
          hint: 'https://...',
          control: FTextFieldControl.managed(controller: _urlController),
          autocorrect: false,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        FTextField(
          label: const Text('Display Name (optional)'),
          hint: 'My Server',
          control: FTextFieldControl.managed(controller: _nameController),
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
              : const Text('Add Server'),
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
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // most people will use this URL
    _urlController.text = 'http://localhost:4533';
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a server URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final provider = context.read<SubsonicProvider>();

    // remove trailing slash if present, since it causes issues with some servers
    final normalizedUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
    final success = await provider.addKnownServer(
      normalizedUrl,
      name: name.isEmpty ? null : name,
    );

    if (!mounted) return;

    if (success) {
      final server = provider.knownServers.firstWhere(
        (s) => s.baseUrl == normalizedUrl,
      );
      widget.onSuccess(server);
    } else {
      setState(() {
        _error = 'Could not connect to server. Check the URL and try again.';
        _isLoading = false;
      });
    }
  }
}
