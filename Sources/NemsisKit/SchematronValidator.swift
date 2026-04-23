//
//  SchematronValidator.swift
//  NemsisKit
//
//  Created by Francis Li on 4/22/26.
//

import Foundation
import Nodal
import SwiftXMLLint
import UniformTypeIdentifiers
import WebKit

enum SchematronValidatorError: Error {
    case javascriptError(Error)
    case unexpectedError
}

@MainActor
class SchematronValidator: NSObject, WKNavigationDelegate, WKURLSchemeHandler {
    let baseURL: URL
    private(set) var webView: WKWebView!
    private var initializer: WKNavigation?

    private var tasks: [URL: Task<Void, Never>] = [:]

    init(baseURL: URL) {
        self.baseURL = baseURL
        super.init()
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(self, forURLScheme: "nemsiskit")
        self.webView = WKWebView(frame: .zero, configuration: config)

        webView.navigationDelegate = self
        initializer = webView.load(URLRequest(url: URL(string: "nemsiskit://app/index.html")!))
    }

    func validate(xml: String, with stylesheet: String) async throws -> [XMLValidationError] {
        try xml.write(to: baseURL.appendingPathComponent("data.xml"), atomically: true, encoding: .utf8)
        let result = try await webView.callAsyncJavaScript("return await validate('\(stylesheet)', 'data.xml')",
                                                           contentWorld: .page)
        if let result = result as? String {
            let doc = try Document(string: result)
            let errorsQuery = try XPathQuery("/svrl:schematron-output/svrl:failed-assert")
            let textQuery = try XPathQuery("./svrl:text")
            let errors = errorsQuery.nodesResult(with: doc.node)
            var results: [XMLValidationError] = []
            for error in errors {
                if let node = error.node {
                    var location = node[attribute: "location"]
                    location = location?.replacingOccurrences(of: #"\[namespace-uri\(\)=[^\]]*\]"#,
                                                              with: "",
                                                              options: .regularExpression)
                    location = location?.replacingOccurrences(of: "/*:", with: "/")
                    location = location?.replacingOccurrences(of: "/EMSDataSet[1]/Header[1]", with: "")
                    let textNode = textQuery.firstNodeResult(with: node)
                    let text = textNode?.node?.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let location, let text {
                        let error = XMLValidationError(message: text, location: location)
                        results.append(error)
                    }
                }
            }
            return results
        } else if let result = result as? Error {
            throw SchematronValidatorError.javascriptError(result)
        } else {
            throw SchematronValidatorError.unexpectedError
        }
    }

    // - MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if navigation == initializer {
            initializer = nil
        }
    }

    // - MARK: WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url {
            let sourceURL = baseURL.appendingPathComponent(url.path)
            let task = urlSchemeTask
            let pathExtension = url.pathExtension
            let originalURL = url
            tasks[url] = Task {
                defer {
                    tasks.removeValue(forKey: url)
                }
                do {
                    let resources = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resources.fileSize
                    let type = UTType(filenameExtension: pathExtension)
                    task.didReceive(URLResponse(url: originalURL,
                                              mimeType: type?.preferredMIMEType,
                                              expectedContentLength: fileSize ?? -1,
                                              textEncodingName: nil))
                    let fileHandle = try FileHandle(forReadingFrom: sourceURL)
                    let chunkSize = 4096
                    while true {
                        if let data = try fileHandle.read(upToCount: chunkSize), !data.isEmpty {
                            task.didReceive(data)
                        } else {
                            break // End of file
                        }
                    }
                    try fileHandle.close()
                    task.didFinish()
                } catch {
                    task.didFailWithError(error)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let task = tasks[url] {
            task.cancel()
            tasks.removeValue(forKey: url)
        }
    }
}
