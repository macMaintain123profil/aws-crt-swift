//  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
//  SPDX-License-Identifier: Apache-2.0.

import AwsCAuth

class SigV4HttpRequestSigner {
    public var allocator: Allocator

    public init(allocator: Allocator = defaultAllocator) {
        self.allocator = allocator
    }
    
    /// Signs an HttpRequest via the SigV4 algorithm.
    /// Do not add the following headers to requests before signing:
    ///   - x-amz-content-sha256,
    ///   - X-Amz-Date,
    ///   - Authorization
    ///
    /// Do not add the following query params to requests before signing:
    ///   - X-Amz-Signature,
    ///   - X-Amz-Date,
    ///   - X-Amz-Credential,
    ///   - X-Amz-Algorithm,
    ///   - X-Amz-SignedHeaders
    ///
    /// The signing result will tell exactly what header and/or query params to add to the request to become a fully-signed AWS http request.
    ///
    /// - `Parameters`:
    ///    - `request`:  The `HttpRequest`to be signed.
    ///    - `config`: The `SigningConfig` to use when signing.
    ///    - `callback`: The `OnRequestSigningComplete` will be called when requst has been signed.
    /// - `Throws`: An error of type `AwsCommonRuntimeError` which will pull last error found in the CRT
    public func signRequest(request: HttpRequest, config: SigningConfig, callback: @escaping OnRequestSigningComplete) throws {
        if config.configType != .aws {
            throw AwsCommonRuntimeError()
        }
        
        if config.rawValue.credentials_provider == nil && config.rawValue.credentials == nil {
            throw AwsCommonRuntimeError()
        }
        
        let callbackData = SigningCallbackData(allocator: allocator.rawValue, request: request, onRequestSigningComplete: callback)
        
        let signable = aws_signable_new_http_request(allocator.rawValue, request.rawValue)
        
        let configPointer = UnsafeMutablePointer<aws_signing_config_aws>.allocate(capacity: 1)
        configPointer.initialize(to: config.rawValue)
        let base = unsafeBitCast(configPointer, to: UnsafeMutablePointer<aws_signing_config_base>.self)
        let configPtr = UnsafePointer(base)
        
        let callbackPointer = UnsafeMutablePointer<SigningCallbackData>.allocate(capacity: 1)
        callbackPointer.initialize(to: callbackData)
        
        defer{
            aws_signable_destroy(signable)
            base.deinitializeAndDeallocate()
        }
        
        if aws_sign_request_aws(allocator.rawValue,
                                    signable,
                                    configPtr,
                                    { (signingResult, errorCode, userData) -> Void in
                                        guard let userData = userData else {
                                            return
                                        }
                                        let callback = userData.assumingMemoryBound(to: SigningCallbackData.self)
                                        if errorCode == AWS_OP_SUCCESS {
                                            aws_apply_signing_result_to_http_request(callback.pointee.request.rawValue,
                                                                                     callback.pointee.allocator.rawValue,
                                                                                     signingResult)
                                        }
                                        defer {
                                            callback.deinitializeAndDeallocate()
                                        }
                                        callback.pointee.onRequestSigningComplete(callback.pointee.request, Int(errorCode))
        },
                                    callbackPointer) != AWS_OP_SUCCESS {
            throw AwsCommonRuntimeError()
        }
    }
    
    deinit {
        print("signer deinitilized")
    }
}
