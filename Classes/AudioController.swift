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


@objc(AudioController)
class AudioController: NSObject {
    
    var _rioUnit: AudioUnit = AudioUnit()
    var _bufferManager: BufferManager!
    var _dcRejectionFilter: DCRejectionFilter!
    var _audioPlayer: AVAudioPlayer?   // for button pressed sound
    
    var muteAudio: Bool
    private(set) var audioChainIsBeingReconstructed: Bool = false
    
    enum aurioTouchDisplayMode {
        case OscilloscopeWaveform
        case OscilloscopeFFT
        case Spectrum
    }
    
    
    // Render callback function
    func performRender(
        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        inTimeStamp: UnsafePointer<AudioTimeStamp>,
        inBufNumber: UInt32,
        inNumberFrames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus
    {
        var err: OSStatus = noErr
        if !audioChainIsBeingReconstructed {
            // we are calling AudioUnitRender on the input bus of AURemoteIO
            // this will store the audio data captured by the microphone in ioData
            err = AudioUnitRender(_rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData)
            
            // filter out the DC component of the signal
            _dcRejectionFilter?.processInplace(AudioBufferList_getDataPtr(ioData, 0), numFrames: inNumberFrames)
            
            // based on the current display mode, copy the required data to the buffer manager
            if _bufferManager.displayMode == .OscilloscopeWaveform {
                _bufferManager.copyAudioDataToDrawBuffer(AudioBufferList_getDataPtr(ioData, 0), inNumFrames: Int(inNumberFrames))
                
            } else if _bufferManager.displayMode == .Spectrum || _bufferManager.displayMode == .OscilloscopeFFT {
                if _bufferManager.needsNewFFTData {
                    _bufferManager.CopyAudioDataToFFTInputBuffer(AudioBufferList_getDataPtr(ioData, 0), numFrames: Int(inNumberFrames))
                }
            }
            
            // mute audio if needed
            if muteAudio {
                for i in 0..<Int(ioData.memory.mNumberBuffers) {
                    memset(AudioBufferList_getDataPtr(ioData, 0), 0, size_t(AudioBufferList_getDataSize(ioData, i)))
                }
            }
        }
        
        return err;
    }
    
    private var performRenderCallback: AudioController_RenderBlock?
    
    
    override init() {
        _bufferManager = nil
        _dcRejectionFilter = nil
        muteAudio = true
        super.init()
        performRenderCallback = self.performRender
        self.setupAudioChain()
    }
    
    
    func handleInterruption(notification: NSNotification) {
        oop_try {
            let theInterruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey] as UInt
            NSLog("Session interrupted > --- %@ ---\n", theInterruptionType == AVAudioSessionInterruptionType.Began.rawValue ? "Begin Interruption" : "End Interruption")
            
            if theInterruptionType == AVAudioSessionInterruptionType.Began.rawValue {
                self.stopIOUnit()
            }
            
            if theInterruptionType == AVAudioSessionInterruptionType.Ended.rawValue {
                // make sure to activate the session
                var error: NSError? = nil
                AVAudioSession.sharedInstance().setActive(true, error: &error)
                if error != nil {NSLog("AVAudioSession set active failed with error: %@", error!)}
                
                self.startIOUnit()
            }
            return nil
            }.catch {(e: CAXException) in
                fputs("Error: \(e.mOperation) (\(e.formatError()))\n", stderr)
                return nil
        }
    }
    
    
    func handleRouteChange(notification: NSNotification) {
        let reasonValue = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as UInt
        let routeDescription = notification.userInfo![AVAudioSessionRouteChangePreviousRouteKey] as AVAudioSessionRouteDescription
        
        NSLog("Route change:")
        if let reason = AVAudioSessionRouteChangeReason(rawValue: reasonValue) {
            switch reason {
            case .NewDeviceAvailable:
                NSLog("     NewDeviceAvailable")
            case .OldDeviceUnavailable:
                NSLog("     OldDeviceUnavailable")
            case .CategoryChange:
                NSLog("     CategoryChange")
                NSLog(" New Category: %@", AVAudioSession.sharedInstance().category)
            case .Override:
                NSLog("     Override")
            case .WakeFromSleep:
                NSLog("     WakeFromSleep")
            case .NoSuitableRouteForCategory:
                NSLog("     NoSuitableRouteForCategory")
            case .RouteConfigurationChange:
                NSLog("     RouteConfigurationChange")
            case .Unknown:
                NSLog("     Unknown")
            }
        } else {
            NSLog("     ReasonUnknown(%zu)", reasonValue)
        }
        
        NSLog("Previous route:\n")
        NSLog("%@", routeDescription)
    }
    
    func handleMediaServerReset(notification: NSNotification) {
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
        oop_try {
            // Configure the audio session
            let sessionInstance = AVAudioSession.sharedInstance()
            
            // we are going to play and record so we pick that category
            var error: NSError? = nil
            sessionInstance.setCategory(AVAudioSessionCategoryPlayAndRecord, error: &error)
            if let ex=XExceptionIfError(error, "couldn't set session's I/O buffer duration") {return ex}
            
            // set the buffer duration to 5 ms
            let bufferDuration: NSTimeInterval = 0.005
            sessionInstance.setPreferredIOBufferDuration(bufferDuration, error: &error)
            if let ex=XExceptionIfError(error, "couldn't set session's I/O buffer duration") {return ex}
            
            // set the session's sample rate
            sessionInstance.setPreferredSampleRate(44100, error: &error)
            if let ex=XExceptionIfError(error, "couldn't set session's preferred sample rate") {return ex}
            
            // add interruption handler
            NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "handleInterruption:",
                name: AVAudioSessionInterruptionNotification,
                object: sessionInstance)
            
            // we don't do anything special in the route change notification
            NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "handleRouteChange:",
                name: AVAudioSessionRouteChangeNotification,
                object: sessionInstance)
            
            // if media services are reset, we need to rebuild our audio chain
            NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "handleMediaServerReset:",
                name: AVAudioSessionMediaServicesWereResetNotification,
                object: sessionInstance)
            
            // activate the audio session
            sessionInstance.setActive(true, error: &error)
            if let ex=XExceptionIfError(error, "couldn't set session active") {return ex}
            return nil
        }
        
        .catch {(e: CAXException) in
            NSLog("Error returned from setupAudioSession: %d: %@", Int32(e.mError), e.mOperation)
            return nil
        }
        .catch {t in
            NSLog("Unknown error returned from setupAudioSession")
            return nil
        }.done()
        
    }
    
    
    private func setupIOUnit() {
        oop_try {
            // Create a new instance of AURemoteIO
            
            var desc = AudioComponentDescription(
                componentType: OSType(kAudioUnitType_Output),
                componentSubType: OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                componentFlags: 0,
                componentFlagsMask: 0)
            
            let comp = AudioComponentFindNext(nil, &desc)
            if let ex=XExceptionIfError(AudioComponentInstanceNew(comp, &self._rioUnit), "couldn't create a new instance of AURemoteIO") {return ex}
            
            //  Enable input and output on AURemoteIO
            //  Input is enabled on the input scope of the input element
            //  Output is enabled on the output scope of the output element
            
            var one: UInt32 = 1
            if let ex=XExceptionIfError(AudioUnitSetProperty(self._rioUnit, AudioUnitPropertyID(kAudioOutputUnitProperty_EnableIO), AudioUnitScope(kAudioUnitScope_Input), 1, &one, SizeOf32(one)), "could not enable input on AURemoteIO") {return ex}
            if let ex=XExceptionIfError(AudioUnitSetProperty(self._rioUnit, AudioUnitPropertyID(kAudioOutputUnitProperty_EnableIO), AudioUnitScope(kAudioUnitScope_Output), 0, &one, SizeOf32(one)), "could not enable output on AURemoteIO") {return ex}
            
            // Explicitly set the input and output client formats
            // sample rate = 44100, num channels = 1, format = 32 bit floating point
            
            var ioFormat = CAStreamBasicDescription(sampleRate: 44100, numChannels: 1, pcmf: .Float32, isInterleaved: false)
            if let ex=XExceptionIfError(AudioUnitSetProperty(self._rioUnit, AudioUnitPropertyID(kAudioUnitProperty_StreamFormat), AudioUnitScope(kAudioUnitScope_Output), 1, &ioFormat, SizeOf32(ioFormat)), "couldn't set the input client format on AURemoteIO") {return ex}
            if let ex=XExceptionIfError(AudioUnitSetProperty(self._rioUnit, AudioUnitPropertyID(kAudioUnitProperty_StreamFormat), AudioUnitScope(kAudioUnitScope_Input), 0, &ioFormat, SizeOf32(ioFormat)), "couldn't set the output client format on AURemoteIO") {return ex}
            
            // Set the MaximumFramesPerSlice property. This property is used to describe to an audio unit the maximum number
            // of samples it will be asked to produce on any single given call to AudioUnitRender
            var maxFramesPerSlice: UInt32 = 4096
            if let ex=XExceptionIfError(AudioUnitSetProperty(self._rioUnit, AudioUnitPropertyID(kAudioUnitProperty_MaximumFramesPerSlice), AudioUnitScope(kAudioUnitScope_Global), 0, &maxFramesPerSlice, SizeOf32(UInt32)), "couldn't set max frames per slice on AURemoteIO") {return ex}
            
            // Get the property value back from AURemoteIO. We are going to use this value to allocate buffers accordingly
            var propSize = SizeOf32(UInt32)
            if let ex=XExceptionIfError(AudioUnitGetProperty(self._rioUnit, kAudioUnitProperty_MaximumFramesPerSlice.ui, kAudioUnitScope_Global.ui, 0, &maxFramesPerSlice, &propSize), "couldn't get max frames per slice on AURemoteIO") {return ex}
            
            self._bufferManager = BufferManager(maxFramesPerSlice: Int(maxFramesPerSlice))
            self._dcRejectionFilter = DCRejectionFilter()
            
            
            // Set the render callback on AURemoteIO
            var renderCallback = createRenderCallback(&self.performRenderCallback)
            if let ex=XExceptionIfError(AudioUnitSetProperty(self._rioUnit, kAudioUnitProperty_SetRenderCallback.ui, kAudioUnitScope_Input.ui, 0, &renderCallback, sizeofValue(renderCallback).ui), "couldn't set render callback on AURemoteIO") {return ex}
            
            // Initialize the AURemoteIO instance
            if let ex=XExceptionIfError(AudioUnitInitialize(self._rioUnit), "couldn't initialize AURemoteIO instance") {return ex}
            return nil
        }
        
        .catch {(e: CAXException) in
            NSLog("Error returned from setupIOUnit: %d: %@", e.mError, e.mOperation)
            return nil
        }
        .catch {t in
            NSLog("Unknown error returned from setupIOUnit")
            return nil
        }.done()
        
    }
    
    private func createButtonPressedSound() {
        var error: NSError? = nil
        
        let url = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("button_press", ofType: "caf")!)
        _audioPlayer = AVAudioPlayer(contentsOfURL: url, error: &error)
        
        XFailIfError(error, "couldn't create AVAudioPlayer")
        
    }
    
    func playButtonPressedSound() {
        _audioPlayer?.play()
    }
    
    private func setupAudioChain() {
        self.setupAudioSession()
        self.setupIOUnit()
        self.createButtonPressedSound()
    }
    
    func startIOUnit() -> OSStatus {
        let err = AudioOutputUnitStart(_rioUnit)
        if err != 0 {NSLog("couldn't start AURemoteIO: %d", Int32(err))}
        return err
    }
    
    func stopIOUnit() -> OSStatus {
        let err = AudioOutputUnitStop(_rioUnit)
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