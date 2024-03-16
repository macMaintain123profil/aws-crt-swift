//  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
//  SPDX-License-Identifier: Apache-2.0.
import AwsCHttp

/// Core classes have manual memory management.
/// You have to balance the retain & release calls in all cases to avoid leaking memory.

@available(iOS 13.0, *)
class HTTPClientConnectionManagerCallbackCore {
    typealias ConnectionContinuation = CheckedContinuation<HTTPClientConnection, Error>

    let connectionManager: HTTPClientConnectionManager
    let continuation: ConnectionContinuation

    init(continuation: ConnectionContinuation,
         connectionManager: HTTPClientConnectionManager) {
        self.continuation = continuation
        self.connectionManager = connectionManager
    }

    private func passRetained() -> UnsafeMutableRawPointer {
        return Unmanaged.passRetained(self).toOpaque()
    }

    static func acquireConnection(
        continuation: ConnectionContinuation,
        connectionManager: HTTPClientConnectionManager
    ) {
        let callbackCore = HTTPClientConnectionManagerCallbackCore(
            continuation: continuation,
            connectionManager: connectionManager
        )
        aws_http_connection_manager_acquire_connection(
            connectionManager.rawValue,
            onConnectionSetup,
            callbackCore.passRetained()
        )
    }
}

@available(iOS 13.0, *)
private func onConnectionSetup(connection: UnsafeMutablePointer<aws_http_connection>?,
                               errorCode: Int32,
                               userData: UnsafeMutableRawPointer!) {
    let callbackDataCore = Unmanaged<HTTPClientConnectionManagerCallbackCore>.fromOpaque(userData!).takeRetainedValue()
    let continuation = callbackDataCore.continuation

    if errorCode != AWS_OP_SUCCESS {
        continuation.resume(throwing: CommonRunTimeError.crtError(CRTError(code: errorCode)))
        return
    }

    // Success
    switch aws_http_connection_get_version(connection) {
    case AWS_HTTP_VERSION_2: continuation.resume(
        returning: HTTP2ClientConnection(
            manager: callbackDataCore.connectionManager,
            connection: connection!))
    case AWS_HTTP_VERSION_1_1:
        continuation.resume(
            returning: HTTPClientConnection(
                manager: callbackDataCore.connectionManager,
                connection: connection!))
    default:
        continuation.resume(
            throwing: CommonRunTimeError.crtError(
                CRTError(
                    code: AWS_ERROR_HTTP_UNSUPPORTED_PROTOCOL.rawValue)))
    }
}
