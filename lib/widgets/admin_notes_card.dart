import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_note_model.dart';

class AdminNotesCard extends StatelessWidget {
  const AdminNotesCard({
    super.key,
    required this.notes,
    required this.canManage,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    this.unreadCount = 0,
    this.maxItems = 4,
  });

  final List<AdminNote> notes;
  final bool canManage;
  final Future<void> Function(String title, String message, bool isImportant)
  onCreate;
  final Future<void> Function(
    AdminNote note,
    String title,
    String message,
    bool isImportant,
  )
  onUpdate;
  final Future<void> Function(AdminNote note) onDelete;
  final int unreadCount;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final visibleNotes = notes.take(maxItems).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Admin Notes',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 10),
                            _UnreadBadge(count: unreadCount),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canManage
                            ? 'Create fast team announcements that sync across every signed-in device.'
                            : 'Latest announcements from the admin team.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.tonalIcon(
                    onPressed: () => _showEditor(context),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('New note'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (visibleNotes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'No admin notes yet. Important reminders and daily instructions will appear here.',
                ),
              )
            else
              Column(
                children: visibleNotes
                    .map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdminNoteTile(
                          note: note,
                          canManage: canManage,
                          onEdit: () => _showEditor(context, note: note),
                          onDelete: () => _confirmDelete(context, note),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, {AdminNote? note}) async {
    final titleController = TextEditingController(text: note?.title ?? '');
    final messageController = TextEditingController(
      text: note?.message ?? '',
    );
    bool isImportant = note?.isImportant ?? false;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  note == null ? 'New admin note' : 'Edit admin note',
                ),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Title is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: messageController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Message is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mark as important'),
                          secondary: const Icon(Icons.priority_high_rounded),
                          value: isImportant,
                          onChanged: (value) =>
                              setDialogState(() => isImportant = value ?? false),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setDialogState(() => isSaving = true);
                            try {
                              if (note == null) {
                                await onCreate(
                                  titleController.text,
                                  messageController.text,
                                  isImportant,
                                );
                              } else {
                                await onUpdate(
                                  note,
                                  titleController.text,
                                  messageController.text,
                                  isImportant,
                                );
                              }
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to save note: $error',
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => isSaving = false);
                              }
                            }
                          },
                    child: Text(isSaving ? 'Saving...' : 'Save note'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
  }

  Future<void> _confirmDelete(BuildContext context, AdminNote note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete note'),
          content: Text('Delete "${note.title}" from Admin Notes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    try {
      await onDelete(note);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $error')),
        );
      }
    }
  }
}

/// Small red badge showing an unread count.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onError,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminNoteTile extends StatelessWidget {
  const _AdminNoteTile({
    required this.note,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminNote note;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('MMM d • h:mm a').format(note.updatedAt);
    final importantColor = Theme.of(context).colorScheme.errorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: note.isImportant
            ? importantColor
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: note.isImportant
            ? Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.isImportant) ...[
                Icon(
                  Icons.priority_high_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timestamp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(note.message),
          const SizedBox(height: 12),
          Text(
            'From ${note.createdBy.isEmpty ? 'Admin' : note.createdBy}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
