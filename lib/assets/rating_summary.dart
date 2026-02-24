import 'package:flutter/material.dart';

class RatingSummaryPage extends StatefulWidget {
  const RatingSummaryPage({super.key});

  @override
  State<RatingSummaryPage> createState() => _RatingSummaryPageState();
}

class _RatingSummaryPageState extends State<RatingSummaryPage> {
  // Mock data – each entry has a username, a rating (1–5) and an optional comment.
  final List<Map<String, dynamic>> _ratings = [
    {
      'username': 'Alice M.',
      'rating': 5,
      'comment': 'Absolutely fantastic work!',
    },
    {
      'username': 'Bob K.',
      'rating': 4,
      'comment': 'Very professional and on time.',
    },
    {
      'username': 'Carol T.',
      'rating': 5,
      'comment': 'Best service I have ever had.',
    },
    {'username': 'David R.', 'rating': 3, 'comment': 'Good, but a bit pricey.'},
    {
      'username': 'Emma S.',
      'rating': 5,
      'comment': 'Will definitely hire again!',
    },
    {'username': 'Frank J.', 'rating': 4, 'comment': 'Quick and efficient.'},
    {
      'username': 'Grace L.',
      'rating': 2,
      'comment': 'Took longer than expected.',
    },
    {
      'username': 'Henry B.',
      'rating': 5,
      'comment': 'Exceeded my expectations!',
    },
    {'username': 'Iris P.', 'rating': 4, 'comment': 'Very thorough and tidy.'},
    {
      'username': 'James W.',
      'rating': 1,
      'comment': 'Did not finish the job properly.',
    },
  ];

  // ── Computed values ───────────────────────────────────────────────────────

  double get _average {
    if (_ratings.isEmpty) return 0.0;
    final sum = _ratings.fold<int>(0, (acc, r) => acc + (r['rating'] as int));
    return sum / _ratings.length;
  }

  int _countForStar(int star) =>
      _ratings.where((r) => r['rating'] == star).length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rating Summary'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _ratings.isEmpty
          ? const Center(child: Text('No ratings yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Average score header ─────────────────────────────────
                _AverageScoreCard(
                  average: _average,
                  totalCount: _ratings.length,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),

                const SizedBox(height: 16),

                // ── Per-star breakdown ───────────────────────────────────
                _BreakdownCard(
                  ratingCounts: {
                    for (int s = 5; s >= 1; s--) s: _countForStar(s),
                  },
                  totalCount: _ratings.length,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),

                const SizedBox(height: 16),

                // ── Individual review cards ──────────────────────────────
                Text(
                  'All Reviews',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._ratings.reversed.map(
                  (r) => _ReviewCard(
                    username: r['username'] as String,
                    rating: r['rating'] as int,
                    comment: r['comment'] as String,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

/// Large card at the top showing the numeric average and star row.
class _AverageScoreCard extends StatelessWidget {
  const _AverageScoreCard({
    required this.average,
    required this.totalCount,
    required this.colorScheme,
    required this.textTheme,
  });

  final double average;
  final int totalCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              'Overall Rating',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              average.toStringAsFixed(1),
              style: textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                fontSize: 72,
              ),
            ),
            const SizedBox(height: 8),
            _StarRow(rating: average, size: 36, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              '$totalCount ${totalCount == 1 ? 'review' : 'reviews'}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card showing horizontal bars for each star level (5 → 1).
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.ratingCounts,
    required this.totalCount,
    required this.colorScheme,
    required this.textTheme,
  });

  final Map<int, int> ratingCounts;
  final int totalCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rating Breakdown',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (int star = 5; star >= 1; star--)
              _BreakdownRow(
                star: star,
                count: ratingCounts[star] ?? 0,
                total: totalCount,
                barColor: colorScheme.primary,
                textTheme: textTheme,
              ),
          ],
        ),
      ),
    );
  }
}

/// Single row: "5 ★ ████░░░ 3"
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.star,
    required this.count,
    required this.total,
    required this.barColor,
    required this.textTheme,
  });

  final int star;
  final int count;
  final int total;
  final Color barColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Star label
          Text('$star', style: textTheme.bodySmall),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: barColor.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Count label
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              style: textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card for one individual review entry.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.username,
    required this.rating,
    required this.comment,
    required this.colorScheme,
    required this.textTheme,
  });

  final String username;
  final int rating;
  final String comment;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.person,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StarRow(
                    rating: rating.toDouble(),
                    size: 18,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 6),
                  Text(comment, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders filled/half/empty stars for a given [rating] value.
class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.rating,
    required this.size,
    required this.color,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i + 1 <= rating;
        final half = !filled && i < rating && rating - i >= 0.5;
        return Icon(
          filled
              ? Icons.star
              : half
              ? Icons.star_half
              : Icons.star_border,
          color: color,
          size: size,
        );
      }),
    );
  }
}
