import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/doodles.dart';
import '../../../core/widgets/text_entry_dialog.dart';
import '../data/boards_repository.dart';
import '../domain/board.dart';
import 'board_painters.dart';

/// The Canvas tab: every board as a thumbnail, newest first.
class CanvasListScreen extends StatelessWidget {
  const CanvasListScreen({super.key});

  void _create(BuildContext context) {
    final board = Board.create();
    BoardsRepository.instance.save(board);
    context.push(AppRoutes.canvasById(board.id));
  }

  @override
  Widget build(BuildContext context) {
    final repo = BoardsRepository.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas'),
        actions: [
          IconButton(
            tooltip: 'New canvas',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => _create(context),
          ),
          const SecondaryMenuButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final boards = repo.boards;
          if (boards.isEmpty) {
            return _EmptyCanvases(onCreate: () => _create(context));
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemCount: boards.length,
            itemBuilder: (context, i) => _BoardTile(board: boards[i]),
          );
        },
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.board});

  final Board board;

  void _showActions(BuildContext context) {
    final repo = BoardsRepository.instance;
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final title = await showTextEntryDialog(
                  context,
                  title: 'Name this canvas',
                  initial: board.title == Board.defaultTitle ? '' : board.title,
                  hint: Board.defaultTitle,
                );
                if (title == null) return;
                repo.save(
                  board.copyWith(
                    title: title.trim().isEmpty
                        ? Board.defaultTitle
                        : title.trim(),
                    updatedAt: DateTime.now(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                repo.delete(board.id);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: const Text('Canvas deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => repo.save(board),
                      ),
                    ),
                  );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = board.cards.length;
    final summary = [
      switch (count) {
        0 => 'No cards',
        1 => '1 card',
        _ => '$count cards',
      },
      relativeTime(board.updatedAt),
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: SketchBorder(
        side: BorderSide(
          color: scheme.outline,
          width: SketchStyles.strokeWidth,
        ),
        seed: board.id.hashCode,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.canvasById(board.id)),
        onLongPress: () => _showActions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ColoredBox(
                color: scheme.surfaceContainerHigh,
                child: board.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.gesture_rounded,
                          size: 36,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : ExcludeSemantics(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: BoardThumbnailPainter(
                            board: board,
                            ink: scheme.outline,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    summary,
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCanvases extends StatelessWidget {
  const _EmptyCanvases({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
        child: Column(
          children: [
            const Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.hub_outlined, size: 64),
                Positioned(
                  right: -30,
                  top: -20,
                  child: SparkRays(size: 34, angle: -0.8),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MarkerHighlight(
              color: AppColors.markerBlue,
              child: Text('Think visually', style: text.headlineSmall),
            ),
            const SizedBox(height: 8),
            Text(
              'Lay ideas out as cards, connect them with arrows and sketch '
              'around them.',
              style: text.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New canvas'),
            ),
          ],
        ),
      ),
    );
  }
}
