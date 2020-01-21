//
//  TingleApiClient.swift
//  TingleApiClient
//
//  Created by Maxwell Weru on 1/9/20.
//  Copyright © 2020 TINGLE SOFTWARE COMPANY LTD. All rights reserved.
//

import Foundation

/**
 * A convenience class for making HTTP requests. The implementation of this uses `URLRequest` and `URLSession` internally.
 *
 */
public class TingleApiClient {
    
    /**
     * The instance of `URLSession` to use in making requests of type `URLRequest`
     */
    private let session: URLSession
    
    /**
     * The middleware for setting authentication information before sending the request
     */
    private let authenticationProvider: IAuthenticationProvider
    
    /**
     * The instance of `JSONDecoder` to use in creating objects from JSON payloads
     */
    private let decoder: JSONDecoder = JSONDecoder()
    
    /**
     * The instance of `JsonEncoder` to use in creating JSON payloads from objects
     */
    public let encoder: JSONEncoder = JSONEncoder()
    
    init(session: URLSession? = nil, authenticationProvider: IAuthenticationProvider? = nil)
    {
        // set the URLSession and default to the shared one when set to nil
        self.session = session ?? URLSession.shared
        
        // set the auhentication provider and default to empty when set to nil
        self.authenticationProvider = authenticationProvider ?? EmptyAuthenticationProvider()
        
        // setup the encoder and decoder
        setupJsonSerialization(encoder: encoder, decoder: decoder)
    }
    
    open func setupJsonSerialization(encoder: JSONEncoder, decoder: JSONDecoder) {
        // nothing to do here, the implementing class shall override to specify the settings for the encoder and decoder
        // example for these settings are the date format, the key strategy etc.
    }
    
    @discardableResult
    func send<TResource>(_ request: inout URLRequest, _ completionHandler: @escaping (ResourceResponse<TResource>?, Error?) -> Void) -> URLSessionTask
        where TResource: Decodable {
            
            // make the result builder
            let builder: (Int, Any, TResource?, HttpApiResponseProblem?) -> ResourceResponse<TResource> = {
                (sc: Int, headers: Any, resource:TResource?, problem: HttpApiResponseProblem?) -> ResourceResponse<TResource> in
                return ResourceResponse(statusCode: sc, headers: headers, resource: resource, problem: problem)
            }
            
            // send the request
            return send(&request, builder, completionHandler)
    }
    
    @discardableResult
    func send<TResource, TProblem>(_ request: inout URLRequest,
                                   _ completionHandler: @escaping (CustomResourceResponse<TResource, TProblem>?, Error?) -> Void) -> URLSessionTask
        where TResource: Decodable {
            
            // make the result builder
            let builder: (Int, Any, TResource?, TProblem?) -> CustomResourceResponse<TResource, TProblem> = {
                (sc: Int, headers: Any, resource:TResource?, problem: TProblem?) -> CustomResourceResponse<TResource, TProblem> in
                return CustomResourceResponse(statusCode: sc, headers: headers, resource: resource, problem: problem)
            }
            
            // send the request
            return send(&request, builder, completionHandler)
    }
    
    @discardableResult
    func send<TResource, TProblem, TResourceResponse>(_ request: inout URLRequest,
                                                      _ resultBuilder: @escaping (Int, Any, TResource?, TProblem?) -> TResourceResponse,
                                                      _ completionHandler: @escaping (TResourceResponse?, Error?) -> Void) -> URLSessionTask
        where TResource: Decodable, TProblem: Decodable, TResourceResponse: CustomResourceResponse<TResource, TProblem> {
            
            // first execute the authentication provider
            authenticationProvider.authenticate(request: &request)
            
            // now send the request over the wire
            let task = session.dataTask(with: request) { (data, response, error) in
                // prepare the variables for resource and problem
                var resource: TResource? = nil
                var problem: TProblem? = nil
                var result: TResourceResponse? = nil
                
                // cast response to the HTTP version
                if let response = response as? HTTPURLResponse {
                    
                    // get the status code
                    let statusCode = response.statusCode
                    
                    // if the response was successful, decode the resource, else the problem
                    if (data != nil && data!.count > 0) {
                        if (200..<300 ~= statusCode) {
                            resource = try! self.decoder.decode(TResource.self, from: data!)
                        } else {
                            problem = try! self.decoder.decode(TProblem.self, from: data!)
                        }
                    }
                    
                    // get the headers
                    let headers = response.allHeaderFields
                    
                    // generate the result
                    result = resultBuilder(statusCode, headers, resource, problem)
                }
                
                // invoke the completion handler
                completionHandler(result, error)
            }
            
            task.resume()
            
            return task
    }
}
