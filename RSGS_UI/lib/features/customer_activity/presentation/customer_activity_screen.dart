import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/customer_activity_repository.dart';

class CustomerActivityScreen extends ConsumerStatefulWidget {
  const CustomerActivityScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final int customerId;
  final String customerName;

  @override
  ConsumerState<CustomerActivityScreen> createState() =>
      _CustomerActivityScreenState();
}

class _CustomerActivityScreenState
    extends ConsumerState<CustomerActivityScreen> {
  Future<void> _addInteraction() async {
    final details = TextEditingController();
    final subject = TextEditingController();
    var type = 'Call';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('add_interaction'.tr(ref)),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      'Call',
                      'WhatsApp',
                      'Email',
                      'Meeting',
                      'Visit',
                      'Note',
                    ]
                        .map(
                          (x) => DropdownMenuItem<String>(
                            value: x,
                            child: Text(x),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => type = value ?? type);
                    },
                    decoration: InputDecoration(labelText: 'type'.tr(ref)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    decoration: InputDecoration(labelText: 'subject'.tr(ref)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: details,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: 'details'.tr(ref)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('cancel'.tr(ref)),
              ),
              FilledButton(
                onPressed: () async {
                  if (details.text.trim().isEmpty) return;

                  await ref
                      .read(customerActivityRepositoryProvider)
                      .createInteraction(
                        widget.customerId,
                        type: type,
                        subject: subject.text.trim().isEmpty
                            ? null
                            : subject.text.trim(),
                        details: details.text.trim(),
                      );
      DataRefreshCoordinator.refresh(ref);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: Text('save'.tr(ref)),
              ),
            ],
          );
        },
      ),
    );

    details.dispose();
    subject.dispose();

    if (result == true) {
      ref.invalidate(customerInteractionsProvider(widget.customerId));
    }
  }

  Future<void> _addFollowUp() async {
    final notes = TextEditingController();
    var type = 'Call';
    var status = 'Pending';
    var date = DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('add_follow_up'.tr(ref)),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      'Call',
                      'WhatsApp',
                      'Email',
                      'Meeting',
                      'Visit',
                    ]
                        .map(
                          (x) => DropdownMenuItem<String>(
                            value: x,
                            child: Text(x),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => type = value ?? type);
                    },
                    decoration: InputDecoration(labelText: 'type'.tr(ref)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('scheduled'.tr(ref)),
                    subtitle: Text(
                      MaterialLocalizations.of(context).formatMediumDate(date),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        initialDate: date,
                      );

                      if (selectedDate != null) {
                        setState(() {
                          date = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            10,
                          );
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: 'notes'.tr(ref)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      'Pending',
                      'Completed',
                      'Cancelled',
                    ]
                        .map(
                          (x) => DropdownMenuItem<String>(
                            value: x,
                            child: Text(x.tr(ref)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => status = value ?? status);
                    },
                    decoration: InputDecoration(labelText: 'status'.tr(ref)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('cancel'.tr(ref)),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(customerActivityRepositoryProvider)
                      .createFollowUp(
                        widget.customerId,
                        type: type,
                        scheduledAt: date,
                        status: status,
                        notes: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                      );
      DataRefreshCoordinator.refresh(ref);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: Text('save'.tr(ref)),
              ),
            ],
          );
        },
      ),
    );

    notes.dispose();

    if (result == true) {
      ref.invalidate(customerFollowUpsProvider(widget.customerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final followUps = ref.watch(
      customerFollowUpsProvider(widget.customerId),
    );
    final interactions = ref.watch(
      customerInteractionsProvider(widget.customerId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customerName} — ${'activities'.tr(ref)}'),
        actions: [
          IconButton(
            onPressed: _addFollowUp,
            icon: const Icon(Icons.add_task),
            tooltip: 'add_follow_up'.tr(ref),
          ),
          IconButton(
            onPressed: _addInteraction,
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'add_interaction'.tr(ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'follow_up'.tr(ref),
            style: context.headlineSmall?.black,
          ),
          const SizedBox(height: 12),
          followUps.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => Text('Error: $error'),
            data: (items) {
              if (items.isEmpty) {
                return Text('no_follow_ups'.tr(ref));
              }

              return Column(
                children: items.map((item) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text('${item.type.tr(ref)} • ${item.status.tr(ref)}'),
                      subtitle: Text(
                        '${MaterialLocalizations.of(context).formatMediumDate(item.scheduledAt)}\n'
                        '${item.notes ?? ''}',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'interaction_history'.tr(ref),
            style: context.headlineSmall?.black,
          ),
          const SizedBox(height: 12),
          interactions.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => Text('Error: $error'),
            data: (items) {
              if (items.isEmpty) {
                return Text('no_interactions'.tr(ref));
              }

              return Column(
                children: items.map((item) {
                  final title = item.subject == null || item.subject!.isEmpty
                      ? item.type.tr(ref)
                      : '${item.type.tr(ref)} • ${item.subject}';

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(title),
                      subtitle: Text(
                        '${item.details}\n'
                        '${MaterialLocalizations.of(context).formatMediumDate(item.occurredAt)}',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
