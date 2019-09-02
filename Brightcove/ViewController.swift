import UIKit
import BrightcovePlayerSDK

let kViewControllerPlaybackServicePolicyKey = "BCpkADawqM1W-vUOMe6RSA3pA6Vw-VWUNn5rL0lzQabvrI63-VjS93gVUugDlmBpHIxP16X8TSe5LSKM415UHeMBmxl7pqcwVY_AZ4yKFwIpZPvXE34TpXEYYcmulxJQAOvHbv2dpfq-S_cm"
let kViewControllerAccountID = "3636334163001"
let kViewControllerVideoID = "3666678807001"

class ViewController: UIViewController, BCOVPlaybackControllerDelegate {

    @IBOutlet weak var btn: UIButton!
    @IBOutlet weak var Lbl: UILabel!
    @IBOutlet weak var Slider: UISlider!
    
    
    let sharedSDKManager = BCOVPlayerSDKManager.shared()
    let playbackService = BCOVPlaybackService(accountId: kViewControllerAccountID, policyKey: kViewControllerPlaybackServicePolicyKey)
    let playbackController :BCOVPlaybackController
    var customPlayer : AVPlayer?
    @IBOutlet weak var videoContainerView: UIView!

    required init?(coder aDecoder: NSCoder) {
        playbackController = (sharedSDKManager?.createPlaybackController())!

        super.init(coder: aDecoder)

        playbackController.analytics.account = kViewControllerAccountID // Optional

        playbackController.delegate = self
        playbackController.isAutoAdvance = true
        playbackController.isAutoPlay = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        btn.setTitle("播放", for: .normal)
        btn.setTitle("暂停", for: .selected)
        btn.setTitle("不可用", for: .disabled)
        btn.addTarget(self, action: #selector(pauseButtonSelected(sender:)), for: .touchUpInside)
        btn.isEnabled = false
        
        Slider.addTarget(self, action: #selector(sliderValueChange(sender:)), for: .valueChanged)
        
        
        // Set up our player view. Create with a standard VOD layout.
        guard let playerView = BCOVPUIPlayerView(playbackController: self.playbackController, options: nil, controlsView: BCOVPUIBasicControlView.withVODLayout()) else {
            return
        }

        // Install in the container view and match its size.
        self.videoContainerView.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: self.videoContainerView.topAnchor),
            playerView.rightAnchor.constraint(equalTo: self.videoContainerView.rightAnchor),
            playerView.leftAnchor.constraint(equalTo: self.videoContainerView.leftAnchor),
            playerView.bottomAnchor.constraint(equalTo: self.videoContainerView.bottomAnchor)
            ])

        // Associate the playerView with the playback controller.
        playerView.playbackController = playbackController

        let newControlLayout = BCOVPUIControlLayout.init()

        playerView.controlsView.layout = newControlLayout

        requestContentFromPlaybackService()
    }

    func requestContentFromPlaybackService() {
        playbackService?.findVideo(withVideoID: kViewControllerVideoID, parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in

            if let v = video {
                self.playbackController.setVideos([v] as NSArray)
                print("add One To Player")
            } else {
                print("ViewController Debug - Error retrieving video: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
    
    func playbackController(_ controller: BCOVPlaybackController!, didAdvanceTo session: BCOVPlaybackSession!) {
//        如果session不存在就说明加载失败喽
        self.customPlayer = session!.player
        self.customPlayer!.currentItem!.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        self.customPlayer!.currentItem!.addObserver(self, forKeyPath: "loadedTimeRanges", options: .new, context: nil)
        self.customPlayer!.currentItem!.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        self.customPlayer?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: DispatchQueue.main, using: { (time) in
            let loadingTime = CMTimeGetSeconds(time)
            let totalTime = CMTimeGetSeconds(self.customPlayer!.currentItem!.duration)
            self.Slider.value = Float(loadingTime/totalTime)
            self.Lbl.text = "\(self.changeFormat(timeInterval: loadingTime))/\(self.changeFormat(timeInterval: totalTime))"
        })
    }
    
    @objc func pauseButtonSelected(sender:UIButton)  {
        sender.isSelected = !sender.isSelected
        if sender.isSelected{
            print("play")
            self.customPlayer?.play()
        }else{
            print("Pause")
            self.customPlayer?.pause()
        }
    }
    
    private func changeFormat(timeInterval:TimeInterval) -> String{
        return String(format: "%02d:%02d:%02d",(Int(timeInterval) % 3600) / 60, Int(timeInterval) / 3600,Int(timeInterval) % 60)
    }
    
    @objc func sliderValueChange(sender:UISlider){
        if self.btn.isEnabled {
            let time = Float64(sender.value) * CMTimeGetSeconds(self.customPlayer!.currentItem!.duration)
            let seekTime = CMTimeMake(value: Int64(time), timescale: 1)
            self.customPlayer!.seek(to: seekTime)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            switch self.customPlayer!.status{
            case .readyToPlay:
                print("准备好了")
                if !self.btn.isEnabled {
                    let totalTime = CMTimeGetSeconds(self.customPlayer!.currentItem!.duration)
                    self.Lbl.text = "00:00:00/\(self.changeFormat(timeInterval: totalTime))"
                    Slider.value = 0.0
                }
                self.btn.isEnabled = true
            case .failed:
                print("加载失败了")
            case.unknown:
                print("未知错误")
            default:
                print("其他未知错误")
            }
        }else if keyPath == "playbackLikelyToKeepUp" {
            print("加载完毕")
            if self.btn.titleLabel?.text == "暂停" {
                self.customPlayer?.play()
            }
        }else if keyPath == "loadedTimeRanges" {
            print("加载中")
        }else {
            print("不可能")
        }
    }
    
}


