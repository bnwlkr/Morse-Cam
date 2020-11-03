//
//  ViewController.swift
//  FlashChat
//
//  Created by Ben Walker on 2020-10-02.
//  Copyright © 2020 bnwlkr. All rights reserved.
//

import UIKit
import AVFoundation

class VideoViewController: UIViewController, DecoderDelegate, UITextFieldDelegate, EncoderDelegate {
    	
    private let session = AVCaptureSession()
	private let sessionQueue = DispatchQueue(label: "sessionq")
	private let videoDataOutputQueue = DispatchQueue(label: "videoq")
	private let decoder = Decoder()
    private let encoder = Encoder()
    
    private var transmitting = false
	
	private var videoDevice: AVCaptureDevice!
	private var videoDataOutput: AVCaptureVideoDataOutput!
	private var videoDeviceInput: AVCaptureDeviceInput!
    
    @IBOutlet weak var keyboardHeightLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputField: UITextField!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var recieveView: UITextView!
    
    let recieveViewAtts = [
        NSAttributedString.Key.backgroundColor: UIColor.secondarySystemBackground.withAlphaComponent(0.8),
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 40.0, weight: UIFont.Weight.heavy),
        NSAttributedString.Key.foregroundColor: UIColor.label
    ]
    
	
	@IBOutlet var previewView: PreviewView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.authorizeCamera()
        NotificationCenter.default.addObserver(self,
           selector: #selector(self.keyboardNotification(notification:)),
           name: UIResponder.keyboardWillChangeFrameNotification,
           object: nil)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
		self.previewView.session = self.session
		self.decoder.delegate = self
        self.encoder.delegate = self
        self.previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
		sessionQueue.async {
			self.configureSession()
			self.session.startRunning()
		}
        self.inputField.delegate = self
	}
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        
        let duration:TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
        let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        let animationCurve:UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)

        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let endFrameY = endFrame?.origin.y ?? 0
        
        var keyboardOffset: CGFloat = 15.0
        
        if ["iPhone XS", "iPhone XS Max", "iPhone XR", "iPhone 11", "iPhone 11 Pro", "iPhone 11 Pro Max", "iPhone 12 mini", "iPhone 12", "iPhone 12 Pro", "iPhone 12 Pro Max"].contains(UIDevice.modelName) {
            keyboardOffset = -5.0
        }
        
        print(UIDevice.modelName, keyboardOffset)
        
        
        if endFrameY >= UIScreen.main.bounds.size.height {
            self.keyboardHeightLayoutConstraint?.constant = 15.0
        } else {
            self.keyboardHeightLayoutConstraint?.constant = (endFrame?.size.height ?? 0) + keyboardOffset
        }

        UIView.animate(
            withDuration: duration,
            delay: TimeInterval(0),
            options: animationCurve,
            animations: { self.view.layoutIfNeeded() },
            completion: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let msg = inputField.text {
            if msg != "" && !encoder.transmitting {
                UIView.animate(withDuration: 1.0) {
                    self.progressView.alpha = 1.0
                }
                self.progressView.setProgress(0.0, animated: false)
                encoder.transmit(message: msg)
            }
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string == "" { return true }
        return Morse.codes.keys.contains(string.uppercased())
    }
    
    func charReceived(char: String) {
        DispatchQueue.main.async {
            let attributed = NSMutableAttributedString(attributedString: self.recieveView.attributedText)
            if char == "\n" {
                attributed.append(NSAttributedString(string: "\n"))
                self.transmitting = false
            } else {
                attributed.append(NSAttributedString(string: char, attributes: self.recieveViewAtts))
            }
            self.recieveView.attributedText = attributed
            self.recieveView.scrollRangeToVisible(NSMakeRange(self.recieveView.text.count-1, 1))
        }
	}
    
    func encoderTransmitted(progress: Float) {
        self.progressView.setProgress(progress, animated: true)
        if progress == 1.0 {
            UIView.animate(withDuration: 1.0) {
                self.progressView.alpha = 0.0
            }
        }
    }
	
	
	func authorizeCamera() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("camera authorized")
            break
            
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    print("dude wtf")
                }
                self.sessionQueue.resume()
                print("camera authorized")
            })
            
        default:
            print("dude wtf")
        }
	}
	

	func configureSession() {
		session.beginConfiguration()
		self.videoDevice = AVCaptureDevice.default(for: AVMediaType.video)!
		do {
			let videoDeviceInput = try AVCaptureDeviceInput(device: self.videoDevice)
			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput
			} else {
				print("Failed to add video device input")
			}
            try self.videoDevice.lockForConfiguration()
            self.videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(FPS))
            self.videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(FPS))
            self.videoDevice.unlockForConfiguration()
		} catch {
			print(error)
		}
		
        
        
		self.videoDataOutput = AVCaptureVideoDataOutput()
		self.videoDataOutput.setSampleBufferDelegate(self.decoder, queue: self.videoDataOutputQueue)
		
		if session.canAddOutput(self.videoDataOutput) {
			session.addOutput(self.videoDataOutput)
		} else {
			print("Failed to add video device input")
		}
		
		self.videoDataOutput.connection(with: .video)?.isEnabled = true
		
		self.session.commitConfiguration()
		print("finished session setup")
	}

}

