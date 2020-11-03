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
	private var torchDevice: AVCaptureDevice!
    private var currentMessage: [Bool] = []
    private var index = 0
    private var timer: Timer!
    var transmitting = false
    var delegate: EncoderDelegate!
	
	init() {
		let torchDeviceMaybe = AVCaptureDevice.default(for: AVMediaType.video)
        if torchDeviceMaybe != nil {
            self.torchDevice = torchDeviceMaybe!
        }
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
        timer = Timer.scheduledTimer(timeInterval: DOT_DURATION / 3, target: self, selector: #selector(timerTick), userInfo: nil, repeats: true)
	}
	
	
    @objc func timerTick() {
        if currentMessage[index] && torchDevice.torchMode != .on {
            toggleFlash()
        } else if !currentMessage[index] && torchDevice.torchMode != .off {
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
		do {
			try torchDevice.lockForConfiguration()
			if (torchDevice.torchMode == AVCaptureDevice.TorchMode.on) {
				torchDevice.torchMode = AVCaptureDevice.TorchMode.off
			} else {
				do {
					try torchDevice.setTorchModeOn(level: 1.0)
				} catch {
					print(error)
				}
			}
			torchDevice.unlockForConfiguration()
		} catch {
			print(error)
		}
	}
	
}
