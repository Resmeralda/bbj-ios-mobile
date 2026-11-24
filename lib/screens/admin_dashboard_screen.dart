import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/review_store.dart';
import '../data/role_store.dart';
import '../models/technique.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';
import 'review_forms.dart';

const _adminColor = Color(0xFF588564);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.store});

  final ReviewStore store;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final _store = widget.store;
  late final ReviewAccess _access;
  late final _tabsController = TabController(length: 3, vsync: this);
  late final _applications = _DashboardQuery(
    _store.watchApplications,
    _queryChanged,
  );
  late final _trainerRoles = _DashboardQuery(
    _store.watchTrainerRoles,
    _queryChanged,
  );
  late final _submissions = _DashboardQuery(
    _store.watchModeration,
    _queryChanged,
  );
  late final _techniques = _DashboardQuery(
    _store.watchTechniques,
    _queryChanged,
  );
  final _visitedQueries = <_DashboardQuery<Object>>{};
  bool _visible = false;
  bool _accessEnded = false;
  SubmissionFilter? _filter;
  bool _busy = false;

  bool get _canView =>
      !_accessEnded &&
      _store.currentUid() == _access.uid &&
      _store.roles.access == _access.token &&
      _store.roles.verifiedRoleFor(_access.uid) == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    // Keep actions bound to the authorization that opened this dashboard.
    _access = _store.capture(UserRole.administrator);
    _store.roles.addListener(_authorizationChanged);
    _tabsController.addListener(_startTabQueries);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible == visible) return;
    _visible = visible;
    if (visible && _canView) {
      _startTabQueries();
      for (final query in _visitedQueries) {
        query.start();
      }
    } else {
      _stopQueries();
    }
  }

  void _startTabQueries() {
    if (!_visible || !_canView) return;
    final queries = switch (_tabsController.index) {
      0 => [_applications, _trainerRoles],
      1 => [_submissions, _techniques],
      _ => [_techniques],
    };
    for (final query in queries) {
      _visitedQueries.add(query);
      query.start();
    }
  }

  void _stopQueries({bool clear = false}) {
    for (final query in _visitedQueries) {
      query.stop(clear: clear);
    }
  }

  void _authorizationChanged() {
    if (_canView || _accessEnded) return;
    _accessEnded = true;
    _stopQueries(clear: true);
    setState(() {});
  }

  void _queryChanged() {
    if (!mounted) return;
    if (!_canView) {
      _authorizationChanged();
      return;
    }
    setState(() {});
  }

  void _retry(_DashboardQuery<Object> query) {
    if (!_canView || !_visible) return;
    setState(query.retry);
  }

  @override
  void dispose() {
    _store.roles.removeListener(_authorizationChanged);
    _tabsController.dispose();
    _stopQueries(clear: true);
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy || !_canView) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted || !_canView) return;
      _notify('Changes saved.');
    } catch (error) {
      if (!mounted || !_canView) return;
      _notify(
        error is StateError
            ? error.message
            : 'Could not save changes. Try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<String?> _confirm({
    required String title,
    required String description,
    required String action,
    bool withReason = false,
  }) {
    var reason = '';
    return showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) => _guardOverlay(
        AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              if (withReason)
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                  maxLength: 1000,
                  maxLines: 2,
                  onChanged: (value) => reason = value,
                ),
            ],
          ),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, reason),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guardOverlay(Widget child) => ListenableBuilder(
    listenable: _store.roles,
    child: child,
    builder: (_, child) => _canView ? child! : const SizedBox.shrink(),
  );

  Future<void> _decideApplication(
    TrainerApplication application,
    ReviewStatus decision,
  ) async {
    final String? reason;
    if (decision == ReviewStatus.approved &&
        application.status == ReviewStatus.pending) {
      reason = '';
    } else {
      final (title, description, action) = switch (decision) {
        ReviewStatus.revoked => (
          'Revoke Trainer access?',
          'This account will lose Trainer access.',
          'Revoke',
        ),
        ReviewStatus.approved => (
          'Reinstate Trainer access?',
          'This account will regain Trainer access.',
          'Reinstate',
        ),
        _ => (
          'Reject trainer application?',
          'The applicant can view your decision and reapply.',
          'Reject',
        ),
      };
      reason = await _confirm(
        title: title,
        description: description,
        action: action,
        withReason: decision != ReviewStatus.approved,
      );
    }
    if (reason == null || !mounted) return;
    await _perform(
      () => _store.reviewApplication(
        _access,
        application.uid,
        decision,
        reason: reason,
        external: application.external ? application : null,
      ),
    );
  }

  Future<void> _manage({
    required String title,
    required String description,
    required String action,
    required Future<void> Function() save,
  }) async {
    final confirmed = await _confirm(
      title: title,
      description: description,
      action: action,
    );
    if (confirmed == null || !mounted) return;
    await _perform(save);
  }

  Future<void> _reopen(TechniqueSubmission submission) => _manage(
    title: 'Reopen submission?',
    description: '${submission.technique.name} will return to Pending.',
    action: 'Reopen',
    save: () => _store.moderate(_access, submission.id, ReviewStatus.pending),
  );

  void _edit([Technique? existing]) => showTechniqueForm(
    context,
    title: existing == null
        ? 'Add Published Technique'
        : 'Edit Published Technique',
    submitLabel: 'Save technique',
    id: existing?.id ?? _store.newTechniqueId(),
    existing: existing,
    color: _adminColor,
    guard: _guardOverlay,
    save: (technique) =>
        _store.saveTechnique(_access, technique, editing: existing != null),
  );

  Future<void> _remove(Technique technique) async {
    await _manage(
      title: 'Remove ${technique.name}?',
      description: 'This removes the technique from the library. A linked review record will show Removed from Library.',
      action: 'Delete',
      save: () => _store.removeTechnique(_access, technique.id),
    );
  }

  Widget _trainerRequests() => _DashboardFeed(
    query: _applications,
    title: 'trainer requests',
    loadFailure: 'Could not load trainer requests.',
    retry: () => _retry(_applications),
    content: (applications) {
      final pending = applications
          .where((item) => item.status == ReviewStatus.pending)
          .toList();
      final reviewed = applications.where(
        (item) =>
            item.status != ReviewStatus.pending &&
            item.status != ReviewStatus.approved,
      );
      final known = applications.map((item) => item.uid).toSet();
      final approved = [
        ...applications.where((item) => item.status == ReviewStatus.approved),
        ...(_trainerRoles.rows ?? const []).where(
          (item) => !known.contains(item.uid),
        ),
      ];
      return [
        _CountStrip({
          'Pending': pending.length,
          'Approved trainers': approved.length,
          'Reviewed': applications.length - pending.length,
        }),
        const SectionHeader('Pending requests'),
        if (pending.isEmpty) const EmptyState('No pending trainer requests.'),
        for (final application in pending) _applicationCard(application),
        const SectionHeader('Approved trainers'),
        _FeedNotice(
          query: _trainerRoles,
          title: 'directly provisioned trainers',
          loadFailure: 'Could not load directly provisioned trainers.',
          retry: () => _retry(_trainerRoles),
        ),
        if (approved.isEmpty &&
            _trainerRoles.rows != null &&
            !_trainerRoles.failed)
          const EmptyState('No approved trainers.'),
        for (final application in approved) _applicationCard(application),
        const SectionHeader('Previously reviewed'),
        for (final application in reviewed) _applicationCard(application),
        if (reviewed.isEmpty) const EmptyState('No reviewed trainer requests.'),
      ];
    },
  );

  Widget _applicationCard(TrainerApplication application) => _ReviewCard(
    key: ValueKey(application.uid),
    title: application.name,
    subtitle: [
      if (application.email.isNotEmpty) application.email,
      application.status?.label ?? 'Unknown',
    ].join(' · '),
    children: [
      if (application.field('academy').isNotEmpty) ...[
        Text(application.field('academy')),
        Text(application.field('position')),
        Text('Contact: ${application.field('contact')}'),
        Text(application.field('reason')),
      ],
      if (application.field('belt').isNotEmpty)
        Text('Belt: ${application.field('belt')}'),
      if (application.field('reviewReason').isNotEmpty)
        Text(application.field('reviewReason')),
      if (application.status == ReviewStatus.pending)
        _ReviewActions(
          busy: _busy,
          onSelect: (decision) => _decideApplication(application, decision),
        ),
      if (application.status == ReviewStatus.approved)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _decideApplication(application, ReviewStatus.revoked),
          child: const Text('Revoke access'),
        ),
      if (application.status == ReviewStatus.revoked)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _decideApplication(application, ReviewStatus.approved),
          child: const Text('Reinstate Access'),
        ),
      if (application.status == ReviewStatus.rejected ||
          application.status == ReviewStatus.revoked)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _manage(
                  title: 'Delete trainer application?',
                  description: 'This removes the previous decision from the applicant’s Profile. The applicant can submit a new request.',
                  action: 'Delete application',
                  save: () =>
                      _store.deleteApplication(_access, application.uid),
                ),
          child: const Text('Delete application'),
        ),
    ],
  );

  Widget _videoSubmissions() {
    final catalog = _techniques.rows;
    if (catalog == null) {
      return Center(child: _publicationNotice());
    }
    return _submissionFeed(catalog.map((item) => item.id).toSet());
  }

  Widget _publicationNotice() => _FeedNotice(
    query: _techniques,
    title: 'publication status',
    loadFailure: 'Could not verify publication status.',
    retry: () => _retry(_techniques),
  );

  Widget _submissionFeed(Set<String> published) => _DashboardFeed(
    query: _submissions,
    title: 'video submissions',
    loadFailure: 'Could not load video submissions.',
    retry: () => _retry(_submissions),
    content: (submissions) {
      final groups = {
        for (final status in SubmissionFilter.values)
          status: <TechniqueSubmission>[],
      };
      for (final item in submissions) {
        if (item.archived) continue;
        final status = SubmissionFilter.classify(item, published);
        if (status != null) groups[status]!.add(item);
      }
      for (final group in groups.values) {
        group.sort((first, second) {
          final byDate = (second.submittedAt?.millisecondsSinceEpoch ?? 0)
              .compareTo(first.submittedAt?.millisecondsSinceEpoch ?? 0);
          return byDate == 0 ? second.id.compareTo(first.id) : byDate;
        });
      }
      final count = groups.values.fold(
        0,
        (total, group) => total + group.length,
      );
      final visible = _filter == null ? SubmissionFilter.values : [_filter!];
      return [
        _publicationNotice(),
        Wrap(
          spacing: 8,
          children: [
            for (final status in [null, ...SubmissionFilter.values])
              ChoiceChip(
                key: ValueKey('video-filter-${status?.name ?? 'all'}'),
                label: Text(
                  '${status?.label ?? 'All Statuses'} · ${status == null ? count : groups[status]!.length}',
                ),
                selected: _filter == status,
                selectedColor: _adminColor.withValues(alpha: .24),
                onSelected: (_) => setState(() => _filter = status),
              ),
          ],
        ),
        DropdownButton<SubmissionFilter?>(
          value: _filter,
          hint: const Text('All Statuses'),
          isExpanded: true,
          onChanged: (status) => setState(() => _filter = status),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Statuses')),
            for (final status in SubmissionFilter.values)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
        ),
        if (count == 0 || (_filter != null && groups[_filter]!.isEmpty))
          EmptyState(
            count == 0
                ? 'No video submissions yet.'
                : 'No submissions match this status.',
          ),
        for (final status in visible)
          if (groups[status]!.isNotEmpty) ...[
            if (_filter == null) SectionHeader(status.label),
            for (final submission in groups[status]!)
              _submissionCard(submission, status),
          ],
      ];
    },
  );

  Widget _submissionCard(
    TechniqueSubmission submission,
    SubmissionFilter status,
  ) => _ReviewCard(
    key: ValueKey(submission.id),
    title: submission.technique.name,
    subtitle:
        '${submission.technique.category} · ${switch (status) {
          SubmissionFilter.approved => 'Approved · Published',
          SubmissionFilter.removed => 'Approved · Removed from Library',
          _ => status.label,
        }}',
    children: [
      Text('Submitted by: ${submission.name}'),
      if (submission.email.isNotEmpty) Text(submission.email),
      _TechniqueInformation(
        technique: submission.technique,
        guard: _guardOverlay,
      ),
      if (status == SubmissionFilter.pending)
        _ReviewActions(
          busy: _busy,
          onSelect: (decision) =>
              _perform(() => _store.moderate(_access, submission.id, decision)),
        ),
      if (status == SubmissionFilter.rejected) ...[
        OutlinedButton(
          onPressed: _busy ? null : () => _reopen(submission),
          child: const Text('Reopen for Review'),
        ),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _manage(
                  title: 'Delete rejected submission?',
                  description: 'This removes the rejected review record.',
                  action: 'Delete submission',
                  save: () =>
                      _store.deleteRejectedSubmission(_access, submission.id),
                ),
          child: const Text('Delete submission'),
        ),
      ],
      if (status == SubmissionFilter.removed)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _manage(
                  title: 'Republish technique?',
                  description: 'This restores the original submission to the library using the same technique ID.',
                  action: 'Republish',
                  save: () => _store.republish(_access, submission.id),
                ),
          child: const Text('Republish'),
        ),
      if (status == SubmissionFilter.approved ||
          status == SubmissionFilter.removed)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _manage(
                  title: 'Archive review record?',
                  description: 'This hides the review record. Any published technique stays in the library.',
                  action: 'Archive',
                  save: () => _store.archiveSubmission(_access, submission.id),
                ),
          child: const Text('Archive Review Record'),
        ),
    ],
  );

  Widget _publishedTechniques() => _DashboardFeed(
    query: _techniques,
    title: 'published techniques',
    loadFailure: 'Could not load published techniques.',
    retry: () => _retry(_techniques),
    content: (techniques) => [
      _CountStrip({'Published': techniques.length}),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _adminColor),
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Add Published Technique'),
      ),
      if (techniques.isEmpty)
        const EmptyState('No published techniques available.'),
      for (final technique in techniques)
        _ReviewCard(
          key: ValueKey(technique.id),
          title: technique.name,
          subtitle: '${technique.category} · ${technique.difficulty}',
          children: [
            _TechniqueInformation(technique: technique, guard: _guardOverlay),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _edit(technique),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _remove(technique),
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return const Scaffold(
        body: Center(child: Text('Administrator access is unavailable.')),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: _adminColor,
        foregroundColor: Colors.white,
        bottom: _tabs(context),
      ),
      body: TabBarView(
        controller: _tabsController,
        children: [
          _DashboardPage(child: _trainerRequests()),
          _DashboardPage(child: _videoSubmissions()),
          _DashboardPage(child: _publishedTechniques()),
        ],
      ),
    );
  }

  TabBar _tabs(BuildContext context) {
    const labels = [
      'Trainer Requests',
      'Video Submissions',
      'Published Techniques',
    ];
    final style = Theme.of(context).textTheme.titleSmall!;
    final width = MediaQuery.sizeOf(context).width / labels.length - 8;
    var height = 46.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      if (painter.height + 16 > height) height = painter.height + 16;
      painter.dispose();
    }
    return TabBar(
      controller: _tabsController,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: style,
      unselectedLabelStyle: style,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      tabs: [
        for (final label in labels)
          Tab(
            height: height,
            child: Text(label, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _DashboardQuery<T> {
  _DashboardQuery(this._watch, this._changed);

  final Stream<ReviewSnapshot<T>> Function() _watch;
  final VoidCallback _changed;
  StreamSubscription<ReviewSnapshot<T>>? _subscription;
  Timer? _deadline;
  bool _started = false;
  bool _waiting = true;
  bool failed = false;
  List<T>? rows;

  bool get refreshing => rows != null && _waiting;

  void start() {
    if (_started) return;
    _started = true;
    failed = false;
    _waiting = true;
    _startDeadline();
    try {
      _subscription = _watch().listen(
        _received,
        onError: _failed,
        onDone: _failed,
      );
    } catch (error) {
      // A query factory can also fail before it returns a stream.
      scheduleMicrotask(() {
        if (_started) _failed(error);
      });
    }
  }

  void _startDeadline() {
    _deadline ??= Timer(const Duration(seconds: 12), _failed);
  }

  void _received(ReviewSnapshot<T> snapshot) {
    if (snapshot.fromCache) {
      // Wait for a server result before showing an empty list or classifying
      // a publication. During reconnection keep the last verified rows.
      if (_waiting || failed) return;
      _waiting = true;
      _startDeadline();
    } else {
      _cancelDeadline();
      rows = snapshot.rows;
      failed = false;
      _waiting = false;
    }
    _changed();
  }

  void _failed([Object? error]) {
    _cancelDeadline();
    if (error is FirebaseException &&
        (error.code == 'permission-denied' ||
            error.code == 'unauthenticated')) {
      stop(clear: true);
      _started = true; // Wait for an explicit retry.
    }
    if (failed) return;
    failed = true;
    _waiting = false;
    _changed();
  }

  void _cancelDeadline() {
    _deadline?.cancel();
    _deadline = null;
  }

  void retry() {
    stop();
    start();
  }

  void stop({bool clear = false}) {
    _cancelDeadline();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _started = false;
    if (clear) rows = null;
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({required this.child});
  final Widget child;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _FeedNotice extends StatelessWidget {
  const _FeedNotice({
    required this.query,
    required this.title,
    required this.loadFailure,
    required this.retry,
  });

  final _DashboardQuery<Object> query;
  final String title;
  final String loadFailure;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    if (query.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            query.rows == null
                ? loadFailure
                : '$loadFailure Showing the last loaded data.',
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: retry, child: Text('Retry $title')),
        ],
      );
    }
    if (query.rows != null && !query.refreshing) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LinearProgressIndicator(),
        Text(query.refreshing ? 'Refreshing $title…' : 'Loading $title…'),
      ],
    );
  }
}

class _DashboardFeed<T extends Object> extends StatelessWidget {
  const _DashboardFeed({
    required this.query,
    required this.title,
    required this.loadFailure,
    required this.retry,
    required this.content,
  });

  final _DashboardQuery<T> query;
  final String title;
  final String loadFailure;
  final VoidCallback retry;
  final List<Widget> Function(List<T>) content;

  @override
  Widget build(BuildContext context) {
    final notice = _FeedNotice(
      query: query,
      title: title,
      loadFailure: loadFailure,
      retry: retry,
    );
    final rows = query.rows;
    if (rows == null) return Center(child: notice);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [notice, ...content(rows)],
    );
  }
}

class _CountStrip extends StatelessWidget {
  const _CountStrip(this.counts);
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final entry in counts.entries)
        Chip(
          backgroundColor: _adminColor.withValues(alpha: .14),
          label: Text('${entry.key} · ${entry.value}'),
        ),
    ],
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      leading: const Icon(Icons.fact_check_outlined, color: _adminColor),
      title: Text(title),
      subtitle: Text(subtitle),
      children: children,
    ),
  );
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.busy, required this.onSelect});

  final bool busy;
  final ValueChanged<ReviewStatus> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: busy ? null : () => onSelect(ReviewStatus.rejected),
          child: const Text('Reject'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _adminColor),
          onPressed: busy ? null : () => onSelect(ReviewStatus.approved),
          child: const Text('Approve'),
        ),
      ),
    ],
  );
}

class _TechniqueInformation extends StatelessWidget {
  const _TechniqueInformation({required this.technique, required this.guard});
  final Technique technique;
  final Widget Function(Widget) guard;

  @override
  Widget build(BuildContext context) {
    final videoId = Technique.youtubeId(technique.videoUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${technique.instructor ?? ''} · ${technique.difficulty}'),
        Text(technique.description),
        if (videoId != null)
          TextButton.icon(
            onPressed: () =>
                showFormSheet(context, guard(_VideoPreview(videoId))),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Preview YouTube video'),
          ),
      ],
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview(this.id);
  final String id;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final _controller = YoutubePlayerController.fromVideoId(
    videoId: widget.id,
    autoPlay: false,
  );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => YoutubePlayer(controller: _controller);
}
