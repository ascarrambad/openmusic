//
//  AdProvider.swift
//  OpenMusic
//
//  Created by Matteo Riva on 19/10/2016.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation
import GoogleMobileAds

typealias AdProviderUnit =  String

extension AdProviderUnit {
    static let banner = "ca-app-pub-5049922818559933/5710477200"
    static let playerBanner = "ca-app-pub-5049922818559933/8707642806"
    static let interstitial = "ca-app-pub-5049922818559933/3160636808"
}

typealias AdProviderFrame = CGRect

extension AdProviderFrame {
    private static let tabH: CGFloat = OSVersion.is8OrLater ? 49 : 56
    
    static let tabBar  = AdProviderFrame(x: 0, y: ScreenSize.height-49-50, width: ScreenSize.width, height: 50)
    static let tabBarPad = AdProviderFrame(x: 0, y: ScreenSize.height-tabH-80, width: ScreenSize.width, height: 80)
    static let top = AdProviderFrame(x: 0, y: 0, width: ScreenSize.width, height: 50)
    static let bottom = AdProviderFrame(x: 0, y: ScreenSize.height-50, width: ScreenSize.width, height: 50)
}

extension Notification.Name {
    static let AdBannerNeedsAppearanceUpdate = NSNotification.Name("AdBannerNeedsAppearanceUpdate")
    static let UserDidPurchaseAds = Notification.Name("UserDidPurchaseAds")
}

class AdProvider: NSObject, GADBannerViewDelegate, GADInterstitialDelegate {
    
    static let shared = AdProvider()
    private(set) var banner: GADBannerView?
    private(set) var playerBanner: GADBannerView?
    private var _interstitial: GADInterstitial? {
        get {
            if !isNoAdsPurchased {
                let interstitial = GADInterstitial(adUnitID: AdProviderUnit.interstitial)
                interstitial.delegate = self
                interstitial.load(GADRequest())
                return interstitial
            } else {
                return nil
            }
        }
    }
    
    private(set) var interstitial: GADInterstitial?
    
    var isNoAdsPurchased: Bool {
        get { return UserDefaults.standard.bool(forKey: "AdProviderNoAdsPurchased") }
        set { UserDefaults.standard.set(newValue, forKey: "AdProviderNoAdsPurchased") }
    }
    
    override private init() {
        super.init()
        
        if !isNoAdsPurchased {
            banner = GADBannerView()
            banner?.adUnitID = AdProviderUnit.banner
            banner?.delegate = self
            banner?.isHidden = true
            
            playerBanner = GADBannerView()
            playerBanner?.adUnitID = AdProviderUnit.playerBanner
            playerBanner?.delegate = self
            playerBanner?.isHidden = true
            
            interstitial = _interstitial
        }
        
        NotificationCenter.default.addObserver(forName: .AdBannerNeedsAppearanceUpdate, object: nil, queue: nil) { [unowned self] (notif) -> Void in
            if let hidden = notif.userInfo?["hidden"] as? Bool {
                self.banner?.isHidden = hidden
            }
        }
        
        NotificationCenter.default.addObserver(forName: .UserDidPurchaseAds, object: nil, queue: .main) { [unowned self] (_) in
            self.banner?.removeFromSuperview()
            self.banner?.delegate = nil
            self.banner = nil
            
            self.playerBanner?.removeFromSuperview()
            self.playerBanner?.delegate = nil
            self.playerBanner = nil
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func initBanner(_ banner: GADBannerView!, with rootViewController: UIViewController, frame: AdProviderFrame) {
        if !isNoAdsPurchased {
            banner.frame = frame
            banner.rootViewController = rootViewController
            rootViewController.view.addSubview(banner)
            let request = GADRequest()
            request.testDevices = [kGADSimulatorID, "dbe5567d6901eec2b0c1df79f58dcfa0"]
            banner.load(request)
        }
    }
    
    func changeBannerFrameWithFrame(_ frame: CGRect) {
        if !isNoAdsPurchased {
            banner?.frame = frame
            banner?.setNeedsDisplay()
        }
    }
    
    func moveBannerToFrame(_ frame: CGRect) {
        if !isNoAdsPurchased {
            UIView.animate(withDuration: 0.3) { [unowned self] in
                self.banner?.isHidden = false
                self.banner?.frame = frame
            }
        }
    }
    
    func removeBannerFromSuperview() {
        if !isNoAdsPurchased {
            banner?.removeFromSuperview()
            banner?.isHidden = false
        }
    }
    
    //MARK: - GADBannerViewDelegate
    
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        bannerView.isHidden = false
    }
    
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        bannerView.isHidden = true
    }
    
    //MARK: - GADInterstitialDelegate
    
    func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        interstitial = _interstitial
    }
    
    func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
        interstitial = _interstitial
    }
    
}

