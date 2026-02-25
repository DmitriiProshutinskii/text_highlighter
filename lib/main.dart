import 'package:flutter/material.dart';
import 'package:flutter_highlighter/highlighter/text_with_highlight.dart';

void main() {
  runApp(const HighlightDemoApp());
}

class HighlightDemoApp extends StatelessWidget {
  const HighlightDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Highlighted Segments Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HighlightDemoPage(),
    );
  }
}

class HighlightDemoPage extends StatefulWidget {
  const HighlightDemoPage({super.key});

  @override
  State<HighlightDemoPage> createState() => _HighlightDemoPageState();
}

class _HighlightDemoPageState extends State<HighlightDemoPage> {
  final TextEditingController _segmentsController = TextEditingController(
    text: 'Hello world.\nI am a developer that will highlight this text.',
  );
  final TextEditingController _highlightIndexesController =
      TextEditingController(text: '1');

  double _fontSize = 26;
  String _selectedColorName = 'Red';

  final Map<String, Color> _highlightColors = const {
    'Red': Colors.red,
    'Green': Colors.green,
    'Blue': Colors.blue,
    'Orange': Colors.orange,
    'Purple': Colors.purple,
  };

  @override
  void dispose() {
    _segmentsController.dispose();
    _highlightIndexesController.dispose();
    super.dispose();
  }

  List<String> get _textSegments {
    final segmentLines = _segmentsController.text.split('\n');
    if (segmentLines.isEmpty) {
      return [''];
    }
    return segmentLines;
  }

  List<int> get _highlightedSegmentIndexes {
    final segmentCount = _textSegments.length;
    return _highlightIndexesController.text
        .split(',')
        .map((rawIndex) => int.tryParse(rawIndex.trim()))
        .whereType<int>()
        .where((index) => index >= 0 && index < segmentCount)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: 1.4,
      color: Colors.black,
    );
    final highlightColor = _highlightColors[_selectedColorName] ?? Colors.red;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: HighlightedSegmentsText(
                    textSegments: _textSegments,
                    highlightedSegmentIndexes: _highlightedSegmentIndexes,
                    textStyle: textStyle,
                    highlightColor: highlightColor.withAlpha(200),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Font size: ${_fontSize.toStringAsFixed(0)}'),
                    Slider(
                      min: 12,
                      max: 56,
                      value: _fontSize,
                      onChanged: (value) {
                        setState(() {
                          _fontSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedColorName,
                      decoration: const InputDecoration(
                        labelText: 'Highlight color',
                        border: OutlineInputBorder(),
                      ),
                      items: _highlightColors.keys
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedColorName = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _segmentsController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Text segments (one segment per line)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _highlightIndexesController,
                      decoration: const InputDecoration(
                        labelText:
                            'Highlighted segment indexes (comma separated)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
