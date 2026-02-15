# Алгоритм мягкой обводки текста (Flutter/Dart)

Ниже — разбор алгоритма, который рисует аккуратную "плашку" под выделенным текстом, даже если текст переносится на несколько строк.  
Пример кода в проекте сделан на Flutter, но сама идея не привязана к Dart.

---

## Где это в коде

- Получение прямоугольников выделения: `calculateHighlightBoundsPerLine()` в `lib/highlighter/shared/get_position_per_line.dart`.
- Нормализация "особого" случая по строкам: `_buildHighlightBounds()` в `lib/highlighter/text_with_highlight.dart`.
- Построение контура через матрицу: `_buildContourPoints()` в `lib/highlighter/helpers/highlighted_text.dart`.
- Скругление углов и векторное произведение: `_roundContourCorners()` в `lib/highlighter/helpers/highlighted_text.dart`.
- Финальная отрисовка path и текста поверх: `HighlightContourPainter.paint()` и `HighlightedSegmentsText.build()`.

---

## Что хотим получить

- Выделение должно идти по контуру текста, а не простым прямоугольником.
- На стыках строк не должно быть ломаных "ступенек".
- Углы должны быть скруглены, чтобы форма выглядела естественно.

![Result](Images/Result.png)

---

## 1) Получаем геометрию выделяемого фрагмента

Сначала превращаем массив сегментов в единый `TextSpan`, отрисовываем его через `TextPainter`, и вычисляем диапазон символов для нужного сегмента.

![Calc](Images/Calc.png)

```dart
final textPainter = TextPainter(
  text: TextSpan(children: inlineSpans),
  textDirection: textDirection,
)..layout(maxWidth: maxWidth);

int selectionStart = 0;
for (int i = 0; i < segmentIndex; i++) {
  selectionStart += textSegments[i].length;
}
final int selectionEnd = selectionStart + textSegments[segmentIndex].length;
```

Для индексов работает простая формула:

$$
s_i = \sum_{k=0}^{i-1} |t_k|,\quad
e_i = s_i + |t_i|
$$

где:

- \(t_i\) — i-й текстовый сегмент,
- \(s_i\) — начало сегмента в общей строке,
- \(e_i\) — конец сегмента.

Дальше используем `getBoxesForSelection`:

```dart
final selectionBoxes = textPainter.getBoxesForSelection(
  TextSelection(baseOffset: selectionStart, extentOffset: selectionEnd),
);
```

Если боксы есть — конвертируем их в `HighlightBounds`.  
Если нет (редкий крайний случай) — берем `caret`-позиции начала/конца и строим fallback-контур.

---

## 2) Нормализуем особый кейс с "уехавшим" первым боксом

Иногда первый бокс может оказаться правее, чем ожидается относительно следующей строки.  
В проекте это правится простым эвристическим правилом: разбиваем группу на две.

![Case](Images/Result2.png)

```dart
if (boundsGroup.length > 1 &&
    boundsGroup[0].startX > (boundsGroup[1].endX - 10)) {
  normalizedBoundsGroups.add([boundsGroup[0]]);
  boundsGroup.removeAt(0);
  normalizedBoundsGroups.add(boundsGroup);
}
```

Практически это убирает артефакты в переходах между строками.

---

## 3) Строим контур через матрицу точек

Идея: собрать все узловые точки боксов в "таблицу" координат и пройти ее по периметру по часовой стрелке.

![Matrix](Images/TextBoxes.png)

### 3.1 Уникальные оси X и Y

Берем все `x` и `y` из прямоугольников, оставляем уникальные и сортируем:

$$
X = \mathrm{sort}\left(\mathrm{unique}(\{x_{left}, x_{right}\})\right),\quad
Y = \mathrm{sort}\left(\mathrm{unique}(\{y_{top}, y_{bottom}\})\right)
$$

Размер матрицы:

$$
|Y| \times |X|
$$

В коде:

```dart
final uniqueXList = uniqueX.toList()..sort();
final uniqueYList = uniqueY.toList()..sort();

final List<List<Offset?>> matrix = List.generate(
  uniqueYList.length,
  (index) => List.generate(uniqueXList.length, (index) => null),
);
```

### 3.2 Заполнение матрицы

Для каждой точки каждого бокса ищем индекс по `x` и `y`, после чего кладем ее в `matrix[yIndex][xIndex]`.

### 3.3 Обход по часовой стрелке

Контур собирается так:

1. Верхняя грань: слева направо.
2. Правая грань: сверху вниз.
3. Нижняя грань: справа налево.
4. Левая грань: снизу вверх.

Формально:

$$
P = T \,\Vert\, R \,\Vert\, B \,\Vert\, L
$$

где \(T, R, B, L\) — списки точек соответствующих сторон, а \(\Vert\) — конкатенация.

### 3.4 Выравниваем переходы на боковых гранях

Когда соседние точки на правой/левой стороне имеют разный `dx`, вертикальный переход может получиться "косым".  
Поэтому `dy` усредняется попарно:

$$
\Delta = \frac{|y_{i+1} - y_i|}{2}
$$

Для правой стороны:

$$
y_i' = y_i + \Delta,\quad y_{i+1}' = y_{i+1} - \Delta
$$

Для левой — зеркально:

$$
y_i' = y_i - \Delta,\quad y_{i+1}' = y_{i+1} + \Delta
$$

### 3.5 Чистим лишние точки

- Удаляем дубликаты.
- Удаляем точки, лежащие на одной прямой:
  - если \(x_{i-1}=x_i=x_{i+1}\), точка не нужна;
  - если \(y_{i-1}=y_i=y_{i+1}\), точка не нужна.

После этого остаются в основном угловые вершины контура.

---

## 4) Скругляем углы через векторы

![Round](Images/Rounded.png)

Для каждой вершины \(p_i\) берем соседние точки \(p_{i-1}\) и \(p_{i+1}\), считаем два единичных вектора:

$$
\hat{v}_{prev} = \frac{p_{i-1} - p_i}{\|p_{i-1} - p_i\|},\quad
\hat{v}_{next} = \frac{p_{i+1} - p_i}{\|p_{i+1} - p_i\|}
$$

Радиус ограничиваем сверху базовым значением и снизу геометрией отрезка:

$$
r = \min\left(r_0,\ \frac{\|p_{i+1} - p_i\|}{2}\right),\quad r_0 = 6
$$

Строим две точки рядом с углом:

$$
p_{closePrev} = p_i + r \cdot \hat{v}_{prev},\quad
p_{closeNext} = p_i + r \cdot \hat{v}_{next}
$$

В коде это выглядит так:

```dart
final prevVector = (prevPoint - point).normalized();
final nextVector = (nextPoint - point).normalized();
final radius = min(6.0, (nextPoint - point).length / 2);

final pointCloseToNext = (nextVector * radius) + point;
final pointCloseToPrev = (prevVector * radius) + point;
```

---

## 5) Определяем направление дуги через векторное произведение

Нужно понять, как рисовать `arcToPoint`: по или против часовой.

Берем:

$$
a = p_i - p_{closePrev},\quad
b = p_{closeNext} - p_{closePrev}
$$

2D-векторное произведение (z-компонента):

$$
b \times a = b_x a_y - b_y a_x
$$

Если знак положительный — поворот считаем "clockwise" (в терминах внутренней геометрии контура), иначе — обратный.

```dart
final vectorToCurrent = point - pointCloseToPrev;
final vectorToNext = pointCloseToNext - pointCloseToPrev;
final crossProduct = vectorToNext.cross(vectorToCurrent);
final isClockwise = crossProduct > 0;
```

> Важно: в экранных координатах Flutter ось \(Y\) направлена вниз, поэтому при передаче флага в `arcToPoint` в коде используется инверсия (`clockwise: ... != true`), чтобы визуально дуга закручивалась правильно.

---

## 6) Рисуем итоговый путь

После скругления получаем пары точек:  
`(точка_входа_в_угол, флаг_направления)` и `(точка_выхода_из_угла, null)`.

Дальше:

1. `moveTo` в первую точку.
2. Рисуем первую дугу.
3. В цикле: `lineTo` до следующего угла -> `arcToPoint`.
4. `close()` и `drawPath()`.

```dart
path.moveTo(roundedContourPoints.first.$1.dx, roundedContourPoints.first.$1.dy);
drawArc(0);
for (int i = 2; i < roundedContourPoints.length; i = i + 2) {
  path.lineTo(roundedContourPoints[i].$1.dx, roundedContourPoints[i].$1.dy);
  drawArc(i);
}
path.close();
canvas.drawPath(path, Paint()..color = highlightColor);
```

---

## 7) Текст рисуем поверх контура

Контур и текст складываются в `Stack`: сначала `CustomPaint`, затем `RichText`.

```dart
Stack(
  children: [
    CustomPaint(...),
    IgnorePointer(
      ignoring: true,
      child: RichText(text: ...),
    ),
  ],
)
```

Так мы получаем аккуратную цветную подложку и тот же текст сверху.

---

## Короткий итог алгоритма

1. Из текста получаем `TextBox`-прямоугольники выделяемого сегмента.
2. Нормализуем особые случаи многострочных переходов.
3. По уникальным `x/y` строим матрицу и обходим ее по периметру по часовой стрелке.
4. Чистим дубликаты и коллинеарные точки.
5. Скругляем углы через единичные векторы и ограниченный радиус.
6. Направление дуги определяем знаком векторного произведения.
7. Рисуем путь и накладываем текст сверху.

---

## Что можно улучшить дальше

- Разделить стили обычного и выделенного текста без расхождения метрик.
- Кэшировать рассчитанный контур, чтобы не пересчитывать его на каждый `build`.
- Улучшить объединение "особых" групп, чтобы сохранять больше семантики цельного блока.

