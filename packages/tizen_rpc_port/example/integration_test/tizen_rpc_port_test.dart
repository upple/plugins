// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tizen_rpc_port/tizen_rpc_port.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Parcel test', (WidgetTester tester) async {
    // These test are based on the example app.
    final Parcel parcel = Parcel();
    parcel.writeChar('a');
    parcel.writeInt32(123);
    parcel.writeString("Hello");
    parcel.writeByte(0x3f);
    parcel.writeDouble(123.4);

    assert(parcel.readChar(), 'a');
    assert(parcel.readInt32(), 123);
    assert(parcel.readString(), "Hello");
    assert(parcel.readByte(), 0x3f);
    assert(parcel.readDouble(), 123.4);
  });
}
