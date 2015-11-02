//
//  DeviceViewController.swift
//  Actors
//
//  Created by Dario Lencina on 11/1/15.
//  Copyright © 2015 dario. All rights reserved.
//

import UIKit
import iAd

public class BaseViewController : UIViewController, ADBannerViewDelegate {
    let iAdBanner : ADBannerView = ADBannerView()
    var iAdConstraints : [NSLayoutConstraint]?
    
    @IBOutlet weak var bannerView : UIView!
    @IBOutlet weak var bottomBannerConstraint : NSLayoutConstraint?
    @IBOutlet weak var bannerHeight : NSLayoutConstraint?
    
    private func setupiAdNetwork() {
        iAdBanner.delegate = self;
        iAdBanner.translatesAutoresizingMaskIntoConstraints = false
        self.bannerView.addSubview(iAdBanner)
        self.bannerView.addConstraints(self.iAdsLayoutConstrains())
        self.layoutBanners()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.setupiAdNetwork()
    }
    
    func layoutBanners() {
        if iAdBanner.bannerLoaded {
            self.shouldShowBanner()
        }else{
            self.shouldHideBanner()
        }
    }
    
    func shouldHideBanner() {
        UIView.animateWithDuration(0.3) { () -> Void in
            self.bottomBannerConstraint!.constant = 40
            self.view.layoutSubviews()
        }
    }
    
    func shouldShowBanner() {
        UIView.animateWithDuration(0.3) { () -> Void in
            let value = 40 - self.iAdBanner.frame.size.height
            self.bottomBannerConstraint!.constant = value
            self.view.layoutSubviews()
        }
    }
    
    func iAdsLayoutConstrains() -> [NSLayoutConstraint] {
        if iAdConstraints != nil {
            return iAdConstraints!
        }
        
        let leading = NSLayoutConstraint(item: iAdBanner, attribute: .Leading, relatedBy: .Equal, toItem: self.bannerView, attribute: .Leading, multiplier: 1, constant: 0)
    
        let top = NSLayoutConstraint(item: iAdBanner, attribute: .Top, relatedBy: .Equal, toItem: self.bannerView, attribute: .Top, multiplier: 1, constant: 0)
        
        let width = NSLayoutConstraint(item: iAdBanner, attribute: .Width, relatedBy: .Equal, toItem: self.bannerView, attribute: .Width, multiplier: 1, constant: 0)
        
        self.iAdConstraints = [top, width, leading]
        return self.iAdConstraints!
    }
    
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    public func bannerViewDidLoadAd(banner: ADBannerView!) {
        self.layoutBanners()
    }
    
    public func bannerView(banner: ADBannerView!, didFailToReceiveAdWithError error: NSError!) {
        self.shouldHideBanner()
    }
    
    public func bannerViewActionShouldBegin(banner: ADBannerView!, willLeaveApplication willLeave: Bool) -> Bool {
        return true
    }

    public func bannerViewActionDidFinish(banner: ADBannerView!) {
        self.shouldHideBanner()
    }
    
}