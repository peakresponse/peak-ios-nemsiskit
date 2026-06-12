//
//  ViewController.swift
//  Example
//
//  Created by Francis Li on 4/15/26.
//

import NemsisKit
import UIKit
import WebKit

let versionString = "3.5.1.251001CP2"

class ViewController: UIViewController {
    weak var button: UIButton!
    weak var webView: WKWebView!
    var version: NemsisV3!

    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Validate", for: .normal)
        button.addTarget(self, action: #selector(validatePressed), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        self.button = button

        version = try! NemsisV3(version: versionString)

        let webView = version.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        self.webView = webView

        let fixturesURL = Bundle.main.url(forResource: "Fixtures/\(versionString)", withExtension: nil)!
        let xsdsURL = fixturesURL.appendingPathComponent("xsds")
        let xsdURLs = try! FileManager.default.contentsOfDirectory(at: xsdsURL, includingPropertiesForKeys: nil)
        for xsdURL in xsdURLs {
            let destURL = version.xsdsDirectoryURL.appendingPathComponent(xsdURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try! FileManager.default.removeItem(at: destURL)
            }
            try! FileManager.default.copyItem(at: xsdURL, to: destURL)
        }
        let schsURL = fixturesURL.appendingPathComponent("schs")
        let schURLs = try! FileManager.default.contentsOfDirectory(at: schsURL, includingPropertiesForKeys: nil)
        for schURL in schURLs {
            let destURL = version.schsDirectoryURL.appendingPathComponent(schURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try! FileManager.default.removeItem(at: destURL)
            }
            try! FileManager.default.copyItem(at: schURL, to: destURL)
        }
        print(version.versionDirectoryURL)
    }

    @objc func validatePressed() {
        let xmlURL = Bundle.main.url(forResource: "Fixtures/\(versionString)/2026-EMS-FailSchematron_v351", withExtension: "xml")!
        let pcr = try! PatientCareReportV3(version: version, url: xmlURL)
        Task { @MainActor in
            let errors = try! await version.validate(pcr: pcr)
            print(errors)
        }
    }
}
