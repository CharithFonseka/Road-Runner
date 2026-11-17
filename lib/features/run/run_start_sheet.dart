import 'package:flutter/material.dart';

import '../../domain/run_name.dart';

class RunStartChoice {
  const RunStartChoice(this.displayName, this.customName);

  final String displayName;
  final String? customName;
}

/// Lets a runner keep the suggested time-of-day title or enter a custom one
/// before GPS tracking begins.
class RunStartSheet extends StatefulWidget {
  const RunStartSheet({super.key, this.routeName});

  final String? routeName;

  static const Key nameFieldKey = Key('runStart.name');
  static const Key startKey = Key('runStart.start');

  @override
  State<RunStartSheet> createState() => _RunStartSheetState();
}

class _RunStartSheetState extends State<RunStartSheet> {
  late final String _automaticName = makeRunName(DateTime.now(), null);
  late final TextEditingController _name = TextEditingController(
    text: widget.routeName ?? _automaticName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    final typed = _name.text.trim();
    final title = typed.isEmpty ? _automaticName : typed;
    Navigator.of(context)
        .pop(RunStartChoice(title, title == _automaticName ? null : title));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ready to run?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text('Give this run a name, or keep the suggestion.'),
              const SizedBox(height: 16),
              TextField(
                key: RunStartSheet.nameFieldKey,
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                onSubmitted: (_) => _start(),
                decoration: const InputDecoration(
                  labelText: 'Run name',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: RunStartSheet.startKey,
                onPressed: _start,
                icon: const Icon(Icons.directions_run_rounded),
                label: const Text('Start run'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
