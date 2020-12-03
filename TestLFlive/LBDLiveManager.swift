//
//  LBDLiveManager.swift


import Foundation

struct ST_STREAM_PARAM {
    var fps: Int = 30
    var width: Int = 960
    var height: Int = 540
    var videoBitrate: Int = 768
    var audioBPS: Int = 64
    var isMirror: Bool = false
    var isFixedBR: Bool = false
    var pushUrl: String = ""
}

@objc public protocol LBDLiveMgrDelegate
{
    @objc optional func handleStartLiveOK(info: Any, head: String?, name: String?, viewer: Int, heart: Int, roomId: String?)
    @objc optional func handleStartLiveNak(error: String?)
    
    @objc optional func handleStopLiveOK()
    @objc optional func handleStopLiveNak(error: String?)
    
    @objc optional func handleLogMsg(msg: String)
    
    @objc optional func handleOtherError(errorCode: Int, msg: String?)
    
    @objc optional func handleBps(kbps: Double, fps: Double)
}


@objc class LBDLiveMgr : NSObject, LFLiveSessionDelegate
{
    
    //    var tiFilter = TiFilter()
    
    let MAX_RETRY_COUNTS: UInt = 10
    var retryCounts = 0
    
    private var preView : UIView?
    
    var timer: Timer? = nil
    
    var isMute = false {
        didSet {
            self.pushKit.muted = isMute 
        }
    }
    
    //  默认分辨率368 ＊ 640  音频：44.1 iphone6以上48  双声道  方向竖屏
    lazy public var pushKit: LFLiveSession = {
        let audioConfiguration = LFLiveAudioConfiguration.defaultConfiguration(for: LFLiveAudioQuality.high)
        let videoConfiguration = LFLiveVideoConfiguration.defaultConfiguration(for: LFLiveVideoQuality.low3)
        let session = LFLiveSession(audioConfiguration: audioConfiguration, videoConfiguration: videoConfiguration)
        session?.delegate = self
        
        session?.reconnectCount = MAX_RETRY_COUNTS
        return session!
    }()
    
    var streamSetting: ST_STREAM_PARAM? = nil {
        didSet{
        }
    }
    
    private var onAir = false {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = self.onAir
        }
    }
    
    weak var delegate : LBDLiveMgrDelegate?
    
    var vedioCallback: ((CMSampleBuffer?) -> ())? = nil
    
    var hostUrl: URL! = nil
    //    public var beauty = false {
    //        willSet{
    //            self.session.beautyFace = beauty
    //        }
    //
    //    }
    
    var currentPinchZoomFactor: CGFloat = 1.0
    
    
    @objc public init(view: UIView)
    {
        super.init()
        
        //        self.addObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(enterBg(not:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive(not:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        self.preView = view
        
        self.getAudioPermissions()
        //            print("Setting-Privacy-Microphone Get Microphone Permission")
        
        //
        self.getVideoPermissions()
        //            print("Setting-Privacy-Camera Get Camera Permission")
        //        }
        
        let pinch = UIPinchGestureRecognizer(target: self, action:#selector(self.pinchDetected))
        view.addGestureRecognizer(pinch)
        
        
    }
    
    @objc func pinchDetected(recognizer: UIPinchGestureRecognizer) {
        
        if (recognizer.state == .began) {
            currentPinchZoomFactor = self.pushKit.zoomScale
        }
        let zoomFactor = currentPinchZoomFactor * recognizer.scale//当前触摸缩放因子*坐标比例
        self.pushKit.zoomScale = (zoomFactor < 1) ? 1 : ((zoomFactor > 3) ? 3 : zoomFactor)
        
    }
    
    private func getAudioPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for:AVMediaType.audio)
        switch status  {
        // 许可对话没有出现，发起授权许可
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted) in
                
            })
            break;
        // 已经开启授权，可继续
        case AVAuthorizationStatus.authorized:
            break;
        // 用户明确地拒绝授权，或者相机设备无法访问
        case AVAuthorizationStatus.denied: break
        case AVAuthorizationStatus.restricted:break;
        default:
            break;
        }
    }
    
    private func getVideoPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video);
        switch status  {
        // 许可对话没有出现，发起授权许可
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted) in
                if(granted){
                    DispatchQueue.main.async {
                        self.pushKit.running = true
                    }
                }
            })
            break;
        // 已经开启授权，可继续
        case AVAuthorizationStatus.authorized:
            self.pushKit.running = true;
            break;
        // 用户明确地拒绝授权，或者相机设备无法访问
        case AVAuthorizationStatus.denied: break
        case AVAuthorizationStatus.restricted:break;
        default:
            break;
        }
    }
    
    
    
    deinit
    {
        //        self.pushKit?.stopPreview()
        //        self.pushKit?.streamerBase.stopStream()
        //        NotificationCenter.default.removeObserver(self)
    }
    
    
    func getCurrentFps() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            //			if let kit = self.pushKit {
            //				if(timer == self.timer) {
            //					let kbps = kit.streamerBase.currentUploadingKbps
            //					let fps = kit.streamerBase.encodingFPS
            //                    if(kbps>0 && fps>0) {
            //                        self.retryCounts = 0
            //                    }
            //                    if(!isProd) {
            //                        self.delegate?.handleBps?(kbps: kbps, fps: fps)
            //                    }
            //				} else {
            //					timer.invalidate()
            //				}
            //			}
        }
    }
    
    @objc public func isOnAir() -> Bool {
        return self.onAir
    }
    
    @objc public func switchCamera()
    {
        let devicePositon = self.pushKit.captureDevicePosition
        self.pushKit.captureDevicePosition = (devicePositon == .front) ?  .back : .front
    }
    
    
    
    
    @objc public func startLive(_ isEncode: Bool = false, auth: String? = nil, pwd: String? = nil)
    {
        
        let pushSrv  = "push"
        guard let url = self.getPushUrl(server: pushSrv, auth: auth, pwd: pwd)  else {
            return
        }
        
        self.hostUrl = url
        
        self.pushStart(url: self.hostUrl, isEncode: isEncode)
        
    }
    
    private func getPushUrl(server: String, auth: String?, pwd: String?) -> URL?
    {
        var _server = server
        let params = _server.components(separatedBy: "://")
        if let _auth = auth,
           let _pwd = pwd,
           let addr = params.last {
            _server = "rtmp://" + _auth + ":" + _pwd + "@" + String(addr)
        }
        if let url = URL(string: _server) {
            return url
        }
        return nil
    }
    
    private func pushStart(url: URL, isEncode: Bool = false)
    {
        self.retryCounts = 0
        
        let stream = LFLiveStreamInfo()
        stream.url = url.absoluteString
        self.pushKit.startLive(stream, isEnc: isEncode)
        
        self.delegate?.handleLogMsg?(msg: "live Start")
        self.onAir = true
    }
    
    @objc public func stopLive()
    {
        self.pushKit.stopLive()
        self.onAir = false
        
        self.delegate?.handleLogMsg?(msg: "live Stop")
        
        self.delegate?.handleStopLiveOK?()
        
        let devicePositon = self.pushKit.captureDevicePosition
        if(devicePositon != .front) {
            self.pushKit.captureDevicePosition = .front
        }
    }
    
    @objc private func enterBg(not: Notification) {
        if(!self.onAir) {
            self.pushKit.running = false
        }
    }
    
    @objc private func becameActive(not: Notification) {
        self.pushKit.running = true
    }
    
    //MARK: - Callbacks
    
    // 回调
    func liveSession(_ session: LFLiveSession?, debugInfo: LFLiveDebug?) {
        print("debugInfo: \(debugInfo?.currentBandwidth)")
    }
    
    func liveSession(_ session: LFLiveSession?, errorCode: LFLiveSocketErrorCode) {
        print("errorCode: \(errorCode.rawValue)")
        self.delegate?.handleLogMsg?(msg: "errorCode: \(errorCode.rawValue)")
        
    }
    
    func liveSession(_ session: LFLiveSession?, liveStateDidChange state: LFLiveState) {
        print("liveStateDidChange: \(state.rawValue)")
        self.delegate?.handleLogMsg?(msg: "stream State \(state.rawValue)")
        switch state {
        case .ready:
            //"未连接"
            break;
        case .pending:
            // "连接中"
            break;
        case .start:
            // "已连接"
            break;
        case .error:
            // "连接错误"
            break;
        case .stop:
            //"未连接"
            break;
        default:
            break;
        }
    }
    
    func handleVideo(_ session: LFLiveSession?, frame: CVPixelBuffer?) {
        if let _frame = frame {
            //use beauty filter
            
            //            tiFilter.renderTiSDK(_frame)
        }
        
    }
}



