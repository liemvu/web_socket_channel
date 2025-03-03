// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library web_socket_channel.io;

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

import 'src/channel.dart';
import 'src/exception.dart';
import 'src/sink_completer.dart';

/// A [WebSocketChannel] that communicates using a `dart:io` [WebSocket].
class IOWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  /// The underlying `dart:io` [WebSocket].
  ///
  /// If the channel was constructed with [IOWebSocketChannel.connect], this is
  /// `null` until the [WebSocket.connect] future completes.
  WebSocket _webSocket;

  String get protocol => _webSocket?.protocol;
  int get closeCode => _webSocket?.closeCode;
  String get closeReason => _webSocket?.closeReason;

  final Stream stream;
  final WebSocketSink sink;

  // TODO(nweiz): Add a compression parameter after the initial release.

  /// Creates a new WebSocket connection.
  ///
  /// Connects to [url] using [WebSocket.connect] and returns a channel that can
  /// be used to communicate over the resulting socket. The [url] may be either
  /// a [String] or a [Uri]. The [protocols] and [headers] parameters are the
  /// same as [WebSocket.connect].
  ///
  /// [pingInterval] controls the interval for sending ping signals. If a ping
  /// message is not answered by a pong message from the peer, the WebSocket is
  /// assumed disconnected and the connection is closed with a `goingAway` code.
  /// When a ping signal is sent, the pong message must be received within
  /// [pingInterval]. It defaults to `null`, indicating that ping messages are
  /// disabled.
  ///
  /// If there's an error connecting, the channel's stream emits a
  /// [WebSocketChannelException] wrapping that error and then closes.
  factory IOWebSocketChannel.connect(url,
      {Iterable<String> protocols,
      Map<String, dynamic> headers,
      Duration pingInterval}) {
    var channel;
    var sinkCompleter = WebSocketSinkCompleter();
    var stream = StreamCompleter.fromFuture(
        WebSocket.connect(url.toString(), headers: headers, protocols: protocols).then((webSocket) {
      webSocket.pingInterval = pingInterval;
      channel._webSocket = webSocket;
      sinkCompleter.setDestinationSink(_IOWebSocketSink(webSocket));
      return webSocket;
    }).catchError((error) => throw WebSocketChannelException.from(error)));

    channel = IOWebSocketChannel._withoutSocket(stream, sinkCompleter.sink);
    return channel;
  }

  /// Creates a channel wrapping [socket].
  IOWebSocketChannel(WebSocket socket)
      : _webSocket = socket,
        stream = socket.handleError(
            (error) => throw WebSocketChannelException.from(error)),
        sink = _IOWebSocketSink(socket);

  /// Creates a channel without a socket.
  ///
  /// This is used with [connect] to synchronously provide a channel that later
  /// has a socket added.
  IOWebSocketChannel._withoutSocket(Stream stream, this.sink)
      : _webSocket = null,
        stream = stream.handleError(
            (error) => throw WebSocketChannelException.from(error));
}

/// A [WebSocketSink] that forwards [close] calls to a `dart:io` [WebSocket].
class _IOWebSocketSink extends DelegatingStreamSink implements WebSocketSink {
  /// The underlying socket.
  final WebSocket _webSocket;

  _IOWebSocketSink(WebSocket webSocket)
      : _webSocket = webSocket,
        super(webSocket);

  Future close([int closeCode, String closeReason]) =>
      _webSocket.close(closeCode, closeReason);
}
