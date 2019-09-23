//
//  UIImageView+Downloader.swift
//  PinboardDemo
//
//  Created by SYED FARAN GHANI on 21/09/19.
//  Copyright © 2019 Syed Faran Ghani. All rights reserved.
//

import UIKit

public extension UIImageView {
    
    var hnk_format : Format<UIImage> {
        let viewSize = self.bounds.size
            assert(viewSize.width > 0 && viewSize.height > 0, "[\(Mirror(reflecting: self).description) \(#function)]: UImageView size is zero. Set its frame, call sizeToFit or force layout first.")
            let scaleMode = self.hnk_scaleMode
            return DownloaderGlobals.UIKit.formatWithSize(viewSize, scaleMode: scaleMode)
    }
    
    func hnk_setImageFromURL(_ URL: Foundation.URL, placeholder : UIImage? = nil, format : Format<UIImage>? = nil, failure fail : ((Error?) -> ())? = nil, success succeed : ((UIImage) -> ())? = nil) {
        let fetcher = NetworkFetcher<UIImage>(URL: URL)
        self.hnk_setImage(fromFetcher: fetcher, placeholder: placeholder, format: format, failure: fail, success: succeed)
    }
    
    func hnk_setImage( _ image: @autoclosure @escaping () -> UIImage, key: String, placeholder : UIImage? = nil, format : Format<UIImage>? = nil, success succeed : ((UIImage) -> ())? = nil) {
        let fetcher = SimpleFetcher<UIImage>(key: key, value: image())
        self.hnk_setImage(fromFetcher: fetcher, placeholder: placeholder, format: format, success: succeed)
    }
    
    func hnk_setImageFromFile(_ path: String, placeholder : UIImage? = nil, format : Format<UIImage>? = nil, failure fail : ((Error?) -> ())? = nil, success succeed : ((UIImage) -> ())? = nil) {
        let fetcher = DiskFetcher<UIImage>(path: path)
        self.hnk_setImage(fromFetcher: fetcher, placeholder: placeholder, format: format, failure: fail, success: succeed)
    }
    
    func hnk_setImage(fromFetcher fetcher : Fetcher<UIImage>,
        placeholder : UIImage? = nil,
        format : Format<UIImage>? = nil,
        failure fail : ((Error?) -> ())? = nil,
        success succeed : ((UIImage) -> ())? = nil) {

        self.hnk_cancelSetImage()
        
        self.hnk_fetcher = fetcher
        
        let didSetImage = self.hnk_fetchImageForFetcher(fetcher, format: format, failure: fail, success: succeed)
        
        if didSetImage { return }
     
        if let placeholder = placeholder {
            self.image = placeholder
        }
    }
    
    func hnk_cancelSetImage() {
        if let fetcher = self.hnk_fetcher {
            fetcher.cancelFetch()
            self.hnk_fetcher = nil
        }
    }
    
    // MARK: Internal
    
    // See: http://stackoverflow.com/questions/25907421/associating-swift-things-with-nsobject-instances
    var hnk_fetcher : Fetcher<UIImage>! {
        get {
            let wrapper = objc_getAssociatedObject(self, &DownloaderGlobals.UIKit.SetImageFetcherKey) as? ObjectWrapper
            let fetcher = wrapper?.hnk_value as? Fetcher<UIImage>
            return fetcher
        }
        set (fetcher) {
            var wrapper : ObjectWrapper?
            if let fetcher = fetcher {
                wrapper = ObjectWrapper(value: fetcher)
            }
            objc_setAssociatedObject(self, &DownloaderGlobals.UIKit.SetImageFetcherKey, wrapper, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var hnk_scaleMode : ImageResizer.ScaleMode {
        switch (self.contentMode) {
        case .scaleToFill:
            return .Fill
        case .scaleAspectFit:
            return .AspectFit
        case .scaleAspectFill:
            return .AspectFill
        case .redraw, .center, .top, .bottom, .left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight:
            return .None
        @unknown default:
            fatalError()
        }
    }

    func hnk_fetchImageForFetcher(_ fetcher : Fetcher<UIImage>, format : Format<UIImage>? = nil, failure fail : ((Error?) -> ())?, success succeed : ((UIImage) -> ())?) -> Bool {
        let cache = Shared.imageCache
        let format = format ?? self.hnk_format
        if cache.formats[format.name] == nil {
            cache.addFormat(format)
        }
        var animated = false
        let fetch = cache.fetch(fetcher: fetcher, formatName: format.name, failure: {[weak self] error in
            if let strongSelf = self {
                if strongSelf.hnk_shouldCancel(forKey: fetcher.key) { return }
                
                strongSelf.hnk_fetcher = nil
                
                fail?(error)
            }
        }) { [weak self] image in
            if let strongSelf = self {
                if strongSelf.hnk_shouldCancel(forKey: fetcher.key) { return }
                
                strongSelf.hnk_setImage(image, animated: animated, success: succeed)
            }
        }
        animated = true
        return fetch.hasSucceeded
    }
    
    func hnk_setImage(_ image : UIImage, animated : Bool, success succeed : ((UIImage) -> ())?) {
        self.hnk_fetcher = nil
        
        if let succeed = succeed {
            succeed(image)
        } else if animated {
            UIView.transition(with: self, duration: DownloaderGlobals.UIKit.SetImageAnimationDuration, options: .transitionCrossDissolve, animations: {
                self.image = image
            }, completion: nil)
        } else {
            self.image = image
        }
    }
    
    func hnk_shouldCancel(forKey key:String) -> Bool {
        if self.hnk_fetcher?.key == key { return false }
        
        Log.debug(message: "Cancelled set image for \((key as NSString).lastPathComponent)")
        return true
    }
    
}
