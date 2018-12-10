library flutter_sudoku_board;

/**
 * Note: get sudoku solution input it here https://anysudokusolver.com/
 * and run in console: var vals = ''; $('table td input').each((i, e) => {vals += e.value;}); console.log(vals);
 *
 * Still deciding if solver should be part of this script, only Dart sudoku solver at the moment is not compatible with Dart 2
 */

import 'dart:collection';
import 'dart:math' as Math;
import 'package:flutter/material.dart';

Cell selected;
List<CellData> boardData = [];
List<SudokuBoardHistoryRecord> history = [];

class SudokuBoardHistoryRecord {
  String values;
  List<SplayTreeSet<String>> notes;

  SudokuBoardHistoryRecord(this.values, this.notes);
}

class CellData {
  String _origValue;
  String _correctValue;
  String _value;
  SplayTreeSet<String> notes = new SplayTreeSet();
  bool readOnly;
  bool isCorrect = false;

  CellData(String val, { String correctValue, List<String> notes }) {
    _origValue = val;
    _correctValue = correctValue;
    value = val;
    readOnly = _origValue != '.';

    if (notes != null && notes.length > 0){
      this.notes = SplayTreeSet.from(notes);
    }
  }

  String get value => _value;

  set value(String val){
    _value = (val == '.') ? '' : val;
  }

  bool updateValue(String val) {
    if (readOnly) {
      return false;
    }

    value = (val == value) ? '' : val;

    isCorrect = (val == _correctValue);
    _updateNotesOnNumberInput();

    return true;
  }

  bool updateNote(String val){
    if (readOnly || value != '') {
      return false;
    }

    return (notes.contains(val))
        ? notes.remove(val)
        : notes.add(val);
  }

  reset(){
    if (readOnly) {
      return;
    }

    value = _origValue;
    notes = new SplayTreeSet();
  }

  _updateNotesOnNumberInput() {
    List<int> affectedIndexes = List.generate(9, (i) => i + ((selected.row * 9) - 1) + 1)
      ..addAll(List.generate(9, (i) => (i * 9) + selected.col));

    boardData.asMap().forEach((index, cellData) {
      if (affectedIndexes.contains(index)){
        cellData.notes.remove(value);
      }
    });
  }

  @override
  String toString() {
    return (value == '') ? '.' : value;
  }
}

class SudokuBoardController {
  SudokuBoardController({
    this.historyMax: 10
  });

  final int historyMax;
  Function boardRefresh = (){};

  onNumberInput(int number) {
    if (selected == null) {
      return;
    }

    CellData cellData = boardData[(selected.row * 9) + selected.col];

    _updateHistory();

    if (cellData.updateValue(number.toString())){
      boardRefresh();
    } else {
      // @todo Not ideal... but we need to remove from history what we just added
      history.removeLast();
    }
  }

  onNoteInput(int number) {
    if (selected == null) {
      return;
    }

    CellData cellData = boardData[(selected.row * 9) + selected.col];

    _updateHistory();

    if (cellData.updateNote(number.toString())){
      boardRefresh();
    } else {
      // @todo Not ideal... but we need to remove from history what we just added
      history.removeLast();
    }
  }

  onUndo(){
    selected = null;

    if (history.length == 0) {
      return;
    }

    SudokuBoardHistoryRecord historyRecord = history.removeLast();

    List<String> values = historyRecord.values.split('');

    boardData.asMap().forEach((int i, CellData c){
      c.value = values[i];
      c.notes = historyRecord.notes[i];
    });

    boardRefresh();
  }

  onErase(){
    if (selected == null) {
      return;
    }

    CellData cellData = boardData[(selected.row * 9) + selected.col];
    cellData.reset();

    boardRefresh();
  }

  _updateHistory(){
    if (history.length >= historyMax) {
      history.removeAt(0);
    }

    String values = '';
    List<SplayTreeSet<String>> notes = [];

    boardData.forEach((cellData) {
      // @todo better or not to use StringBuffer?
      // @todo to get values as string we could also do `boardData.join('')` but since we are iterating... ?
      values += cellData.toString();
      notes.add(SplayTreeSet.from(cellData.notes));
    });

    history.add(
        SudokuBoardHistoryRecord(
            values,
            notes
        )
    );
  }
}

class SudokuBoard extends StatefulWidget {
  SudokuBoard({
    Key key,
    this.data,
    this.solution,
    this.controller,
    this.size,
  }) : super(key: key) {
    parseData();
  }

  final String data;
  final String solution;
  final SudokuBoardController controller;
  final double size;

  @override
  _SudokuBoardState createState() => _SudokuBoardState();

  parseData() {
    data.split('').asMap().forEach((index, value) {
      boardData.add(
          CellData(
              value,
              correctValue: (solution.isNotEmpty) ? solution[index] : null
          )
      );
    });
  }
}

class _SudokuBoardState extends State<SudokuBoard> {
  final double marginSize = 3.0;

  @override
  void initState() {
    super.initState();
    widget.controller.boardRefresh = refreshCallback;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.size == null) {
      return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        return Column(
            children: renderRows(getCellSize(Math.min(constraints.maxWidth, constraints.maxHeight) - 2))
        );
      });
    } else {
      return Column(
          children: renderRows(getCellSize(widget.size))
      );
    }
  }

  double getCellSize(boardSize) {
    return (boardSize / 9).floorToDouble() - 1.5;
  }

  EdgeInsets getCellMargin(int x, int y) {
    EdgeInsets margin = EdgeInsets.all(0.3);
    if ([2, 5].contains(y)){
      margin = margin.copyWith(right: marginSize);
    }

    if ([2, 5].contains(x)) {
      margin = margin.copyWith(bottom: marginSize);
    }

    return margin;
  }

  refreshCallback(){
    setState((){});
  }

  renderRows(cellSize) {
    List<Row> rows = [];

    for(int i=0; i < 9; i++){
      List<Cell> cols = [];

      for(int j=0; j < 9; j++){
        int cellIndex = (i * 9) + j;
        CellData cellData = boardData[cellIndex];

        final Cell cell = Cell(
            row: i,
            col: j,
            size: cellSize,
            value: cellData.value,
            notes: (cellData.notes != null) ? cellData.notes.join('') : '',
            readonly: cellData.readOnly,
            isCorrect: cellData.isCorrect,
            margin: getCellMargin(i, j),
            boardRefresh: refreshCallback
        );

        cols.add(cell);
      }
      rows.add(Row(children: cols, mainAxisAlignment: MainAxisAlignment.center));
    }
    return rows;
  }
}

class Cell extends StatefulWidget {
  Cell({
    Key key,
    this.row,
    this.col,
    this.size,
    this.value,
    this.notes,
    this.readonly,
    this.isCorrect,
    this.margin,
    this.boardRefresh
  }): super(key: key) {
    hash = '$row$col';
  }

  final int row;
  final int col;
  final double size;
  final String value;
  final String notes;
  final bool readonly;
  final bool isCorrect;
  final EdgeInsets margin;
  final boardRefresh;
  String hash;

  @override
  CellState createState() => CellState();
}

class CellState extends State<Cell> {
  Color bgColor;
  Color textColor;
  List<String> notes = [];

  @override
  Widget build(BuildContext context) {
    bgColor = Colors.white;
    textColor = Colors.black;

    bool isSelected = selected != null && selected.hash == widget.hash;

    if (widget.readonly){
      textColor = Colors.black;
    } else if(!widget.isCorrect) {
      textColor = Color(0xFFE74252);
    } else {
      textColor = Color(0xFF4F8CF7);
    }

    if (selected != null){
      if(isSelected) {
        bgColor = Color(0xFF43DEFC);
        textColor = Colors.white;
      } else if (widget.row == selected.row || widget.col == selected.col) {
        bgColor = Color(0xFFEFF8FF);
      }
    }

    renderCellText() {
      double notesFontSize = (widget.notes != null && widget.notes.length > 6)
          ? widget.size * 0.25
          : widget.size * 0.35;

      return (widget.value == '' && widget.notes != '')
          ? Container(
          padding: EdgeInsets.all(3.0),
          alignment: AlignmentDirectional.bottomEnd,
          child:Text(widget.notes, style: TextStyle(
              letterSpacing: 2.0,
              color: Colors.black54,
              fontSize: notesFontSize),
              textAlign: TextAlign.end
          ))
          : Container(
          alignment: AlignmentDirectional.center,
          child: Text(widget.value, style: TextStyle(
              color: textColor,
              fontSize: widget.size * 0.70)
          ));
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        color: bgColor,
        margin: widget.margin,
        child: renderCellText(),
      ),
    );
  }

  onTap(){
    selected = (selected != null && selected.hash == widget.hash) ? null : widget;
    widget.boardRefresh();
  }
}
