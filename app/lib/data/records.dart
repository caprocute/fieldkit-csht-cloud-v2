import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:fk_data_protocol/fk-data.pb.dart' as proto;
import 'package:intl/intl.dart';

import '../diagnostics.dart';
import 'paths.dart';

abstract class Visitor {
  Future<void> visitRecord(proto.DataRecord record, double progress);
}

// Visits records that have been synced to the phone from a device. Uses include
// export/diagnostics/charting/etc...
class RecordWalker {
  final String deviceId;

  RecordWalker({required this.deviceId});

  Stream<double> walkAll(Visitor visitor) async* {
    final files = await Paths.findDataFiles(deviceId);
    final totalBytes = files.map((file) => file.size).sum;

    int bytesProcessed = 0;
    int records = 0;
    for (final file in files) {
      final opening = File(file.path);
      final reading = opening.openRead();

      Loggers.state.i("${file.meta} length=${file.size}");

      // Buffered holds left over data, since we're reading 65k chunks sometimes
      // records will span those chunks and so we keep the end of the previous chunk
      // around.
      final List<int> buffered = List.empty(growable: true);
      await for (final data in reading) {
        // Append to buffered data, so we can parse whatever was left over.
        buffered.addAll(data);

        // Parse as many records as we can from this chunk.
        RecordReader messages = RecordReader(buffered);
        while (true) {
          final buffer = messages.readRecord();
          if (buffer == null) {
            // We failed to read a record, so add whatever's left over to the
            // buffered array.
            buffered.clear();
            buffered.addAll(messages.remainder());
            bytesProcessed += messages.position();
            break;
          }

          final proto.DataRecord record = proto.DataRecord.fromBuffer(buffer);
          final bytes = (bytesProcessed + messages.position());
          final progress = bytes / totalBytes;
          await visitor.visitRecord(record, progress);

          records += 1;

          if (records % 100 == 0) {
            yield progress;
          }
        }
      }

      if (buffered.isNotEmpty) {
        Loggers.state.w("${file.meta} extra ${buffered.length} bytes of data!");
      }
    }

    Loggers.state.i("done!");
  }
}

// I tried to accomplish this with CodedBufferReader and kept running into
// snags. Specifically being able to handle records across boundaries.
class RecordReader {
  final Uint8List _buffer;
  int _bufferPos = 0;
  int _currentLimit = -1;

  RecordReader(List<int> buffer)
      : _buffer = buffer is Uint8List ? buffer : Uint8List.fromList(buffer) {
    _currentLimit = buffer.length;
  }

  Uint8List? readRecord() {
    final length = _peekRawVarint32(false);
    if (length == null) {
      return null;
    }
    if (_bufferPos + length.bytes + length.value > _currentLimit) {
      return null;
    }
    _bufferPos += length.bytes;
    _bufferPos += length.value;
    return Uint8List.view(_buffer.buffer,
        _buffer.offsetInBytes + _bufferPos - length.value, length.value);
  }

  Uint8List remainder() {
    return Uint8List.view(_buffer.buffer, _buffer.offsetInBytes + _bufferPos);
  }

  int position() {
    return _bufferPos;
  }

  PeekedVarint? _peekRawVarint32(bool signed) {
    // Read up to 10 bytes.
    // We use a local [bufferPos] variable to avoid repeatedly loading/store the
    // this._bufferpos field.
    var bufferPos = _bufferPos;
    var bytes = _currentLimit - bufferPos;
    if (bytes > 10) bytes = 10;
    var result = 0;
    for (var i = 0; i < bytes; i++) {
      final byte = _buffer[bufferPos++];
      result |= (byte & 0x7f) << (i * 7);
      if ((byte & 0x80) == 0) {
        result &= 0xffffffff;
        return PeekedVarint(
          value: signed ? result - 2 * (0x80000000 & result) : result,
          bytes: bufferPos - _bufferPos,
        );
      }
    }
    return null;
  }
}

class PeekedVarint {
  final int value;
  final int bytes;

  PeekedVarint({required this.value, required this.bytes});
}

String newTimeId() {
  final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
  final now = DateTime.now();
  return formatter.format(now);
}
