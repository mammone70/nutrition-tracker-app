import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_api_client.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Settings → Calorie Tracker sync against mammone70/calorie-tracker.
class CalorieTrackerSyncScreen extends StatefulWidget {
  const CalorieTrackerSyncScreen({super.key});

  @override
  State<CalorieTrackerSyncScreen> createState() =>
      _CalorieTrackerSyncScreenState();
}

class _CalorieTrackerSyncScreenState extends State<CalorieTrackerSyncScreen> {
  final _log = Logger('CalorieTrackerSyncScreen');
  final _baseUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final CalorieTrackerSyncCredentials _credentials;
  late final SyncService _syncService;
  late final CalorieTrackerApiClient _api;

  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _obscurePassword = true;
  int _pending = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _credentials = locator<CalorieTrackerSyncCredentials>();
    _syncService = locator<SyncService>();
    _api = locator<CalorieTrackerApiClient>();
    _syncService.addListener(_onSyncChanged);
    _load();
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncChanged);
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSyncChanged() {
    if (!mounted) return;
    setState(() {
      _pending = _syncService.pendingCount;
      if (_syncService.lastError != null) {
        _statusMessage = _syncService.lastError;
      }
    });
  }

  Future<void> _load() async {
    final enabled = await _credentials.isEnabled();
    final baseUrl = await _credentials.getBaseUrl();
    final email = await _credentials.getEmail() ?? '';
    final password = await _credentials.getPassword() ?? '';
    await _syncService.refreshPendingCount();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _baseUrlController.text = baseUrl;
      _emailController.text = email;
      _passwordController.text = password;
      _pending = _syncService.pendingCount;
      _loading = false;
    });
  }

  Future<void> _persistFields() async {
    await _credentials.setBaseUrl(_baseUrlController.text);
    await _credentials.setEmail(_emailController.text);
    await _credentials.setPassword(_passwordController.text);
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await _credentials.setEnabled(value);
  }

  Future<void> _saveFields() async {
    setState(() => _busy = true);
    try {
      await _persistFields();
      if (!mounted) return;
      setState(() {
        _statusMessage = S.of(context).calorieTrackerSyncSavedLabel;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probe() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _persistFields();
      final result = await _api.probe();
      if (!mounted) return;
      setState(() {
        _statusMessage = result.ok
            ? S.of(context).calorieTrackerSyncProbeOkLabel
            : S.of(context).calorieTrackerSyncProbeFailLabel(result.message);
      });
    } catch (error, stackTrace) {
      _log.warning('Probe failed', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            S.of(context).calorieTrackerSyncProbeFailLabel(error.toString());
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInAndSync() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _persistFields();
      await _credentials.setEnabled(true);
      setState(() => _enabled = true);
      await _api.login();
      final ok = await _syncService.syncNow();
      if (!mounted) return;
      setState(() {
        _pending = _syncService.pendingCount;
        _statusMessage = ok
            ? S.of(context).calorieTrackerSyncSuccessLabel
            : (_syncService.lastError ??
                S.of(context).calorieTrackerSyncFailedLabel);
      });
    } catch (error, stackTrace) {
      _log.warning('Sign-in/sync failed', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            S.of(context).calorieTrackerSyncProbeFailLabel(error.toString());
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).calorieTrackerSyncTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Dimens.spacing16),
              children: [
                Text(
                  S.of(context).calorieTrackerSyncIntro,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Dimens.spacing20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.of(context).calorieTrackerSyncEnableLabel),
                  subtitle:
                      Text(S.of(context).calorieTrackerSyncEnableSubtitle),
                  value: _enabled,
                  onChanged: _busy ? null : _setEnabled,
                ),
                const SizedBox(height: Dimens.spacing12),
                TextField(
                  controller: _baseUrlController,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: S.of(context).calorieTrackerSyncBaseUrlLabel,
                    hintText: CalorieTrackerSyncCredentials.defaultBaseUrl,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Dimens.spacing12),
                TextField(
                  controller: _emailController,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: S.of(context).calorieTrackerSyncEmailLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Dimens.spacing12),
                TextField(
                  controller: _passwordController,
                  enabled: !_busy,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: S.of(context).calorieTrackerSyncPasswordLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.spacing12),
                Text(
                  S.of(context).calorieTrackerSyncPendingLabel(_pending),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: Dimens.spacing8),
                  Text(
                    _statusMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: Dimens.spacing20),
                Wrap(
                  spacing: Dimens.spacing8,
                  runSpacing: Dimens.spacing8,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _saveFields,
                      child: Text(S.of(context).calorieTrackerSyncSaveLabel),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _probe,
                      child: Text(S.of(context).calorieTrackerSyncTestLabel),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _signInAndSync,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(S.of(context).calorieTrackerSyncNowLabel),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
