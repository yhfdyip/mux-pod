import Flutter
import UIKit
import libmoshios

// MARK: - MoshPlugin
// Flutter MethodChannel/EventChannel bridge for libmoshios
// Channel: com.muxpod.app/mosh (method), com.muxpod.app/mosh_events (event)

class MoshPlugin: NSObject {
  static let methodChannelName = "com.muxpod.app/mosh"
  static let eventChannelName  = "com.muxpod.app/mosh_events"

  private var eventSink: FlutterEventSink?
  private var moshThread: Thread?
  private var running = false

  // Shared winsize updated by resizeMosh
  private var winsize = winsize()

  // Input pipe: Flutter writes to inputWrite, mosh reads from inputRead
  private var inputReadFD:  Int32 = -1
  private var inputWriteFD: Int32 = -1

  // Output pipe: mosh writes to outputWrite, reader thread reads from outputRead
  private var outputReadFD:  Int32 = -1
  private var outputWriteFD: Int32 = -1

  func register(with messenger: FlutterBinaryMessenger) {
    let method = FlutterMethodChannel(name: MoshPlugin.methodChannelName,
                                      binaryMessenger: messenger)
    method.setMethodCallHandler(handleMethodCall(_:result:))

    let event = FlutterEventChannel(name: MoshPlugin.eventChannelName,
                                     binaryMessenger: messenger)
    event.setStreamHandler(self)
  }

  // MARK: - MethodChannel

  private func handleMethodCall(_ call: FlutterMethodCall,
                                result: @escaping FlutterResult) {
    switch call.method {
    case "startMosh":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      startMosh(args: args, result: result)

    case "stopMosh":
      stopMosh()
      result(nil)

    case "sendMoshInput":
      guard let data = call.arguments as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected bytes", details: nil))
        return
      }
      sendInput(data.data)
      result(nil)

    case "resizeMosh":
      guard let args = call.arguments as? [String: Any],
            let cols = args["cols"] as? Int,
            let rows = args["rows"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing cols/rows", details: nil))
        return
      }
      winsize.ws_col = UInt16(cols)
      winsize.ws_row = UInt16(rows)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Mosh lifecycle

  private func startMosh(args: [String: Any], result: @escaping FlutterResult) {
    guard !running else {
      result(FlutterError(code: "ALREADY_RUNNING", message: "Mosh already running", details: nil))
      return
    }
    guard
      let ip   = args["ip"]   as? String,
      let port = args["port"] as? String,
      let key  = args["key"]  as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "ip/port/key required", details: nil))
      return
    }

    let predict = (args["predict"] as? String) ?? "adaptive"
    let cols    = (args["cols"]    as? Int)    ?? 80
    let rows    = (args["rows"]    as? Int)    ?? 24

    winsize.ws_col = UInt16(cols)
    winsize.ws_row = UInt16(rows)

    // Create pipes
    var inPipe  = [Int32](repeating: 0, count: 2)
    var outPipe = [Int32](repeating: 0, count: 2)
    guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else {
      result(FlutterError(code: "PIPE_ERROR", message: "pipe() failed", details: nil))
      return
    }
    inputReadFD   = inPipe[0];  inputWriteFD  = inPipe[1]
    outputReadFD  = outPipe[0]; outputWriteFD = outPipe[1]

    let fIn  = fdopen(inputReadFD,   "r")
    let fOut = fdopen(outputWriteFD, "w")

    running = true
    result(nil)  // ack Flutter immediately; events follow via EventChannel

    // Start output reader thread
    let outputFD = outputReadFD
    let sink = eventSink
    Thread.detachNewThread {
      self.readOutputLoop(fd: outputFD, sink: sink)
    }

    // Run mosh_main on dedicated thread (blocks until session ends)
    let ipC       = (ip      as NSString).utf8String!
    let portC     = (port    as NSString).utf8String!
    let keyC      = (key     as NSString).utf8String!
    let predictC  = (predict as NSString).utf8String!

    moshThread = Thread {
      let exitCode = mosh_main(
        fIn, fOut, &self.winsize,
        { _, statePtr, stateLen in
          // state_callback: ignore for now
          _ = statePtr; _ = stateLen
        },
        nil,
        ipC, portC, keyC, predictC,
        nil, 0
      )
      fclose(fIn)
      fclose(fOut)
      self.running = false
      DispatchQueue.main.async {
        self.eventSink?(["type": "disconnected", "exitCode": exitCode])
      }
    }
    moshThread!.start()
  }

  private func stopMosh() {
    // Close input pipe to signal EOF to mosh_main
    if inputWriteFD >= 0 { close(inputWriteFD); inputWriteFD = -1 }
    if inputReadFD  >= 0 { close(inputReadFD);  inputReadFD  = -1 }
    running = false
  }

  private func sendInput(_ data: Data) {
    guard inputWriteFD >= 0 else { return }
    data.withUnsafeBytes { ptr in
      _ = write(inputWriteFD, ptr.baseAddress!, data.count)
    }
  }

  // Read mosh output and forward to Flutter EventChannel
  private func readOutputLoop(fd: Int32, sink: FlutterEventSink?) {
    let bufSize = 4096
    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
    defer {
      buf.deallocate()
      close(fd)
    }
    while true {
      let n = read(fd, buf, bufSize)
      if n <= 0 { break }
      let data = Data(bytes: buf, count: n)
      DispatchQueue.main.async {
        self.eventSink?(["type": "output", "data": FlutterStandardTypedData(bytes: data)])
      }
    }
  }
}

// MARK: - FlutterStreamHandler

extension MoshPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
