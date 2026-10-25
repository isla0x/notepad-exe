import 'package:flutter_test/flutter_test.dart';
import 'package:notepad_exe/logic/notes.dart';
void main() {
  test('links normalize names, deduplicate and reject invalid file names', () {
    expect(linkedNoteNames('[[장보기]] [[장보기.txt]] [[Trip]] [[trip.txt]] [[bad/name]] [[ ]]'), ['장보기.txt', 'Trip.txt']);
    expect(linkedNoteNames('[[unfinished\nline]] [not a link]'), isEmpty);
  });
}
