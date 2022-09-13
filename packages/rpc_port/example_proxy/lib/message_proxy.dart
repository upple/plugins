import 'dart:async';

import 'package:rpc_port/tizen_rpc_port.dart';
import 'package:tizen_log/tizen_log.dart';

const _logTag = 'RPC_PORT_PROXY';
const _tidlVersion = '1.9.1';

enum _DelegateId {
  notifyCB(1);

  const _DelegateId(this.id);
  final int id;
}

enum _MethodId {
  result(0),
  callback(1),
  register(2),
  unregister(3),
  send(4);

  const _MethodId(this.id);
  final int id;
}

abstract class CallbackBase extends Parcelable {
  int id = 0;
  bool once = false;
  int seqId = 0;
  static int _seqNum = 0;

  CallbackBase(this.id, this.once) {
    seqId = _seqNum++;
  }

  CallbackBase.fromParcel(Parcel parcel) {
    deserialize(parcel);
  }

  String get tag => '$id::$seqId';

  void _onReceivedEvent(Parcel parcel);

  @override
  void serialize(Parcel parcel) {
    parcel.writeInt32(id);
    parcel.writeInt32(seqId);
    parcel.writeBool(once);
  }

  @override
  void deserialize(Parcel parcel) {
    id = parcel.readInt32();
    seqId = parcel.readInt32();
    once = parcel.readBool();
  }
}

abstract class NotifyCB extends CallbackBase {
  NotifyCB({bool once = false}) : super(_DelegateId.notifyCB.id, once);

  /// virtual fucntion
  Future<void> onReceived(String sender, String msg);

  @override
  void _onReceivedEvent(Parcel parcel) async {
    String sender = parcel.readString();
    String msg = parcel.readString();

    onReceived(sender, msg);
  }
}

abstract class Message extends ProxyBase {
  bool _online = false;
  final List<CallbackBase> _delegateList = <CallbackBase>[];

  Message(String appid) : super(appid, 'Message');

  /// virtual fucntion
  void onConnected();
  void onDisconnected();
  void onRejected();

  @override
  Future<void> onConnectedEvent(String appid, String portName) async {
    _online = true;
    onConnected();
  }

  @override
  Future<void> onDisconnectedEvent(String appid, String portName) async {
    _online = false;
    onDisconnected();
  }

  @override
  Future<void> onRejectedEvent(String appid, String portName) async {
    onRejected();
  }

  @override
  Future<void> onReceivedEvent(
      String appid, String portName, Parcel parcel) async {
    final int cmd = parcel.readInt32();
    if (cmd != _MethodId.callback.id) {
      parcel.dispose();
      return;
    }

    _processReceivedEvent(parcel);
  }

  void _processReceivedEvent(Parcel parcel) {
    final int id = parcel.readInt32();
    final int seqId = parcel.readInt32();
    final bool once = parcel.readBool();

    for (final CallbackBase delegate in _delegateList) {
      if (delegate.id == id && delegate.seqId == seqId) {
        delegate._onReceivedEvent(parcel);
        if (delegate.once) {
          _delegateList.remove(delegate);
        }
        break;
      }
    }
  }

  Future<Parcel> _consumeCommand(Port port) async {
    do {
      try {
        final Parcel parcel = await port.receive();
        final int cmd = parcel.readInt32();
        if (cmd == _MethodId.result.id) {
          return parcel;
        }

        parcel.dispose();
      } catch (e) {
        Log.error(_logTag, e.toString());
        return Parcel();
      }
    } while (true);
  }

  void disposeCallback(String tag) {
    _delegateList.removeWhere((CallbackBase element) => element.tag == tag);
  }

  Future<int> register(String name, NotifyCB cb) async {
    Log.info(_logTag, 'register');

    if (!_online) {
      throw Exception('NotConnectedSocketException');
    }

    final Parcel parcel = Parcel();
    final ParcelHeader header = parcel.getHeader();
    header.tag = _tidlVersion;
    parcel.writeInt32(_MethodId.register.id);

    parcel.writeString(name);
    cb.serialize(parcel);
    _delegateList.add(cb);

    final Port port = getPort(PortType.main);
    await port.send(parcel);
    parcel.dispose();

    late Parcel parcelReceived;
    do {
      parcelReceived = await _consumeCommand(port);
      final ParcelHeader headerReceived = parcelReceived.getHeader();
      if (headerReceived.tag.isEmpty) {
        break;
      } else if (headerReceived.sequenceNumber == header.sequenceNumber) {
        break;
      }

      parcelReceived.dispose();
    } while (true);

    final ret = parcelReceived.readInt32();

    parcelReceived.dispose();
    return ret;
  }

  Future<void> unregister() async {
    Log.info(_logTag, 'unregister');

    if (!_online) {
      throw Exception('NotConnectedSocketException');
    }

    final Parcel parcel = Parcel();
    final ParcelHeader header = parcel.getHeader();
    header.tag = _tidlVersion;
    parcel.writeInt32(_MethodId.unregister.id);

    final Port port = getPort(PortType.main);
    await port.send(parcel);
    parcel.dispose();
  }

  Future<int> send(String msg) async {
    Log.info(_logTag, 'send');

    if (!_online) {
      throw Exception('NotConnectedSocketException');
    }

    final Parcel parcel = Parcel();
    final ParcelHeader header = parcel.getHeader();
    header.tag = _tidlVersion;
    parcel.writeInt32(_MethodId.send.id);

    parcel.writeString(msg);

    final Port port = getPort(PortType.main);
    await port.send(parcel);
    parcel.dispose();

    late Parcel parcelReceived;
    do {
      parcelReceived = await _consumeCommand(port);
      final ParcelHeader headerReceived = parcelReceived.getHeader();
      if (headerReceived.tag.isEmpty) {
        break;
      } else if (headerReceived.sequenceNumber == header.sequenceNumber) {
        break;
      }

      parcelReceived.dispose();
    } while (true);

    final ret = parcelReceived.readInt32();

    parcelReceived.dispose();
    return ret;
  }
}
