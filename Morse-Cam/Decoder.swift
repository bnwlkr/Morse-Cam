//
//  Decoder.swift
//  FlashChat
//
//  Created by Ben Walker on 2020-10-03.
//  Copyright © 2020 bnwlkr. All rights reserved.
//

import Foundation
import AVFoundation

protocol DecoderDelegate {
	func charReceived (char: String)
}

class Decoder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
	
	private var lowBar: Double = -10.0
	private var highBar: Double = 10.0
	private var recalc = 5.0
    
    private var recvTimeout: Timer? = nil
	
	
	private var currentBit = -1
	private var currentCount = 0
	
	private let morse = Morse()
	
	private var currentCode = ""
	private var reading = false
	
	var delegate: DecoderDelegate!
	
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
		let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
		let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
		let brightnessValue : Double = exifData?[kCGImagePropertyExifBrightnessValue as String] as! Double
		let time = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer).seconds
		self.processBrightness(time: time, value: brightnessValue)
	}
	
	
	func processBrightness(time: Double, value: Double) {
		let lowDist = abs(value - self.lowBar)
		let highDist = abs(value - self.highBar)
		if lowDist <= highDist {
			received(bit: 0)
			if value > lowBar {
				highBar -= highDist / recalc
				lowBar += lowDist / recalc
			} else {
				lowBar -= lowDist / recalc
			}
		} else {
			received(bit: 1)
			if value < highBar {
				lowBar += lowDist / recalc
				highBar -= highDist / recalc
			} else {
				highBar += highDist / recalc
			}
		}
	}
    
    func forward(char: String) {
        self.delegate.charReceived(char: char)
        DispatchQueue.main.async {
            print("forward: ", char)
            self.recvTimeout?.invalidate()
            self.recvTimeout = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) {_ in
                print("timeout")
                self.delegate.charReceived(char: "\n")
                self.reading = false
            }
            if char == "\n" {
                self.recvTimeout?.invalidate()
            }
        }
    }
    
	func received(bit: Int) {
		if bit == currentBit && Double(currentCount) <= WORD_GAP {
			currentCount += 1
		} else {
			if currentBit == 1 {  // dit or dah
				let ditDist = abs(Double(currentCount) - DIT_LENGTH)
				let dahDist = abs(Double(currentCount) - DAH_LENGTH)
				if min(ditDist, dahDist) == ditDist {
                    currentCode += "."
				} else {
					currentCode += "-"
				}
			} else {
				let charDist = abs(Double(currentCount) - DIT_DAH_GAP)
				let letterDist = abs(Double(currentCount) - LETTER_GAP)
				let wordDist = abs(Double(currentCount) - WORD_GAP)
				if min(charDist, letterDist, wordDist) == charDist {
					//currentCode += " "
				} else if min(charDist, letterDist, wordDist) == letterDist {
                    if reading {
                        if let char = Morse.chars[currentCode] {
                            forward(char: char)
                        }
                    } else {
                        if currentCode == Morse.ATTENTION {
                            forward(char: "\u{200B}")
                            reading = true
                        }
                    }
					currentCode = ""
                } else {
                    if reading {
                        if currentCode == Morse.OVER {
                            forward(char: "\n")
                            reading = false
                        } else if let char = Morse.chars[currentCode] {
                            forward(char: char)
                            forward(char: " ")
                        }
                    }
                    currentCode = ""
				}
			}
			currentBit = bit
			currentCount = 1
		}
	}
	
	

}
