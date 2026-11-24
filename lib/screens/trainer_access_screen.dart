import 'package:flutter/material.dart';

import '../data/review_store.dart';
import '../data/role_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';
import 'review_forms.dart';

class TrainerAccessPanel extends StatefulWidget {
  const TrainerAccessPanel({
    super.key,
    required this.store,
    required this.uid,
    required this.role,
  });

  final ReviewStore store;
  final String uid;
  final UserRole? role;

  @override
  State<TrainerAccessPanel> createState() => _TrainerAccessPanelState();
}

class _TrainerAccessPanelState extends State<TrainerAccessPanel> {
  late final _application = widget.store.watchApplication(widget.uid);

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _application,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const EmptyState('Could not load your trainer request.');
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator();
      }
      final application = snapshot.data;
      final status = application?.status;
      final canApply =
          widget.role == UserRole.student &&
          (application == null ||
              status == ReviewStatus.rejected ||
              status == ReviewStatus.revoked);
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trainer access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              application == null
                  ? 'No trainer request submitted.'
                  : status?.label ?? 'Request status unavailable',
            ),
            if (application != null &&
                application.field('reviewReason').isNotEmpty)
              Text(application.field('reviewReason')),
            if (application != null && application.field('academy').isNotEmpty)
              OutlinedButton(
                onPressed: () => showTrainerApplication(
                  context,
                  widget.store,
                  null,
                  application: application,
                ),
                child: const Text('View application'),
              ),
            if (canApply ||
                (widget.role == UserRole.student &&
                    status == ReviewStatus.pending))
              OutlinedButton(
                onPressed: () {
                  final access = _startDraft(
                    context,
                    widget.store,
                    UserRole.student,
                  );
                  if (access != null) {
                    showTrainerApplication(
                      context,
                      widget.store,
                      access,
                      application: application,
                      editing: status == ReviewStatus.pending,
                    );
                  }
                },
                child: Text(
                  status == ReviewStatus.pending
                      ? 'Edit pending application'
                      : 'Request Trainer Access',
                ),
              ),
          ],
        ),
      );
    },
  );
}

void openSubmissionForm(BuildContext context, ReviewStore store) {
  final access = _startDraft(context, store, UserRole.trainer);
  if (access == null) return;
  final draft = store.openDraft(access);
  showTechniqueForm(
    context,
    title: 'Submit Technique',
    submitLabel: 'Submit for review',
    id: draft.id,
    draft: draft,
    draftChanged: (field, value) => store.updateDraft(draft, field, value),
    clearDraft: draft.values.clear,
    save: (technique) => store.submitDraft(draft, technique),
  );
}

ReviewAccess? _startDraft(
  BuildContext context,
  ReviewStore store,
  UserRole role,
) {
  try {
    return store.capture(role);
  } on StateError catch (error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
    return null;
  }
}

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({
    super.key,
    required this.store,
    required this.uid,
  });

  final ReviewStore store;
  final String uid;

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  late final _submissions = widget.store.watchSubmissions(owner: widget.uid);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Submissions'),
      backgroundColor: AppColors.home,
      foregroundColor: Colors.white,
    ),
    body: StreamBuilder(
      stream: _submissions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load your submissions.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton(
              onPressed: () => openSubmissionForm(context, widget.store),
              child: const Text('Submit Technique'),
            ),
            if (snapshot.data!.isEmpty)
              const EmptyState('No video submissions yet.'),
            for (final submission in snapshot.data!)
              AppCard(
                child: ListTile(
                  title: Text(submission.technique.name),
                  subtitle: Text(
                    '${submission.technique.category} · ${submission.technique.difficulty}',
                  ),
                  trailing: Text(submission.status?.label ?? 'Unknown'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
