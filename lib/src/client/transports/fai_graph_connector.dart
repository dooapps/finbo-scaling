import 'dart:async';
import 'dart:ui';

import '../../types/fai_gun.dart';
import '../../types/fai.dart';
import '../flow/fai_event.dart';
import '../flow/fai_process_queue.dart';
import '../graph/fai_graph.dart';

class GunGraphConnectorEventType {
  final GunEvent<GunGraphData, String?, String?> graphData;

  final GunEvent<GunMsg, dynamic, dynamic> receiveMessage;
  final GunEvent<bool, dynamic, dynamic> connection;

  GunGraphConnectorEventType(
      {required this.graphData,
      required this.receiveMessage,
      required this.connection});
}

abstract class GunGraphConnector {
  final String name;
  late bool isConnected;

  late final GunGraphConnectorEventType events;

  late final GunProcessQueue<GunMsg, dynamic, dynamic> inputQueue;

  late final GunProcessQueue<GunMsg, dynamic, dynamic> outputQueue;

  GunGraphConnector({this.name = 'GunGraphConnector'}) {
    isConnected = false;
    inputQueue =
        GunProcessQueue<GunMsg, dynamic, dynamic>(name: '$name.inputQueue');
    outputQueue =
        GunProcessQueue<GunMsg, dynamic, dynamic>(name: '$name.outputQueue');
    events = GunGraphConnectorEventType(
      graphData: GunEvent<GunGraphData, String?, String?>(
          name: '$name.events.graphData'),
      receiveMessage: GunEvent<GunMsg, dynamic, dynamic>(
          name: '$name.events.receiveMessage'),
      connection:
          GunEvent<bool, dynamic, dynamic>(name: '$name.events.connection'),
    );
    events.connection.on(__onConnectedChange);
  }

  GunGraphConnector off(String msgId, [dynamic _, dynamic __]) {
    return this;
  }

  GunGraphConnector sendPutsFromGraph(GunGraph graph) {
    graph.events.put.on(put);
    return this;
  }

  GunGraphConnector sendRequestsFromGraph(GunGraph graph) {
    graph.events.get.on((req, [dynamic _, dynamic __]) {
      get(req);
    });
    return this;
  }

  FutureOr<void> waitForConnection() {
    var completer = Completer<void>();

    if (isConnected) {
      return Future<void>.value();
    }
    onConnected(bool? connected, [dynamic _, dynamic __]) {
      if (!(connected ?? false)) {
        return;
      }
      completer.complete();
      events.connection.off(onConnected);
    }

    events.connection.on(onConnected);

    return completer.future;
  }

  /// Send graph data for one or more nodes
  ///
  /// @returns A function to be called to clean up callback listeners
  VoidCallback put(FlutterGunPut params, [dynamic _, dynamic __]) {
    return () {};
  }

  /// Request data for a given soul
  ///
  /// @returns A function to be called to clean up callback listeners
  VoidCallback get(FlutterGunGet params, [dynamic _, dynamic __]) {
    return () => {};
  }

  /// Queues outgoing messages for sending
  ///
  /// @param msgs The Gun wire protocol messages to enqueue
  GunGraphConnector send(List<GunMsg> msgs) {
    outputQueue.enqueueMany(msgs);
    if (isConnected) {
      outputQueue.process();
    }

    return this;
  }

  /// Queue incoming messages for processing
  ///
  /// @param msgs
  GunGraphConnector ingest(List<GunMsg> msgs) {
    inputQueue.enqueueMany(msgs).process();

    return this;
  }

  GunGraphConnector connectToGraph(GunGraph graph) {
    graph.events.off.on(off);
    return this;
  }

  __onConnectedChange(bool connected, [dynamic _, dynamic __]) {
    if (connected) {
      isConnected = true;
      outputQueue.process();
    } else {
      isConnected = false;
    }
  }
}
