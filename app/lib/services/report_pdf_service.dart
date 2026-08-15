import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/app_models.dart';
import '../state/app_controller.dart';

enum ReportGroupBy { daily, monthly }

const _navy       = PdfColor.fromInt(0xFF0D1B2A);
const _blue       = PdfColor.fromInt(0xFF1565C0);
const _lightBlue  = PdfColor.fromInt(0xFFE3F2FD);
const _accentBlue = PdfColor.fromInt(0xFF42A5F5);
const _white      = PdfColors.white;
const _borderGrey = PdfColor.fromInt(0xFFDDE3EE);
const _textDark   = PdfColor.fromInt(0xFF0D1B2A);
const _textMid    = PdfColor.fromInt(0xFF4A5568);
const _textLight  = PdfColor.fromInt(0xFF8A9BB0);
const _rowAlt     = PdfColor.fromInt(0xFFF0F4FA);

String _fmt(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
}

String _fmtTs(String? ts) {
  if (ts == null || ts.isEmpty) return 'Never';
  final d = DateTime.tryParse(ts)?.toLocal();
  return d == null ? ts : _fmt(d);
}

String _dur(int s) {
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
  return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
}

String _formatPeriodKey(String key, ReportGroupBy groupBy) {
  if (groupBy == ReportGroupBy.daily) {
    final d = DateTime.tryParse(key);
    return d == null ? key : _fmt(d);
  }
  final parts = key.split('-');
  if (parts.length < 2) return key;
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final month = int.tryParse(parts[1]) ?? 1;
  return '${months[month - 1]} ${parts[0]}';
}

/// Returns total rounds across all screens for a client in the date range.
int _totalRoundsForClient(
  AppController controller,
  String clientId,
  DateTime from,
  DateTime to,
) {
  // Rounds are stored per screen (not per client), so sum rounds for all screens
  // that have at least one media item belonging to this client assigned.
  final clientMediaIds = controller.mediaForClient(clientId).map((m) => m.id).toSet();
  final relevantScreenIds = controller.screens
      .where((s) => s.assignedMediaIds.any(clientMediaIds.contains))
      .map((s) => s.id)
      .toSet();

  var total = 0;
  for (final stat in controller.playbackStats) {
    if (stat.mediaId != '__round__') continue;
    if (!relevantScreenIds.contains(stat.screenId)) continue;
    if (stat.playDate == null) continue;
    final d = DateTime.tryParse(stat.playDate!);
    if (d == null) continue;
    if (d.isBefore(DateTime(from.year, from.month, from.day))) continue;
    if (d.isAfter(DateTime(to.year, to.month, to.day))) continue;
    total += stat.roundCount;
  }
  return total;
}

class ReportPdfService {
  static Future<Uint8List> generateClientReport({
    required ClientProfile client,
    required AppController controller,
    required DateTime startDate,
    required DateTime endDate,
    required ReportGroupBy groupBy,
    Map<String, Uint8List>? videoThumbnails,
  }) async {
    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    try {
      final data = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final screens     = controller.screens;
    final totalRounds = _totalRoundsForClient(controller, client.id, startDate, endOfDay);
    final dateStr     = '${_fmt(startDate)} to ${_fmt(endDate)}';

    // Only media currently assigned to at least one screen (active in playlist)
    final assignedMediaIds = screens.expand((s) => s.assignedMediaIds).toSet();
    final clientMediaIds   = controller.mediaForClient(client.id).map((m) => m.id).toSet();
    final activeMediaIds   = assignedMediaIds.intersection(clientMediaIds);
    final mediaSummaries   = controller
        .mediaSummariesForClient(client.id, from: startDate, to: endOfDay)
        .where((s) => activeMediaIds.contains(s.media.id))
        .toList();

    // Screen breakdown: rounds per screen with date-wise detail
    final screenRows = <({ScreenDevice screen, int rounds, Map<String, int> byDate})>[];
    for (final screen in screens) {
      // Only include screens that have at least one of this client's media assigned
      if (!screen.assignedMediaIds.any(clientMediaIds.contains)) continue;
      final Map<String, int> byDate = {};
      var total = 0;
      for (final stat in controller.playbackStats) {
        if (stat.screenId != screen.id) continue;
        if (stat.mediaId != '__round__') continue;
        if (stat.playDate == null) continue;
        final d = DateTime.tryParse(stat.playDate!);
        if (d == null) continue;
        if (d.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) continue;
        if (d.isAfter(DateTime(endOfDay.year, endOfDay.month, endOfDay.day))) continue;
        byDate[stat.playDate!] = (byDate[stat.playDate!] ?? 0) + stat.roundCount;
        total += stat.roundCount;
      }
      if (total > 0) screenRows.add((screen: screen, rounds: total, byDate: byDate));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        footer: (_) => _footer(),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          widgets.add(_headerBar(logoImage, client, dateStr));
          widgets.add(pw.SizedBox(height: 20));

          widgets.add(_statRow(activeMediaIds.length, totalRounds));
          widgets.add(pw.SizedBox(height: 24));

          // ── SCREEN BREAKDOWN ──────────────────────────────────────────────
          if (screenRows.isNotEmpty) {
            widgets.add(_sectionTitle('SCREEN BREAKDOWN'));
            widgets.add(pw.SizedBox(height: 10));

            for (final row in screenRows) {
              final sortedDates = row.byDate.keys.toList()..sort();
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderGrey, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const pw.BoxDecoration(
                        color: _navy,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(6),
                          topRight: pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${row.screen.name}${row.screen.location.isNotEmpty ? '  •  ${row.screen.location}' : ''}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _white),
                            ),
                          ),
                          pw.Text(
                            '${row.rounds} rounds total',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _accentBlue),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Table.fromTextArray(
                        headers: ['DATE', 'ROUNDS'],
                        data: sortedDates
                            .map((d) => [_formatPeriodKey(d, ReportGroupBy.daily), '${row.byDate[d]}'])
                            .toList(),
                        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _white),
                        headerDecoration: const pw.BoxDecoration(color: _blue),
                        cellStyle: const pw.TextStyle(fontSize: 9, color: _textDark),
                        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
                        border: pw.TableBorder.all(color: _borderGrey, width: 0.4),
                        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
                        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      ),
                    ),
                  ],
                ),
              ));
            }
            widgets.add(pw.SizedBox(height: 14));
          }

          // ── MEDIA BREAKDOWN ───────────────────────────────────────────────
          widgets.add(_sectionTitle('MEDIA BREAKDOWN'));
          widgets.add(pw.SizedBox(height: 10));

          for (int i = 0; i < mediaSummaries.length; i++) {
            final summary = mediaSummaries[i];
            final item    = summary.media;

            // Screens that currently have this video assigned
            final assignedScreenRows = screenRows
                .where((r) => r.screen.assignedMediaIds.contains(item.id))
                .toList();

            // Per-screen line: rounds in range + last activity from screen record
            final screenLines = <String>[];
            for (final row in assignedScreenRows) {
              final last = row.screen.lastPlaybackAt;
              screenLines.add(
                '${row.screen.name}: ${row.rounds} rounds  |  last: ${_fmtTs(last)}',
              );
            }

            // Period breakdown: sum rounds across all screens that have this video,
            // grouped by day or month
            final Map<String, int> periodRounds = {};
            for (final row in assignedScreenRows) {
              for (final entry in row.byDate.entries) {
                final raw    = entry.key;
                final parsed = DateTime.tryParse(raw);
                if (parsed == null) continue;
                final key = groupBy == ReportGroupBy.daily
                    ? raw
                    : '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
                periodRounds[key] = (periodRounds[key] ?? 0) + entry.value;
              }
            }

            // Fill in zero-count periods
            if (groupBy == ReportGroupBy.daily) {
              DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);
              final last = DateTime(endDate.year, endDate.month, endDate.day);
              while (!cursor.isAfter(last)) {
                final key = '${cursor.year}-${cursor.month.toString().padLeft(2,'0')}-${cursor.day.toString().padLeft(2,'0')}';
                periodRounds.putIfAbsent(key, () => 0);
                cursor = cursor.add(const Duration(days: 1));
              }
            } else {
              DateTime cursor = DateTime(startDate.year, startDate.month, 1);
              final last = DateTime(endDate.year, endDate.month, 1);
              while (!cursor.isAfter(last)) {
                final key = '${cursor.year}-${cursor.month.toString().padLeft(2,'0')}';
                periodRounds.putIfAbsent(key, () => 0);
                cursor = DateTime(cursor.year, cursor.month + 1, 1);
              }
            }

            final sortedPeriods = periodRounds.keys.toList()..sort();

            widgets.add(pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: _navy,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item.kind == MediaKind.video ? 'VIDEO' : 'IMAGE'} ${i + 1}    ${item.title}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _white),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        '${_dur(summary.playTimeSeconds)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _accentBlue),
                      ),
                    ],
                  ),
                ),
                if (screenLines.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: screenLines
                          .map((line) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 4),
                                child: pw.Text(line,
                                    style: const pw.TextStyle(fontSize: 9, color: _textDark)),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ));

            if (sortedPeriods.isNotEmpty) {
              widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: pw.Text(
                  groupBy == ReportGroupBy.daily ? 'Daily Rounds' : 'Monthly Rounds',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textMid),
                ),
              ));
              widgets.add(pw.SizedBox(height: 6));
              widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: pw.Table.fromTextArray(
                  headers: [groupBy == ReportGroupBy.daily ? 'DATE' : 'MONTH', 'ROUNDS'],
                  data: sortedPeriods
                      .map((k) => [_formatPeriodKey(k, groupBy), '${periodRounds[k]}'])
                      .toList(),
                  headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _white),
                  headerDecoration: const pw.BoxDecoration(color: _blue),
                  cellStyle: const pw.TextStyle(fontSize: 9, color: _textDark),
                  oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
                  border: pw.TableBorder.all(color: _borderGrey, width: 0.4),
                  cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                ),
              ));
            }

            widgets.add(pw.SizedBox(height: 14));
          }

          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _lightBlue,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'This report provides the summary of TV advertisement playback across screens during the selected period.',
                    style: const pw.TextStyle(fontSize: 9, color: _textMid),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Thank you!',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
                    pw.Text('for choosing Brand Slots',
                        style: pw.TextStyle(fontSize: 9, color: _blue)),
                  ],
                ),
              ],
            ),
          ));

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _headerBar(pw.ImageProvider? logo, ClientProfile client, String dateStr) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 180,
          color: _white,
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Image(logo, width: 80, height: 44, fit: pw.BoxFit.contain)
              else
                pw.Text('BRAND SLOTS',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(height: 8),
              pw.Text('THE SMARTEST WAY TO GROW YOUR BRAND',
                  style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _textMid)),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            color: _navy,
            padding: const pw.EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('TV ADVERTISEMENT',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _white)),
                pw.Text('PLAYBACK REPORT',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _accentBlue)),
                pw.SizedBox(height: 12),
                pw.Text('PERIOD: $dateStr',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _accentBlue)),
                pw.SizedBox(height: 4),
                pw.Text('CLIENT: ${client.name}',
                    style: const pw.TextStyle(fontSize: 9, color: _white)),
                if (client.contactName.isNotEmpty)
                  pw.Text('CONTACT: ${client.contactName}',
                      style: const pw.TextStyle(fontSize: 9, color: _white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _statRow(int mediaCount, int rounds) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          _statCell('ACTIVE VIDEOS', '$mediaCount'),
          pw.Container(width: 0.8, height: 50, color: _borderGrey),
          _statCell('TOTAL ROUNDS', '$rounds'),
        ],
      ),
    );
  }

  static pw.Widget _statCell(String label, String value) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _textMid)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _textDark)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 18, color: _blue),
        pw.SizedBox(width: 8),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _textDark)),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('+91 7356 506 639', style: const pw.TextStyle(fontSize: 8, color: _white)),
          pw.Text('+91 8593 945 350', style: const pw.TextStyle(fontSize: 8, color: _white)),
          pw.Text('Ads.brandslots@gmail.com', style: const pw.TextStyle(fontSize: 8, color: _white)),
          pw.Text('brand_slots_', style: const pw.TextStyle(fontSize: 8, color: _white)),
          pw.Text('Brand Slots', style: const pw.TextStyle(fontSize: 8, color: _white)),
        ],
      ),
    );
  }
}
