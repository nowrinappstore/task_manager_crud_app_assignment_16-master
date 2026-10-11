import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationLabScreen extends StatefulWidget {
  const NotificationLabScreen({super.key});

  @override
  State<NotificationLabScreen> createState() => _NotificationLabScreenState();
}

class _LogEntry {
  final IconData icon;
  final String text;
  final DateTime time;
  const _LogEntry(this.icon, this.text, this.time);
}

class _NotificationLabScreenState extends State<NotificationLabScreen> {
  static const _primary = Colors.indigo;

  final List<_LogEntry> _log = [];
  String? _busyKey;

  Future<void> _run({
    required String key,
    required IconData icon,
    required String logText,
    required String snackText,
    required Future<void> Function() action,
  }) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = key);

    try {
      await action();
      if (!mounted) return;
      setState(() {
        _log.insert(0, _LogEntry(icon, logText, DateTime.now()));
        if (_log.length > 20) _log.removeLast();
      });
      _showSnack(snackText);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : Colors.indigo.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(message),
        ),
      );
  }

  Widget _scheduleCard({
    required String key,
    required int id,
    required IconData icon,
    required Color color,
    required int seconds,
    required String label,
    required String payload,
  }) {
    return _ActionCard(
      icon: icon,
      color: color,
      title: 'Scheduled notification',
      subtitle: 'Fires after a $seconds-second delay',
      buttonLabel: label,
      loading: _busyKey == key,
      enabled: _busyKey == null,
      onPressed: () => _run(
        key: key,
        icon: icon,
        logText: 'Scheduled for $seconds seconds from now',
        snackText: 'Notification scheduled for $seconds seconds!',
        action: () => NotificationService.scheduleIn(
          id: id,
          title: 'Scheduled Notification',
          body: 'Your $seconds-second timer is complete!',
          delay: Duration(seconds: seconds),
          payload: payload,
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: Icons.waving_hand_rounded,
                  color: Colors.orange,
                  title: 'Instant notification',
                  subtitle: 'Send a notification right now',
                  buttonLabel: 'Say Hello',
                  loading: _busyKey == 'hello',
                  enabled: _busyKey == null,
                  onPressed: () => _run(
                    key: 'hello',
                    icon: Icons.waving_hand_rounded,
                    logText: 'Instant notification sent',
                    snackText: 'Notification sent!',
                    action: () => NotificationService.showNotification(
                      id: 1,
                      title: 'Hello!',
                      body: 'Tap me to open a screen',
                      payload: 'hello',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ActionCard(
                  icon: Icons.schedule_rounded,
                  color: Colors.teal,
                  title: 'Scheduled notification',
                  subtitle: 'Fires after a 5-second delay',
                  buttonLabel: 'Schedule in 5s',
                  loading: _busyKey == 'schedule',
                  enabled: _busyKey == null,
                  onPressed: () => _run(
                    key: 'schedule',
                    icon: Icons.schedule_rounded,
                    logText: 'Scheduled for 5 seconds from now',
                    snackText: 'Notification scheduled for 5 seconds!',
                    action: () => NotificationService.scheduleIn(
                      id: 2,
                      title: 'Scheduled Notification',
                      body: 'Your 5-second timer is complete!',
                      delay: const Duration(seconds: 5),
                      payload: 'scheduled_hello',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _scheduleCard(
                  key: 'schedule10',
                  id: 3,
                  icon: Icons.timer_10_rounded,
                  color: Colors.blue,
                  seconds: 10,
                  label: 'Schedule in 10s',
                  payload: 'scheduled_10s',
                ),
                const SizedBox(height: 14),
                _scheduleCard(
                  key: 'schedule30',
                  id: 4,
                  icon: Icons.hourglass_bottom_rounded,
                  color: Colors.purple,
                  seconds: 30,
                  label: 'Schedule in 30s',
                  payload: 'scheduled_30s',
                ),
                const SizedBox(height: 14),
                _scheduleCard(
                  key: 'schedule60',
                  id: 5,
                  icon: Icons.alarm_rounded,
                  color: Colors.pink,
                  seconds: 60,
                  label: 'Schedule in 1 min',
                  payload: 'scheduled_1m',
                ),
                const SizedBox(height: 14),
                _ActionCard(
                  icon: Icons.person_rounded,
                  color: Colors.cyan.shade700,
                  title: 'Notification with payload',
                  subtitle: 'Tap it to open the profile screen',
                  buttonLabel: 'Send',
                  loading: _busyKey == 'profile',
                  enabled: _busyKey == null,
                  onPressed: () => _run(
                    key: 'profile',
                    icon: Icons.person_rounded,
                    logText: 'Profile notification sent',
                    snackText: 'Profile notification sent!',
                    action: () => NotificationService.showNotification(
                      id: 9,
                      title: 'Your Profile',
                      body: 'Tap to open your profile',
                      payload: 'profile',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ActionCard(
                  icon: Icons.layers_rounded,
                  color: Colors.green.shade700,
                  title: 'Multiple notifications',
                  subtitle: 'Send 3 notifications at once',
                  buttonLabel: 'Send 3',
                  loading: _busyKey == 'multi',
                  enabled: _busyKey == null,
                  onPressed: () => _run(
                    key: 'multi',
                    icon: Icons.layers_rounded,
                    logText: '3 notifications sent',
                    snackText: '3 notifications sent!',
                    action: () async {
                      for (var i = 1; i <= 3; i++) {
                        await NotificationService.showNotification(
                          id: 100 + i,
                          title: 'Notification #$i',
                          body: 'This is notification number $i of 3',
                          payload: 'multi_$i',
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _ActionCard(
                  icon: Icons.notifications_off_rounded,
                  color: Colors.red,
                  title: 'Cancel pending',
                  subtitle: 'Clear all scheduled notifications',
                  buttonLabel: 'Cancel All',
                  outlined: true,
                  loading: _busyKey == 'cancel',
                  enabled: _busyKey == null,
                  onPressed: () => _run(
                    key: 'cancel',
                    icon: Icons.notifications_off_rounded,
                    logText: 'All notifications cancelled',
                    snackText: 'All notifications cancelled.',
                    action: NotificationService.cancelAll,
                  ),
                ),
                const SizedBox(height: 28),
                _buildLogHeader(),
                const SizedBox(height: 10),
                _buildLog(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 16,
        24,
        32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade700, Colors.indigo.shade400],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Navigator.of(context).canPop()
                ? IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            )
                : const SizedBox(height: 48),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Notification Lab',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Test local notifications',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogHeader() {
    return Row(
      children: [
        const Icon(Icons.history_rounded, size: 20, color: _primary),
        const SizedBox(width: 8),
        const Text(
          'Activity',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (_log.isNotEmpty)
          TextButton(
            onPressed: () => setState(_log.clear),
            child: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _buildLog() {
    if (_log.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No activity yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _log.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, i) {
          final e = _log[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade50,
              child: Icon(e.icon, size: 16, color: _primary),
            ),
            title: Text(e.text),
            trailing: Text(
              _formatTime(e.time),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool outlined;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: outlined ? color : Colors.white,
      ),
    );

    final child = loading ? spinner : Text(buttonLabel);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            outlined
                ? OutlinedButton(
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            )
                : FilledButton(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
