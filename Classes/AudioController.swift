//
//  AudioController.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//
/*

     File: AudioController.h
     File: AudioController.mm
 Abstract: This class demonstrates the audio APIs used to capture audio data from the microphone and play it out to the speaker. It also demonstrates how to play system sounds
  Version: 2.0

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.


 */

// Framework includes
import AudioToolbox
import AVFoundation


@objc protocol AURenderCallbackDelegate {
    func performRender(_ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        inTimeStamp: UnsafePointer<AudioTimeStamp>,
        inBufNumber: UInt32,
        inNumberFrames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus
}

private let AudioController_RenderCallback: AURenderCallback = {(inRefCon,
        ioActionFlags/*: UnsafeMutablePointer<AudioUnitRenderActionFlags>*/,
        inTimeStamp/*: UnsafePointer<AudioTimeStamp>*/,
        inBufNumber/*: UInt32*/,
        inNumberFrames/*: UInt32*/,
        ioData/*: UnsafeMutablePointer<AudioBufferList>*/)
    -> OSStatus
in
    let delegate = unsafeBitCast(inRefCon, to: AURenderCallbackDelegate.self)
    let result = delegate.performRender(ioActionFlags,
        inTimeStamp: inTimeStamp,
        inBufNumber: inBufNumber,
        inNumberFrames: inNumberFrames,
        ioData: ioData!)
    return result
}


@objc(AudioController)
class AudioController: NSObject, AURenderCallbackDelegate {
    
    var _rioUnit: AudioUnit? = nil
    var _bufferManager: BufferManager!
    var _dcRejectionFilter: DCRejectionFilter!
    var _audioPlayer: AVAudioPlayer?   // for button pressed sound
    
    var muteAudio: Bool
    private(set) var audioChainIsBeingReconstructed: Bool = false
    
    enum aurioTouchDisplayMode {
        case oscilloscopeWaveform
        case oscilloscopeFFT
        case spectrum
    }
    
    // Render callback function
    func performRender(
        _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        inTimeStamp: UnsafePointer<AudioTimeStamp>,
        inBufNumber: UInt32,
        inNumberFrames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus
    {
        let ioPtr = UnsafeMutableAudioBufferListPointer(ioData)
        var err: OSStatus = noErr
        if !audioChainIsBeingReconstructed {
            // we are calling AudioUnitRender on the input bus of AURemoteIO
            // this will store the audio data captured by the microphone in ioData
            err = AudioUnitRender(_rioUnit!, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData)
            
            // filter out the DC component of the signal
            _dcRejectionFilter?.processInplace(UnsafeMutablePointer(ioPtr[0].mData!), numFrames: inNumberFrames)
            
            // based on the current display mode, copy the required data to the buffer manager
            if _bufferManager.displayMode == .oscilloscopeWaveform {
                _bufferManager.copyAudioDataToDrawBuffer(UnsafeMutablePointer(ioPtr[0].mData), inNumFrames: Int(inNumberFrames))
                
            } else if _bufferManager.displayMode == .spectrum || _bufferManager.displayMode == .oscilloscopeFFT {
                if _bufferManager.needsNewFFTData {
                    _bufferManager.CopyAudioDataToFFTInputBuffer(UnsafeMutablePointer(ioPtr[0].mData!), numFrames: Int(inNumberFrames))
                }
            }
            
            // mute audio if needed
            if muteAudio {
                for i in 0..<ioPtr.count {
                    memset(ioPtr[i].mData, 0, Int(ioPtr[i].mDataByteSize))
                }
            }
        }
        
        return err;
    }
    
    
    override init() {
        _bufferManager = nil
        _dcRejectionFilter = nil
        muteAudio = true
        super.init()
        self.setupAudioChain()
    }
    
    
    func handleInterruption(_ notification: Notification) {
//        do {
            let theInterruptionType = (notification as NSNotification).userInfo![AVAudioSessionInterruptionTypeKey] as! UInt
            NSLog("Session interrupted > --- %@ ---\n", theInterruptionType == AVAudioSessionInterruptionType.began.rawValue ? "Begin Interruption" : "End Interruption")
            
            if theInterruptionType == AVAudioSessionInterruptionType.began.rawValue {
                self.stopIOUnit()
            }
            
            if theInterruptionType == AVAudioSessionInterruptionType.ended.rawValue {
                // make sure to activate the session
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch let error as NSError {
                    NSLog("AVAudioSession set active failed with error: %@", error)
                } catch {
                    fatalError()
                }
                
                self.startIOUnit()
            }
//        } catch let e as CAXException {
//            fputs("Error: \(e.mOperation) (\(e.formatError()))\n", stderr)
//        }
    }
    
    
    func handleRouteChange(_ notification: Notification) {
        let reasonValue = (notification as NSNotification).userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
        let routeDescription = (notification as NSNotification).userInfo![AVAudioSessionRouteChangePreviousRouteKey] as! AVAudioSessionRouteDescription?
        
        NSLog("Route change:")
        if let reason = AVAudioSessionRouteChangeReason(rawValue: reasonValue) {
            switch reason {
            case .newDeviceAvailable:
                NSLog("     NewDeviceAvailable")
            case .oldDeviceUnavailable:
                NSLog("     OldDeviceUnavailable")
            case .categoryChange:
                NSLog("     CategoryChange")
                NSLog(" New Category: %@", AVAudioSession.sharedInstance().category)
            case .override:
                NSLog("     Override")
            case .wakeFromSleep:
                NSLog("     WakeFromSleep")
            case .noSuitableRouteForCategory:
                NSLog("     NoSuitableRouteForCategory")
            case .routeConfigurationChange:
                NSLog("     RouteConfigurationChange")
            case .unknown:
                NSLog("     Unknown")
            }
        } else {
            NSLog("     ReasonUnknown(%zu)", reasonValue)
        }
        
        if let prevRout = routeDescription {
            NSLog("Previous route:\n")
            NSLog("%@", prevRout)
        }
    }
    
    func handleMediaServerReset(_ notification: Notification) {
        NSLog("Media server has reset")
        audioChainIsBeingReconstructed = true
        
        usleep(25000) //wait here for some time to ensure that we don't delete these objects while they are being accessed elsewhere
        
        // rebuild the audio chain
        _bufferManager = nil
        _dcRejectionFilter = nil
        _audioPlayer = nil
        
        self.setupAudioChain()
        self.startIOUnit()
        
        audioChainIsBeingReconstructed = false
    }
    
    private func setupAudioSession() {
        do {
            // Configure the audio session
            let sessionInstance = AVAudioSession.sharedInstance()
            
            // we are going to play and record so we pick that category
            do {
                try sessionInstance.setCategory(AVAudioSessionCategoryPlayAndRecord)
            } catch let error as NSError {
                try XExceptionIfError(error, "couldn't set session's audio category")
            } catch {
                fatalError()
            }
            
            // set the buffer duration to 5 ms
            let bufferDuration: TimeInterval = 0.005
            do {
                try sessionInstance.setPreferredIOBufferDuration(bufferDuration)
            } catch let error as NSError {
                try XExceptionIfError(error, "couldn't set session's I/O buffer duration")
            } catch {
                fatalError()
            }
            
            do {
                // set the session's sample rate
                try sessionInstance.setPreferredSampleRate(44100)
            } catch let error as NSError {
                try XExceptionIfError(error, "couldn't set session's preferred sample rate")
            } catch {
                fatalError()
            }
            
            // add interruption handler
            NotificationCenter.default.addObserver(self,
                selector: #selector(AudioController.handleInterruption(_:)),
                name: NSNotification.Name.AVAudioSessionInterruption,
                object: sessionInstance)
            
            // we don't do anything special in the route change notification
            NotificationCenter.default.addObserver(self,
                selector: #selector(AudioController.handleRouteChange(_:)),
                name: NSNotification.Name.AVAudioSessionRouteChange,
                object: sessionInstance)
            
            // if media services are reset, we need to rebuild our audio chain
            NotificationCenter.default.addObserver(self,
                selector: #selector(AudioController.handleMediaServerReset(_:)),
                name: NSNotification.Name.AVAudioSessionMediaServicesWereReset,
                object: sessionInstance)
            
            do {
                // activate the audio session
                try sessionInstance.setActive(true)
            } catch let error as NSError {
                try XExceptionIfError(error, "couldn't set session active")
            } catch {
                fatalError()
            }
        } catch let e as CAXException {
            NSLog("Error returned from setupAudioSession: %d: %@", Int32(e.mError), e.mOperation)
        } catch _ {
            NSLog("Unknown error returned from setupAudioSession")
        }
        
    }
    
    
    private func setupIOUnit() {
        do {
            // Create a new instance of AURemoteIO
            
            var desc = AudioComponentDescription(
                componentType: OSType(kAudioUnitType_Output),
                componentSubType: OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                componentFlags: 0,
                componentFlagsMask: 0)
            
            let comp = AudioComponentFindNext(nil, &desc)
            try XExceptionIfError(AudioComponentInstanceNew(comp!, &self._rioUnit), "couldn't create a new instance of AURemoteIO")
            
            //  Enable input and output on AURemoteIO
            //  Input is enabled on the input scope of the input element
            //  Output is enabled on the output scope of the output element
            
            var one: UInt32 = 1
            try XExceptionIfError(AudioUnitSetProperty(self._rioUnit!, AudioUnitPropertyID(kAudioOutputUnitProperty_EnableIO), AudioUnitScope(kAudioUnitScope_Input), 1, &one, SizeOf32(one)), "could not enable input on AURemoteIO")
            try XExceptionIfError(AudioUnitSetProperty(self._rioUnit!, AudioUnitPropertyID(kAudioOutputUnitProperty_EnableIO), AudioUnitScope(kAudioUnitScope_Output), 0, &one, SizeOf32(one)), "could not enable output on AURemoteIO")
            
            // Explicitly set the input and output client formats
            // sample rate = 44100, num channels = 1, format = 32 bit floating point
            
            var ioFormat = CAStreamBasicDescription(sampleRate: 44100, numChannels: 1, pcmf: .float32, isInterleaved: false)
            try XExceptionIfError(AudioUnitSetProperty(self._rioUnit!, AudioUnitPropertyID(kAudioUnitProperty_StreamFormat), AudioUnitScope(kAudioUnitScope_Output), 1, &ioFormat, SizeOf32(ioFormat)), "couldn't set the input client format on AURemoteIO")
            try XExceptionIfError(AudioUnitSetProperty(self._rioUnit!, AudioUnitPropertyID(kAudioUnitProperty_StreamFormat), AudioUnitScope(kAudioUnitScope_Input), 0, &ioFormat, SizeOf32(ioFormat)), "couldn't set the output client format on AURemoteIO")
            
            // Set the MaximumFramesPerSlice property. This property is used to describe to an audio unit the maximum number
            // of samples it will be asked to produce on any single given call to AudioUnitRender
            var maxFramesPerSlice: UInt32 = 4096
            try XExceptionIfError(AudioUnitSetProperty(self._rioUnit!, AudioUnitPropertyID(kAudioUnitProperty_MaximumFramesPerSlice), AudioUnitScope(kAudioUnitScope_Global), 0, &maxFramesPerSlice, SizeOf32(UInt32.self)), "couldn't set max frames per slice on AURemoteIO")
            
            // Get the property value back from AURemoteIO. We are going to use this value to allocate buffers accordingly
            var propSize = SizeOf32(UInt32.self)
            try XExceptionIfError(AudioUnitGetProperty(self._rioUnit!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, &propSize), "couldn't get max frames per slice on AURemoteIO")
            
            self._bufferManager = BufferManager(maxFramesPerSlice: Int(maxFramesPerSlice))
            self._dcRejectionFilter = DCRejectionFilter()
            
            
            // Set the render callback on AURemoteIO
            var renderCallback = AURenderCallbackStruct(
                inputProc: AudioController_RenderCallback,
                inputProcRefCon: UnsafeMutablePointer(unsafeAddress(of: self))
            )
            try XExceptionIfError(AudioUnitSetProperty(self._rioUnit!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallback, sizeofValue(renderCallback).ui), "couldn't set render callback on AURemoteIO")
            
            // Initialize the AURemoteIO instance
            try XExceptionIfError(AudioUnitInitialize(self._rioUnit!), "couldn't initialize AURemoteIO instance")
        } catch let e as CAXException {
            NSLog("Error returned from setupIOUnit: %d: %@", e.mError, e.mOperation)
        } catch _ {
            NSLog("Unknown error returned from setupIOUnit")
        }
        
    }
    
    private func createButtonPressedSound() {
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: "button_press", ofType: "caf")!)
        do {
            _audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch let error as NSError {
            XFailIfError(error, "couldn't create AVAudioPlayer")
            _audioPlayer = nil
        }
        
    }
    
    func playButtonPressedSound() {
        _audioPlayer?.play()
    }
    
    private func setupAudioChain() {
        self.setupAudioSession()
        self.setupIOUnit()
        self.createButtonPressedSound()
    }
    
    @discardableResult
    func startIOUnit() -> OSStatus {
        let err = AudioOutputUnitStart(_rioUnit!)
        if err != 0 {NSLog("couldn't start AURemoteIO: %d", Int32(err))}
        return err
    }
    
    @discardableResult
    func stopIOUnit() -> OSStatus {
        let err = AudioOutputUnitStop(_rioUnit!)
        if err != 0 {NSLog("couldn't stop AURemoteIO: %d", Int32(err))}
        return err
    }
    
    var sessionSampleRate: Double {
        return AVAudioSession.sharedInstance().sampleRate
    }
    
    var bufferManagerInstance: BufferManager {
        return _bufferManager
    }
    
}
