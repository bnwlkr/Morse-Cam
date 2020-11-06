//
//  Encoder.swift
//  FlashChat
//
//  Created by Ben Walker on 2020-10-11.
//  Copyright © 2020 bnwlkr. All rights reserved.
//

import Foundation
import AVFoundation


protocol EncoderDelegate {
    func encoderTransmitted(progress: Float)
}

class Encoder {
	private var torchDevice: AVCaptureDevice?
    private var currentMessage: [Bool] = []
    private var index = 0
    private var timer: Timer!
    var transmitting = false
    var delegate: EncoderDelegate!
	
	init() {
        self.torchDevice = AVCaptureDevice.default(for: AVMediaType.video)
	}
	
	
	func transmit(message: String) {
        self.transmitting = true
		var morse = Array<String>(message.map { String($0).uppercased() }).map { Morse.codes[$0] ?? "" }
        morse = [".-.", "/", Morse.ATTENTION] + morse + [Morse.OVER]
        for (i,letter) in morse.enumerated() {
            if letter == "/" {
                currentMessage.append(contentsOf: Array<Bool>(repeating: false, count: Int(WORD_GAP)-Int(LETTER_GAP)))
                continue
            }
            for (j,elem) in letter.enumerated() {
				if elem == "." {
                    currentMessage.append(contentsOf: Array<Bool>(repeating: true, count: Int(DIT_LENGTH)))
                } else if elem == "-" {
                    currentMessage.append(contentsOf: Array<Bool>(repeating: true, count: Int(DAH_LENGTH)))
                }
                if j != letter.count - 1 {
                    currentMessage.append(contentsOf: Array<Bool>(repeating: false, count: Int(DIT_DAH_GAP)))
                }
			}
            if i != morse.count - 1 {
                currentMessage.append(contentsOf: Array<Bool>(repeating: false, count: Int(LETTER_GAP)))
            }
		}
        if self.torchDevice != nil {
            timer = Timer.scheduledTimer(timeInterval: DOT_DURATION / 3, target: self, selector: #selector(timerTick), userInfo: nil, repeats: true)
        }
	}
	
	
    @objc func timerTick() {
        if currentMessage[index] && torchDevice!.torchMode != .on {
            toggleFlash()
        } else if !currentMessage[index] && torchDevice!.torchMode != .off {
            toggleFlash()
        }
        self.delegate.encoderTransmitted(progress: Float(index)/Float(currentMessage.count-1))
        if index == currentMessage.count - 1 {
            timer.invalidate()
            toggleFlash()
            index = 0
            self.currentMessage = []
            transmitting = false
        } else {
            index += 1
        }
    }
	
    func toggleFlash() {
        guard let torchDevice = self.torchDevice, torchDevice.isTorchAvailable else {
            NSLog("No torch is available on this device.")
            return
        }
                
        do {
            try torchDevice.lockForConfiguration()
            defer {
                torchDevice.unlockForConfiguration()
            }
            
            switch torchDevice.torchMode {
            case .on:
                torchDevice.torchMode = .off
                
            case .off, .auto:
                try torchDevice.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                
            @unknown default:
                NSLog("Code requires update for a new case in \(AVCaptureDevice.TorchMode.self).")
            }
        } catch {
            NSLog("Failed to change the torch level: \(error)")
        }
    }
}
