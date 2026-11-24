import 'package:flutter/material.dart';

import '../data/review_store.dart';
import '../models/technique.dart';
import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/form_helpers.dart';

typedef ReviewFormField = ({
  String key,
  String label,
  int limit,
  List<String>? choices,
});

const _techniqueFields = <ReviewFormField>[
  (key: 'name', label: 'Technique name', limit: 120, choices: null),
  (key: 'instructor', label: 'Instructor', limit: 120, choices: null),
  (key: 'category', label: 'Category', limit: 0, choices: Technique.categories),
  (
    key: 'difficulty',
    label: 'Difficulty',
    limit: 0,
    choices: Technique.difficulties,
  ),
  (key: 'description', label: 'Description', limit: 3000, choices: null),
  (key: 'videoUrl', label: 'YouTube URL', limit: 500, choices: null),
];

const _applicationFields = <ReviewFormField>[
  (key: 'academy', label: 'Academy or dojo', limit: 120, choices: null),
  (
    key: 'position',
    label: 'Position',
    limit: 0,
    choices: TrainerApplication.positions,
  ),
  (
    key: 'belt',
    label: 'Belt rank (optional)',
    limit: 0,
    choices: UserProfile.belts,
  ),
  (
    key: 'contact',
    label: 'Academy website or contact information',
    limit: 300,
    choices: null,
  ),
  (
    key: 'reason',
    label: 'Reason for requesting access',
    limit: 2000,
    choices: null,
  ),
];

Future<void> showTrainerApplication(
  BuildContext context,
  ReviewStore store,
  ReviewAccess? access, {
  TrainerApplication? application,
  bool editing = false,
}) => _showReviewForm(
  context,
  _ReviewForm(
    title: access == null
        ? 'Trainer application'
        : editing
        ? 'Edit trainer application'
        : 'Request Trainer Access',
    submitLabel: editing ? 'Save changes' : 'Send request',
    fields: _applicationFields,
    initial: {
      if (application != null)
        for (final field in _applicationFields)
          field.key: application.field(field.key),
    },
    readOnly: access == null,
    save: (values) =>
        store.apply(access!, values, editing: editing ? application : null),
  ),
);

Future<void> showTechniqueForm(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required String id,
  Technique? existing,
  Color color = AppColors.home,
  SubmissionDraft? draft,
  void Function(String, String)? draftChanged,
  VoidCallback? clearDraft,
  Widget Function(Widget)? guard,
  required Future<void> Function(Technique technique) save,
}) {
  final form = _ReviewForm(
    title: title,
    submitLabel: submitLabel,
    fields: _techniqueFields,
    color: color,
    initial: draft?.values ?? existing?.toPublication() ?? const {},
    draft: draft,
    draftChanged: draftChanged,
    clearDraft: clearDraft,
    save: (values) => save(Technique.fromMap(id, values)),
  );
  return _showReviewForm(context, guard?.call(form) ?? form);
}

Future<void> _showReviewForm(BuildContext context, Widget form) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..removeCurrentSnackBar();
  return showFormSheet(context, form);
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.save,
    this.initial = const {},
    this.color = AppColors.home,
    this.readOnly = false,
    this.draftChanged,
    this.clearDraft,
    this.draft,
  });

  final String title;
  final String submitLabel;
  final List<ReviewFormField> fields;
  final Map<String, String> initial;
  final Color color;
  final bool readOnly;
  final void Function(String, String)? draftChanged;
  final VoidCallback? clearDraft;
  final SubmissionDraft? draft;
  final Future<void> Function(Map<String, String>) save;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  var _form = GlobalKey<FormState>();
  late final _values = {
    for (final field in widget.fields)
      field.key: widget.initial[field.key] ?? '',
  };
  bool _saving = false;
  String? _error;

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this draft?'),
        content: const Text('The unfinished submission will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    widget.clearDraft!();
    setState(() {
      _values.clear();
      _form = GlobalKey<FormState>();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_values);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved successfully.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is StateError
            ? error.message
            : 'Could not save. Check your connection and try again.';
      });
    }
  }

  String? _validate(ReviewFormField field, String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return field.key == 'belt' ? null : 'Required';
    if (field.key == 'videoUrl' && Technique.youtubeId(value) == null) {
      return 'Enter a supported YouTube video URL.';
    }
    return null;
  }

  Widget _input(ReviewFormField field) {
    final choices = field.choices;
    final decoration = InputDecoration(labelText: field.label);
    if (choices != null) {
      return DropdownButtonFormField<String>(
        decoration: decoration,
        isExpanded: true,
        initialValue: choices.contains(_values[field.key])
            ? _values[field.key]
            : null,
        items: [
          if (field.key == 'belt')
            const DropdownMenuItem(value: '', child: Text('Not applicable')),
          for (final option in choices)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: _saving || widget.readOnly
            ? null
            : (value) => widget.draftChanged?.call(field.key, value ?? ''),
        validator: (value) => _validate(field, value),
        onSaved: (value) => _values[field.key] = value ?? '',
      );
    }
    return TextFormField(
      decoration: decoration,
      initialValue: _values[field.key],
      enabled: !_saving && !widget.readOnly,
      onChanged: (value) => widget.draftChanged?.call(field.key, value),
      maxLength: field.limit,
      maxLines: field.key == 'reason' || field.key == 'description' ? 3 : 1,
      keyboardType: field.key == 'videoUrl'
          ? TextInputType.url
          : TextInputType.text,
      validator: (value) => _validate(field, value),
      onSaved: (value) => _values[field.key] = value!.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    if (draft == null) return _buildForm();
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        if (draft.available) return _buildForm();
        _values.clear();
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('This submission draft is no longer available.'),
        );
      },
    );
  }

  Widget _buildForm() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(widget.title),
        for (final field in widget.fields) _input(field),
        if (_error case final error?)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        if (!widget.readOnly)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.color),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving…' : widget.submitLabel),
          ),
        if (widget.clearDraft != null)
          TextButton(
            onPressed: _saving ? null : _clear,
            child: const Text('Clear Draft'),
          ),
      ],
    ),
  );
}
