import 'package:flutter/material.dart';

import '../core/brand/brand_colors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/scoring_helper.dart';
import '../models/cliente_score_model.dart';
import 'premium_card.dart';

class ScoreCard extends StatefulWidget {
  const ScoreCard({super.key, required this.scores});

  final ClienteScoreModel scores;

  @override
  State<ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<ScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;
  late final Animation<int> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final target = ScoringHelper.scoreProgress(widget.scores.scoreFinal);
    _progressAnim = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scoreAnim = IntTween(begin: 0, end: widget.scores.scoreFinal).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scores = widget.scores;
    final segmentColor = ScoringHelper.segmentoColor(scores.segmento);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ScoringHelper.segmentoBackground(scores.segmento),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: segmentColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              'SEGMENTO: ${ScoringHelper.segmentoLabel(scores.segmento)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: segmentColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'TU SCORE FINAL',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.muted),
          ),
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (_, __) => Text(
              '${_scoreAnim.value}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: BrandColors.red,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progressAnim.value,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: segmentColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(ScoringHelper.scoreProgress(scores.scoreFinal) * 100).toStringAsFixed(0)}% del máximo (1000)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _ScoreRow(
            label: 'Score Transaccional',
            value: scores.scoreTransaccional,
            max: ScoringHelper.maxTransaccional,
          ),
          _ScoreRow(
            label: 'Score de Campo',
            value: scores.scoreCampo,
            max: ScoringHelper.maxCampo,
            signed: true,
          ),
          const Divider(height: 28),
          const Text(
            'HIPÓTESIS DE CRÉDITO',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Text(
            'Hasta ${Formatters.money(scores.hipotesisCredito)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: BrandColors.ink,
            ),
          ),
          const Text(
            'Monto sugerido según tu score',
            style: TextStyle(fontSize: 12, color: BrandColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.max,
    this.signed = false,
  });

  final String label;
  final int value;
  final int max;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final display = signed && value > 0 ? '+$value' : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            '$display  (${((value / max) * 100).clamp(0, 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
