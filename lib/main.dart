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
      title: 'TextHighlighted Demo',
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
  final TextEditingController _textsController = TextEditingController(
    text: 'Hello world.\nI am a developer that will highlight this text.',
  );
  final TextEditingController _indexesController = TextEditingController(
    text: '1',
  );

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
    _textsController.dispose();
    _indexesController.dispose();
    super.dispose();
  }

  List<String> get _texts {
    final lines = _textsController.text.split('\n');
    if (lines.isEmpty) {
      return [''];
    }
    return lines;
  }

  List<int> get _indexes {
    final textCount = _texts.length;
    return _indexesController.text
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((index) => index >= 0 && index < textCount)
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
      appBar: AppBar(title: const Text('TextHighlighted Demo')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: TextHighlighted(
                    texts: _texts,
                    indexes: _indexes,
                    style: textStyle,
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
                      controller: _textsController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Texts (one item per line)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _indexesController,
                      decoration: const InputDecoration(
                        labelText: 'Highlighted indexes (comma separated)',
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
