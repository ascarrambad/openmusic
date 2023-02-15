//
//  NavigationViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 19/06/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit
import WebKit

class NavigationViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var percentageView: UIView!
    @IBOutlet weak var percentage: UILabel!
    
    @IBOutlet weak var reloadButton: UIBarButtonItem!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var forwardButton: UIBarButtonItem!
    
    private let webView = WKWebView()
    private let searchBar =  UITextField()
    private let downloadManager = DonwloadManager.shared
    
    //MARK: - Init

    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        homeAction()
        
        view.insertSubview(webView, belowSubview: percentageView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let height = NSLayoutConstraint(item: webView, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 0)
        let width = NSLayoutConstraint(item: webView, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0)
        view.addConstraints([height, width])
        
        searchBar.font = UIFont.systemFont(ofSize: 15)
        searchBar.clearButtonMode = .whileEditing
        searchBar.autocapitalizationType = .none
        searchBar.returnKeyType = .go
        searchBar.autocorrectionType = .no
        searchBar.keyboardType = .webSearch
        searchBar.delegate = self
        searchBar.frame = CGRect(x: 0, y: 0, width: navigationController!.navigationBar.frame.size.width, height: 30)
        searchBar.textColor = navigationItem.rightBarButtonItem?.tintColor
        searchBar.tintColor = navigationItem.rightBarButtonItem?.tintColor
        navigationItem.titleView = searchBar
        navigationItem.titleView?.tintColor = navigationItem.rightBarButtonItem?.tintColor
        
        percentageView.layer.cornerRadius = 10
        percentageView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        webView.addObserver(self, forKeyPath: "loading", options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: [.initial, .new], context: nil)
        webView.addObserver(self, forKeyPath: "URL", options: [.initial, .new], context: nil)
        
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: "loading", context: nil)
        webView.removeObserver(self, forKeyPath: "estimatedProgress", context: nil)
        webView.removeObserver(self, forKeyPath: "URL", context: nil)
    }
    
    //MARK: - Observer
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "loading") {
            let barButton: UIBarButtonItem
            if webView.isLoading {
                barButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(NavigationViewController.stopAction))
            } else {
                barButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(NavigationViewController.refreshAction))
            }
            barButton.tintColor = navigationItem.rightBarButtonItem?.tintColor
            navigationController?.toolbar.items?[4] = barButton
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
        } else if (keyPath == "estimatedProgress") {
            progressView.isHidden = webView.estimatedProgress == 1
            progressView.setProgress(Float(webView.estimatedProgress), animated: true)
        } else if (keyPath == "URL") {
            searchBar.text = webView.url?.absoluteString.replacingOccurrences(of: "http(s)?://(www.)?", with: "", options: [.regularExpression, .caseInsensitive], range: nil)
        }
    }
    
    //MARK: - Actions
    
    @IBAction func dismissAction() {
        dismiss(animated: true, completion: nil)
    }
    
    func stopAction() {
        webView.stopLoading()
    }
    
    @IBAction func refreshAction() {
        if let url = webView.url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    @IBAction func previousAction() {
        webView.goBack()
    }
    
    @IBAction func followingAction() {
        webView.goForward()
    }
    
    @IBAction func homeAction() {
        let home = UserDefaults.standard.string(forKey: "homeNavigation") ?? "http://www.google.com"
        if let url = URL(string: home) {
            webView.load(URLRequest(url: url))
        }
    }
    
    @IBAction func sheetAction() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.view.tintColor = navigationItem.rightBarButtonItem?.tintColor
        
        
        let homeAction = UIAlertAction(title: "set_home".localized, style: .default) {[weak self] (_) in
            if let home = self?.webView.url?.absoluteString {
                UserDefaults.standard.set(home, forKey: "homeNavigation")
            }
        }
        let shareAction = UIAlertAction(title: "share_link".localized, style: .default) {[weak self] (_) in
            if let home = self?.webView.url {
                let share = UIActivityViewController(activityItems: [home], applicationActivities: nil)
                share.view.tintColor = self?.navigationItem.rightBarButtonItem?.tintColor
                self?.present(share, animated: true, completion: nil)
            }
        }
        
        let cancelAction = UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
        
        sheet.addAction(homeAction)
        sheet.addAction(shareAction)
        sheet.addAction(cancelAction)
        
        present(sheet, animated: true, completion: nil)
    }
    
    //MARK: - Generics
    
    func handleError(_ error: NSError) {
        let alert = UIAlertController(title: "error".localized, message: error.localizedDescription, preferredStyle: .alert)
        alert.view.tintColor = navigationItem.rightBarButtonItem?.tintColor
        
        let okAction = UIAlertAction(title: "ok_button".localized, style: .default, handler: nil)
        
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    //MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let address = textField.text!
        let webRegex = "^(http(s)?://)?(www.)?[^ ]+\\.[^ ]{1,4}$"
        let pred = NSPredicate(format: "SELF MATCHES[c] %@", webRegex)
        
        let url: URL
        if pred.evaluate(with: address) {
            let protoRegex = "^http(s)?://(www.)?[^ ]+\\.[^ ]{1,4}$"
            let pred = NSPredicate(format: "SELF MATCHES[c] %@", protoRegex)
            if pred.evaluate(with: address) {
                url = URL(string: address)!
            } else {
                url = URL(string: "http://" + address)!
            }
        } else {
            let search = "https://www.google.com/search?q=" + address.replacingOccurrences(of: " ", with: "+")
            url = URL(string: search)!
        }
        
        webView.load(URLRequest(url: url))
        return false
    }
    
    //MARK: - WKWebViewDelegate
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleError(error as NSError)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.setProgress(0.0, animated: false)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.absoluteString == "about:blank" {
            decisionHandler(.cancel)
        } else if navigationAction.navigationType == .linkActivated {
            decisionHandler(.allow)
        } else {
            decisionHandler(.allow)
        }
        
        //print(navigationAction.request)
        if let header = navigationAction.request.allHTTPHeaderFields {
            //print(header)
            if let referer = header["Referer"] {
                self.referer = referer
            } else {
                self.referer = nil
            }
        }
//        if let body = navigationAction.request.httpBody {
//            print(NSString(data: body, encoding: String.Encoding.utf8.rawValue))
//        }
    }
    
    var referer: String?

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let contentType = navigationResponse.response.mimeType {
            if contentType.contains("audio/mpeg") {
                
                decisionHandler(.cancel)
                
                let alertController = UIAlertController(title: "fill_info_placeholder".localized, message: nil, preferredStyle: .alert)
                alertController.view.tintColor = navigationItem.rightBarButtonItem?.tintColor
                
                alertController.addTextField { (text) in
                    text.placeholder = "artist_field_placeholder".localized
                }
                alertController.addTextField { (text) in
                    text.placeholder = "song_field_placeholder".localized
                }
                
                let downloadAction = UIAlertAction(title: "ok_button".localized, style: .default) {[weak self] (_) in
                    
                    self?.percentageView.isHidden = false
                    
                    let infos = ["id" : Date().description,
                                 "artist" : alertController.textFields![0].text!,
                                 "track" : alertController.textFields![1].text!]
                    
                    var request = URLRequest(url: navigationResponse.response.url!)
                    if let response = navigationResponse.response as? HTTPURLResponse,
                        let cookie = response.allHeaderFields["Set-Cookie"] as? String {
                        request.addValue(cookie, forHTTPHeaderField: "Cookie")
                    }
                    
                    if let referer = self?.referer {
                        request.addValue(referer, forHTTPHeaderField: "Referer")
                    }
                    
                    self?.downloadManager.download(request: request, with: infos, handler: {[weak self] (perc) in
                        self?.percentage.text = "\(Int(perc*100))%"
                        }, completion: { (error) in
                            DispatchQueue.main.async {[weak self] in
                                self?.percentageView.isHidden = true
                                self?.percentage.text = "0%"
                                if let error = error {
                                    self?.handleError(error)
                                }
                            }
                    })
                    
                }
                
                let cancelAction = UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
                
                alertController.addAction(downloadAction)
                alertController.addAction(cancelAction)
                present(alertController, animated: true, completion: nil)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
        //print(navigationResponse.response)
    }
}
