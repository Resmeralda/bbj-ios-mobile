import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../models/technique.dart';
import '../services/technique_service.dart';
import '../services/favorites_service.dart';

/// Standalone red Techniques page. The Training tab reuses TechniquesContent.
class TechniquesScreen extends StatefulWidget {
  final String initialCategory;
  final bool favoritesOnly;

  const TechniquesScreen({
    super.key,
    this.initialCategory = 'All',
    this.favoritesOnly = false,
  });

  @override
  State<TechniquesScreen> createState() => _TechniquesScreenState();
}

class _TechniquesScreenState extends State<TechniquesScreen> {
  static const filters = ['All', 'Takedowns', 'Submissions', 'Guard', 'Escapes'];
  late int tab;
  bool showSearch = false;
  String search = '';
  Set<String> selectedDifficulties = {}; // Empty means all levels.

  @override
  void initState() {
    super.initState();
    _selectCategory();
  }

  void _selectCategory() {
    final index = filters.indexOf(widget.initialCategory);
    tab = index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant TechniquesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      _selectCategory();
    }
  }

  Future<void> _showDifficultyFilters() async {
    final draft = Set<String>.from(selectedDifficulties);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          const levels = ['Beginner', 'Intermediate', 'Advanced'];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter by difficulty',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('All Levels'),
                    value: draft.isEmpty,
                    onChanged: (_) => updateSheet(draft.clear),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  for (final level in levels)
                    CheckboxListTile(
                      title: Text(level),
                      value: draft.contains(level),
                      onChanged: (checked) => updateSheet(() {
                        if (checked == true) {
                          draft.add(level);
                        } else {
                          draft.remove(level);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, Set<String>.from(draft)),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() => selectedDifficulties = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: widget.favoritesOnly ? 'My Favorites' : 'Techniques',
      color: AppColors.techniques,
      actionIcon: showSearch ? Icons.close : Icons.search,
      onAction: () => setState(() {
        showSearch = !showSearch;
        if (!showSearch) search = '';
      }),
      tabs: filters,
      tab: tab,
      onTab: (index) => setState(() => tab = index),
      children: [
        if (showSearch) ...[
          TextField(
            autofocus: true,
            onChanged: (value) => setState(() => search = value),
            decoration: InputDecoration(
              hintText: 'Search techniques or instructors',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _showDifficultyFilters,
              icon: Icon(
                Icons.tune,
                color: selectedDifficulties.isEmpty
                    ? AppColors.muted
                    : AppColors.techniques,
              ),
              label: Text(
                selectedDifficulties.isEmpty
                    ? 'Filter'
                    : 'Filter (${selectedDifficulties.length})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TechniquesContent(
          category: filters[tab],
          showOverview: false,
          favoritesOnly: widget.favoritesOnly,
          searchQuery: search,
          selectedDifficulties: selectedDifficulties,
        ),
      ],
    );
  }
}

/// Used in both the blue Training overview and red Techniques page.
class TechniquesContent extends StatefulWidget {
  final String category;
  final bool showOverview;
  final bool favoritesOnly;
  final String searchQuery;
  final Set<String> selectedDifficulties;

  const TechniquesContent({
    super.key,
    this.category = 'All',
    this.showOverview = true,
    this.favoritesOnly = false,
    this.searchQuery = '',
    this.selectedDifficulties = const {},
  });

  @override
  State<TechniquesContent> createState() => _TechniquesContentState();
}

class _TechniquesContentState extends State<TechniquesContent> {
  final TechniqueService _techniqueService = TechniqueService();
  final FavoritesService _favoritesService = FavoritesService();
  late final Stream<List<Technique>> _techniquesStream;
  late final Stream<Set<String>> _favoritesStream;
  bool showAll = false;
  final Set<String> _pendingFavorites = {};

  @override
  void initState() {
    super.initState();
    _techniquesStream = _techniqueService.getTechniques();
    _favoritesStream = _favoritesService.getFavorites();
  }

  bool _sameLevels(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void didUpdateWidget(covariant TechniquesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.searchQuery != widget.searchQuery ||
        !_sameLevels(oldWidget.selectedDifficulties, widget.selectedDifficulties) ||
        oldWidget.favoritesOnly != widget.favoritesOnly) {
      showAll = false;
    }
  }

  Future<void> _toggleFavorite(Technique technique, bool isFavorite) async {
    if (_pendingFavorites.contains(technique.id)) return;
    setState(() => _pendingFavorites.add(technique.id));
    try {
      await _favoritesService.toggleFavorite(technique.id, isFavorite);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update favorites.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingFavorites.remove(technique.id));
    }
  }

  void _openTechnique(Technique technique) => context.push(
    '/training/techniques/${Uri.encodeComponent(technique.id)}',
  );

  void _openLibrary({String category = 'All', bool favoritesOnly = false}) {
    context.push(Uri(
      path: '/training/techniques',
      queryParameters: {
        'category': category,
        if (favoritesOnly) 'favorites': 'true',
      },
    ).toString());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Technique>>(
      stream: _techniquesStream,
      builder: (context, techniqueSnapshot) {
        if (techniqueSnapshot.hasError) {
          return const Center(child: Text('Could not load techniques.'));
        }
        if (!techniqueSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allTechniques = techniqueSnapshot.data!;
        if (allTechniques.isEmpty) {
          return const Center(child: Text('No techniques available yet.'));
        }
        final featured = allTechniques.firstWhere(
          (technique) => technique.id == 'armbar-guard',
          orElse: () => allTechniques.first,
        );
        int count(String category) => allTechniques
            .where((technique) => technique.category == category)
            .length;

        final query = widget.searchQuery.trim().toLowerCase();
        final techniques = allTechniques.where((technique) {
          final matchesCategory = widget.category == 'All' ||
              technique.category == widget.category;
          final matchesDifficulty = widget.selectedDifficulties.isEmpty ||
              widget.selectedDifficulties.any((level) =>
                  level.toLowerCase() == technique.difficulty.toLowerCase());
          final matchesSearch = query.isEmpty ||
              technique.name.toLowerCase().contains(query) ||
              technique.category.toLowerCase().contains(query) ||
              (technique.instructor ?? '').toLowerCase().contains(query) ||
              technique.description.toLowerCase().contains(query);
          return matchesCategory && matchesDifficulty && matchesSearch;
        }).toList();

        return StreamBuilder<Set<String>>(
          stream: _favoritesStream,
          builder: (context, favoriteSnapshot) {
            if (favoriteSnapshot.hasError) {
              return const Center(child: Text('Could not load favorites.'));
            }
            if (!favoriteSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final favoriteIds = favoriteSnapshot.data!;
            final favorites = techniques
                .where((technique) => favoriteIds.contains(technique.id))
                .toList();
            final browse = widget.favoritesOnly ? favorites : techniques;
            final visible = (widget.showOverview || !showAll)
                ? browse.take(4).toList()
                : browse;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showOverview && !widget.favoritesOnly) ...[
                  AppCard(
                    color: Colors.blueGrey.shade700,
                    onTap: () => _openTechnique(featured),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Featured Technique',
                            style: TextStyle(color: Colors.white70)),
                        Text(featured.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            )),
                        Text(featured.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                          ),
                          onPressed: () => _openTechnique(featured),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Watch Video'),
                        ),
                      ],
                    ),
                  ),
                  Row(children: [
                    QuickTile(Icons.people_alt,
                        'Takedowns\n${count('Takedowns')} techniques',
                        Colors.red,
                        onTap: () => _openLibrary(category: 'Takedowns')),
                    QuickTile(Icons.sports_kabaddi,
                        'Submissions\n${count('Submissions')} techniques',
                        Colors.blue,
                        onTap: () => _openLibrary(category: 'Submissions')),
                    QuickTile(Icons.self_improvement,
                        'Guard\n${count('Guard')} techniques',
                        Colors.green,
                        onTap: () => _openLibrary(category: 'Guard')),
                    QuickTile(Icons.directions_run,
                        'Escapes\n${count('Escapes')} techniques',
                        Colors.amber.shade800,
                        onTap: () => _openLibrary(category: 'Escapes')),
                  ]),
                  const SizedBox(height: 12),
                ],
                if (!widget.favoritesOnly) ...[
                  SectionHeader(
                    widget.showOverview ? 'Continue Learning' : 'Browse Techniques',
                    action: widget.showOverview ? 'View All' : null,
                    actionColor: AppColors.techniques,
                    onAction: widget.showOverview ? () => _openLibrary() : null,
                  ),
                  if (browse.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No techniques match these filters.'),
                    )
                  else if (widget.showOverview)
                    SizedBox(
                      height: 170,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: browse.map((technique) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 190,
                            child: _VideoCard(
                              technique: technique,
                              isFavorite: favoriteIds.contains(technique.id),
                              onTap: () => _openTechnique(technique),
                              onFavoriteTap: () => _toggleFavorite(
                                  technique, favoriteIds.contains(technique.id)),
                            ),
                          ),
                        )).toList(),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 850
                            ? 4
                            : constraints.maxWidth >= 550 ? 3 : 2;
                        final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final technique in visible)
                              SizedBox(
                                width: cardWidth,
                                child: _VideoCard(
                                  technique: technique,
                                  isFavorite: favoriteIds.contains(technique.id),
                                  onTap: () => _openTechnique(technique),
                                  onFavoriteTap: () => _toggleFavorite(
                                      technique, favoriteIds.contains(technique.id)),
                                ),
                              ),
                            if (browse.length > 4)
                              SizedBox(
                                width: cardWidth,
                                height: 172,
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => setState(() => showAll = !showAll),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(showAll ? Icons.expand_less : Icons.arrow_forward,
                                            color: AppColors.techniques, size: 34),
                                        const SizedBox(height: 8),
                                        Text(showAll ? 'Show Less' : 'Show More',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (!showAll)
                                          Text('${browse.length - 4} more',
                                              style: const TextStyle(color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                ],
                SectionHeader(
                  widget.favoritesOnly ? 'Saved Techniques' : 'My Favorites',
                  action: widget.favoritesOnly ? null : 'View All',
                  actionColor: AppColors.techniques,
                  onAction: widget.favoritesOnly ? null : () => _openLibrary(
                    category: widget.category,
                    favoritesOnly: true,
                  ),
                ),
                if (favorites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.category == 'All'
                          ? 'No favorites saved yet. Tap a bookmark to save a technique.'
                          : 'No favorite ${widget.category.toLowerCase()} techniques yet.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  for (final technique in widget.favoritesOnly
                      ? favorites
                      : favorites.take(3))
                    _Fav(
                      technique: technique,
                      onTap: () => _openTechnique(technique),
                      onFavoriteTap: () => _toggleFavorite(technique, true),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

String? _thumbnailUrl(String? videoUrl) {
  if (videoUrl == null || videoUrl.isEmpty) return null;
  final videoId = YoutubePlayerController.convertUrlToId(videoUrl);
  if (videoId == null || videoId.isEmpty) return null;
  return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

class _VideoCard extends StatelessWidget {
  final Technique technique;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const _VideoCard({
    required this.technique,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = _thumbnailUrl(technique.videoUrl);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: thumbnail == null
                          ? Container(color: Colors.black87)
                          : Image.network(
                              thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.black87),
                            ),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle, color: Colors.white, size: 36),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                        onPressed: onFavoriteTap,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          isFavorite ? Icons.bookmark : Icons.bookmark_border,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(technique.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(technique.difficulty,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fav extends StatelessWidget {
  final Technique technique;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const _Fav({
    required this.technique,
    required this.onTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = _thumbnailUrl(technique.videoUrl);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              image: thumbnail == null
                  ? null
                  : DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover),
            ),
            child: const Icon(Icons.play_circle, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(technique.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${technique.category} • ${technique.difficulty}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(technique.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove from favorites',
            onPressed: onFavoriteTap,
            icon: const Icon(Icons.bookmark, color: AppColors.techniques),
          ),
        ],
      ),
    );
  }
}
