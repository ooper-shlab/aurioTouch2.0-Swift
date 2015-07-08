//
//  EAGLView.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/1.
//
//
/*

     File: EAGLView.h
     File: EAGLView.mm
 Abstract: This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass
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
import Foundation
import UIKit
import OpenGLES

@objc(EAGLView)
class EAGLView: UIView {
    
    var applicationResignedActive: Bool = false
    
    private final let USE_DEPTH_BUFFER = true
    private final let SPECTRUM_BAR_WIDTH = 4
    
    
    func CLAMP<T: ArithmeticType>(min: T, _ x: T, _ max: T) -> T {return x < min ? min : (x > max ? max : x)}
    
    
    // value, a, r, g, b
    typealias ColorLevel = (interpVal: GLfloat, a: GLfloat, r: GLfloat, g: GLfloat, b: GLfloat)
    let colorLevels: [ColorLevel] = [
        (0.0, 1.0, 0.0, 0.0, 0.0),
        (0.333, 1.0, 0.7, 0.0, 0.0),
        (0.667, 1.0, 0.0, 0.0, 1.0),
        (1.0, 1.0, 0.0, 1.0, 1.0),
    ]
    
    private final let kMinDrawSamples = 64
    private final let kMaxDrawSamples = 4096
    
    
    struct SpectrumLinkedTexture {
        var texName: GLuint
        var nextTex: UnsafeMutablePointer<SpectrumLinkedTexture>
    }
    
    
    //    /* The pixel dimensions of the backbuffer */
    private var backingWidth: GLint = 0
    private var backingHeight: GLint = 0
    
    private var context: EAGLContext!
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    private var viewRenderbuffer: GLuint = 0
    private var viewFramebuffer: GLuint = 0
    
    /* OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist) */
    private var depthRenderbuffer: GLuint = 0
    
    private var animationTimer: NSTimer?
    private var animationInterval: NSTimeInterval = 0
    private var animationStarted: NSTimeInterval = 0
    
    private var sampleSizeOverlay: UIImageView!
    private var sampleSizeText: UILabel!
    
    private var initted_oscilloscope: Bool = false
    private var initted_spectrum: Bool = false
    private var texBitBuffer: UnsafeMutablePointer<UInt32> =  UnsafeMutablePointer.alloc(512)
    private var spectrumRect: CGRect = CGRect()
    
    private var bgTexture: GLuint = 0
    private var muteOffTexture: GLuint = 0
    private var muteOnTexture: GLuint = 0
    private var fftOffTexture: GLuint = 0
    private var fftOnTexture: GLuint = 0
    private var sonoTexture: GLuint = 0
    
    private var displayMode: AudioController.aurioTouchDisplayMode = .OscilloscopeFFT
    
    private var firstTex: UnsafeMutablePointer<SpectrumLinkedTexture> = nil
    
    private var pinchEvent: UIEvent?
    private var lastPinchDist: CGFloat = 0.0
    private var l_fftData: UnsafeMutablePointer<Float32> = nil
    private var oscilLine: UnsafeMutablePointer<GLfloat> = nil
    
    private var audioController: AudioController = AudioController()
    
    
    // You must implement this
    override class func layerClass() -> AnyClass {
        return CAEAGLLayer.self
    }
    
    //The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
    required init?(coder: NSCoder) {
        // Set up our overlay view that pops up when we are pinching/zooming the oscilloscope
        super.init(coder: coder)
        
        self.frame = UIScreen.mainScreen().bounds
        
        // Get the layer
        let eaglLayer = self.layer as! CAEAGLLayer
        
        eaglLayer.opaque = true
        
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking : false,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
        ]
        
        context = EAGLContext(API: .OpenGLES1)
        
        if context == nil || !EAGLContext.setCurrentContext(context) || !self.createFramebuffer() {
            fatalError("cannot initialize EAGLView")
        }
        
        // Enable multi touch so we can handle pinch and zoom in the oscilloscope
        self.multipleTouchEnabled = true
        
        l_fftData = UnsafeMutablePointer.alloc(audioController.bufferManagerInstance.FFTOutputBufferLength)
        bzero(l_fftData, size_t(audioController.bufferManagerInstance.FFTOutputBufferLength * sizeof(Float32)))
        
        oscilLine = UnsafeMutablePointer.alloc(kDefaultDrawSamples * 2)
        bzero(oscilLine, size_t(kDefaultDrawSamples * 2 * sizeof(GLfloat)))
        
        animationInterval = 1.0 / 60.0
        
        self.setupView()
        self.drawView()
        
        displayMode = .OscilloscopeWaveform
        
        // Set up our overlay view that pops up when we are pinching/zooming the oscilloscope
        var img_ui: UIImage? = nil
        // Draw the rounded rect for the bg path using this convenience function
        let bgPath = EAGLView.createRoundedRectPath(CGRectMake(0, 0, 110, 234), 15.0)
        
        let cs = CGColorSpaceCreateDeviceRGB()
        // Create the bitmap context into which we will draw
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let cxt = CGBitmapContextCreate(nil, 110, 234, 8, 4*110, cs, bitmapInfo.rawValue)
        CGContextSetFillColorSpace(cxt, cs)
        let fillClr: [CGFloat] = [0.0, 0.0, 0.0, 0.7]
        CGContextSetFillColor(cxt, fillClr)
        // Add the rounded rect to the context...
        CGContextAddPath(cxt, bgPath)
        // ... and fill it.
        CGContextFillPath(cxt)
        
        // Make a CGImage out of the context
        let img_cg = CGBitmapContextCreateImage(cxt)
        // Make a UIImage out of the CGImage
        img_ui = UIImage(CGImage: img_cg!)
        
        // Create the image view to hold the background rounded rect which we just drew
        sampleSizeOverlay = UIImageView(image: img_ui)
        sampleSizeOverlay.frame = CGRectMake(190, 124, 110, 234)
        
        // Create the text view which shows the size of our oscilloscope window as we pinch/zoom
        sampleSizeText = UILabel(frame: CGRectMake(-62, 0, 234, 234))
        sampleSizeText.textAlignment = NSTextAlignment.Center
        sampleSizeText.textColor = UIColor.whiteColor()
        sampleSizeText.text = "0000 ms"
        sampleSizeText.font = UIFont.boldSystemFontOfSize(36.0)
        // Rotate the text view since we want the text to draw top to bottom (when the device is oriented vertically)
        sampleSizeText.transform = CGAffineTransformMakeRotation(M_PI_2.g)
        sampleSizeText.backgroundColor = UIColor.clearColor()
        
        // Add the text view as a subview of the overlay BG
        sampleSizeOverlay.addSubview(sampleSizeText)
        // Text view was retained by the above line, so we can release it now
        
        // We don't add sampleSizeOverlay to our main view yet. We just hang on to it for now, and add it when we
        // need to display it, i.e. when a user starts a pinch/zoom.
        
        // Set up the view to refresh at 20 hz
        self.setAnimationInterval(1.0/20.0)
        self.startAnimation()
        
    }
    
    override func layoutSubviews() {
        EAGLContext.setCurrentContext(context)
        self.destroyFramebuffer()
        self.createFramebuffer()
        self.drawView()
    }
    
    private func createFramebuffer() -> Bool {
        glGenFramebuffersOES(1, &viewFramebuffer)
        glGenRenderbuffersOES(1, &viewRenderbuffer)
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES.ui, viewFramebuffer)
        glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, viewRenderbuffer)
        context.renderbufferStorage(GL_RENDERBUFFER_OES.l, fromDrawable: self.layer as! EAGLDrawable)
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES.ui, GL_COLOR_ATTACHMENT0_OES.ui, GL_RENDERBUFFER_OES.ui, viewRenderbuffer)
        
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES.ui, GL_RENDERBUFFER_WIDTH_OES.ui, &backingWidth)
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES.ui, GL_RENDERBUFFER_HEIGHT_OES.ui, &backingHeight)
        
        if USE_DEPTH_BUFFER {
            glGenRenderbuffersOES(1, &depthRenderbuffer)
            glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, depthRenderbuffer)
            glRenderbufferStorageOES(GL_RENDERBUFFER_OES.ui, GL_DEPTH_COMPONENT16_OES.ui, backingWidth, backingHeight)
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES.ui, GL_DEPTH_ATTACHMENT_OES.ui, GL_RENDERBUFFER_OES.ui, depthRenderbuffer)
        }
        
        if glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES.ui) != GL_FRAMEBUFFER_COMPLETE_OES.ui {
            NSLog("failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES.ui))
            return false
        }
        
        return true
    }
    
    
    private func destroyFramebuffer() {
        glDeleteFramebuffersOES(1, &viewFramebuffer)
        viewFramebuffer = 0
        glDeleteRenderbuffersOES(1, &viewRenderbuffer)
        viewRenderbuffer = 0
        
        if depthRenderbuffer != 0 {
            glDeleteRenderbuffersOES(1, &depthRenderbuffer)
            depthRenderbuffer = 0
        }
    }
    
    
    func startAnimation() {
        animationTimer = NSTimer.scheduledTimerWithTimeInterval(animationInterval, target: self, selector: "drawView", userInfo: nil, repeats: true)
        animationStarted = NSDate.timeIntervalSinceReferenceDate()
        audioController.startIOUnit()
    }
    
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        audioController.stopIOUnit()
    }
    
    
    private func setAnimationInterval(interval: NSTimeInterval) {
        animationInterval = interval
        
        if animationTimer != nil {
            self.stopAnimation()
            self.startAnimation()
        }
    }
    
    
    private func setupView() {
        // Sets up matrices and transforms for OpenGL ES
        glViewport(0, 0, backingWidth, backingHeight)
        glMatrixMode(GL_PROJECTION.ui)
        glLoadIdentity()
        glOrthof(0, GLfloat(backingWidth), 0, GLfloat(backingHeight), -1.0, 1.0)
        glMatrixMode(GL_MODELVIEW.ui)
        
        // Clears the view with black
        glClearColor(0.0, 0.0, 0.0, 1.0)
        
        glEnableClientState(GL_VERTEX_ARRAY.ui)
    }
    
    
    // Updates the OpenGL view when the timer fires
    func drawView() {
        // the NSTimer seems to fire one final time even though it's been invalidated
        // so just make sure and not draw if we're resigning active
        if self.applicationResignedActive { return }
        
        // Make sure that you are drawing to the current context
        EAGLContext.setCurrentContext(context)
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES.ui, viewFramebuffer)
        self.drawView(self, forTime: NSDate.timeIntervalSinceReferenceDate() - animationStarted)
        
        glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, viewRenderbuffer)
        context.presentRenderbuffer(GL_RENDERBUFFER_OES.l)
    }
    
    
    private func setupViewForOscilloscope() {
        var img: CGImage
        
        // Load our GL textures
        
        img = UIImage(named: "oscilloscope.png")!.CGImage!
        
        self.createGLTexture(&bgTexture, fromCGImage: img)
        
        img = UIImage(named: "fft_off.png")!.CGImage!
        self.createGLTexture(&fftOffTexture, fromCGImage: img)
        
        img = UIImage(named: "fft_on.png")!.CGImage!
        self.createGLTexture(&fftOnTexture, fromCGImage: img)
        
        img = UIImage(named: "mute_off.png")!.CGImage!
        self.createGLTexture(&muteOffTexture, fromCGImage: img)
        
        img = UIImage(named: "mute_on.png")!.CGImage!
        self.createGLTexture(&muteOnTexture, fromCGImage: img)
        
        img = UIImage(named: "sonogram.png")!.CGImage!
        self.createGLTexture(&sonoTexture, fromCGImage: img)
        
        initted_oscilloscope = true
    }
    
    
    private func clearTextures() {
        bzero(texBitBuffer, size_t(sizeof(UInt32) * 512))
        
        for var curTex = firstTex; curTex != nil; curTex = curTex.memory.nextTex {
            glBindTexture(GL_TEXTURE_2D.ui, curTex.memory.texName)
            glTexImage2D(GL_TEXTURE_2D.ui, 0, GL_RGBA, 1, 512, 0, GL_RGBA.ui, GL_UNSIGNED_BYTE.ui, texBitBuffer)
        }
    }
    
    private func setupViewForSpectrum() {
        glClearColor(0.0, 0.0, 0.0, 0.0)
        
        spectrumRect = CGRectMake(10.0, 10.0, 460.0, 300.0)
        
        // The bit buffer for the texture needs to be 512 pixels, because OpenGL textures are powers of
        // two in either dimensions. Our texture is drawing a strip of 300 vertical pixels on the screen,
        // so we need to step up to 512 (the nearest power of 2 greater than 300).
        texBitBuffer = UnsafeMutablePointer.alloc(512)
        
        // Clears the view with black
        glClearColor(0.0, 0.0, 0.0, 1.0)
        
        glEnableClientState(GL_VERTEX_ARRAY.ui)
        glEnableClientState(GL_TEXTURE_COORD_ARRAY.ui)
        
        let texCount = Int(ceil(CGRectGetWidth(spectrumRect) / CGFloat(SPECTRUM_BAR_WIDTH)))
        var texNames: UnsafeMutablePointer<GLuint>
        
        texNames = UnsafeMutablePointer.alloc(texCount)
        glGenTextures(GLsizei(texCount), texNames)
        
        var curTex: UnsafeMutablePointer<SpectrumLinkedTexture> = nil
        firstTex = UnsafeMutablePointer.alloc(1)
        firstTex.memory.texName = texNames[0]
        firstTex.memory.nextTex = nil
        curTex = firstTex
        
        bzero(texBitBuffer, size_t(sizeof(UInt32) * 512))
        
        glBindTexture(GL_TEXTURE_2D.ui, curTex.memory.texName)
        glTexParameteri(GL_TEXTURE_2D.ui, GL_TEXTURE_MIN_FILTER.ui, GL_NEAREST)
        
        for i in 1..<texCount {
            curTex.memory.nextTex = UnsafeMutablePointer.alloc(1)
            curTex = curTex.memory.nextTex
            curTex.memory.texName = texNames[i]
            curTex.memory.nextTex = nil
            
            glBindTexture(GL_TEXTURE_2D.ui, curTex.memory.texName)
            glTexParameteri(GL_TEXTURE_2D.ui, GL_TEXTURE_MIN_FILTER.ui, GL_NEAREST)
        }
        
        // Enable use of the texture
        glEnable(GL_TEXTURE_2D.ui)
        // Set a blending function to use
        glBlendFunc(GL_ONE.ui, GL_ONE_MINUS_SRC_ALPHA.ui)
        // Enable blending
        glEnable(GL_BLEND.ui)
        
        initted_spectrum = true
        
        texNames.dealloc(texCount)
    }
    
    private func drawOscilloscope() {
        // Clear the view
        glClear(GL_COLOR_BUFFER_BIT.ui)
        
        glBlendFunc(GL_SRC_ALPHA.ui, GL_ONE.ui)
        
        glColor4f(1.0, 1.0, 1.0, 1.0)
        
        glPushMatrix()
        
        // xy coord. offset for various devices
        let offsetY = GLfloat((self.bounds.size.height - 480) / 2)
        let offsetX = GLfloat((self.bounds.size.width - 320) / 2)
        
        glTranslatef(offsetX, 480 + offsetY, 0.0)
        glRotatef(-90.0, 0.0, 0.0, 1.0)
        
        glEnable(GL_TEXTURE_2D.ui)
        glEnableClientState(GL_VERTEX_ARRAY.ui)
        glEnableClientState(GL_TEXTURE_COORD_ARRAY.ui)
        
        // Draw our background oscilloscope screen
        let vertices1: [GLfloat] = [
            0.0, 0.0,
            512.0, 0.0,
            0.0, 512.0,
            512.0, 512.0,
        ]
        let texCoords1: [GLshort] = [
            0, 0,
            1, 0,
            0, 1,
            1, 1,
        ]
        
        
        glBindTexture(GL_TEXTURE_2D.ui, bgTexture)
        
        glVertexPointer(2, GL_FLOAT.ui, 0, vertices1)
        glTexCoordPointer(2, GL_SHORT.ui, 0, texCoords1)
        
        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        
        // Draw our buttons
        let vertices2: [GLfloat] = [
            0.0, 0.0,
            112.0, 0.0,
            0.0, 64.0,
            112.0, 64.0,
        ]
        let texCoords2: [GLshort] = [
            0, 0,
            1, 0,
            0, 1,
            1, 1,
        ]
        
        glPushMatrix()
        
        glVertexPointer(2, GL_FLOAT.ui, 0, vertices2)
        glTexCoordPointer(2, GL_SHORT.ui, 0, texCoords2)
        
        // button coords
        glTranslatef(15 + offsetX, 0, 0)
        glBindTexture(GL_TEXTURE_2D.ui, sonoTexture)
        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        glTranslatef(90 + offsetX, 0, 0)
        glBindTexture(GL_TEXTURE_2D.ui, audioController.muteAudio ? muteOnTexture : muteOffTexture)
        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        glTranslatef(105 + offsetX, 0, 0)
        glBindTexture(GL_TEXTURE_2D.ui, (displayMode == .OscilloscopeFFT) ? fftOnTexture : fftOffTexture)
        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        glPopMatrix()
        
        let bufferManager = audioController.bufferManagerInstance
        let drawBuffers = bufferManager.drawBuffers
        if displayMode == .OscilloscopeFFT {
            if bufferManager.hasNewFFTData {
                bufferManager.GetFFTOutput(l_fftData)
                
                let maxY = bufferManager.currentDrawBufferLength
                let fftLength = bufferManager.FFTOutputBufferLength
                for y in 0..<maxY {
                    let yFract = CGFloat(y) / CGFloat(maxY - 1)
                    let fftIdx = yFract * (CGFloat(fftLength) - 1)
                    
                    var fftIdx_i: Double = 0.0
                    let fftIdx_f = modf(Double(fftIdx), &fftIdx_i)
                    
                    let lowerIndex = Int(fftIdx_i)
                    var upperIndex = lowerIndex + 1
                    upperIndex = (upperIndex == fftLength) ? fftLength - 1 : upperIndex
                    
                    let fft_l_fl = CGFloat(l_fftData[lowerIndex] + 80) / 64.0
                    let fft_r_fl = CGFloat(l_fftData[upperIndex] + 80) / 64.0
                    let interpVal = fft_l_fl * (1.0 - CGFloat(fftIdx_f)) + fft_r_fl * CGFloat(fftIdx_f)
                    
                    drawBuffers[0][y] = Float32(CLAMP(0.0, interpVal, 1.0))
                }
                self.cycleOscilloscopeLines()
            }
        }
        
        var oscilLine_ptr: UnsafeMutablePointer<GLfloat>
        let max = GLfloat(kDefaultDrawSamples)
        var drawBuffer_ptr: UnsafeMutablePointer<Float32>
        
        glPushMatrix()
        
        // Translate to the left side and vertical center of the screen, and scale so that the screen coordinates
        // go from 0 to 1 along the X, and -1 to 1 along the Y
        glTranslatef(17.0, 182.0, 0.0)
        glScalef(448.0, 116.0, 1.0)
        
        // Set up some GL state for our oscilloscope lines
        glDisable(GL_TEXTURE_2D.ui)
        glDisableClientState(GL_TEXTURE_COORD_ARRAY.ui)
        glDisableClientState(GL_COLOR_ARRAY.ui)
        glDisable(GL_LINE_SMOOTH.ui)
        glLineWidth(2.0)
        
        // Draw a line for each stored line in our buffer (the lines are stored and fade over time)
        for drawBuffer_i in 0..<kNumDrawBuffers {
            if drawBuffers[drawBuffer_i] == nil { continue }
            
            oscilLine_ptr = oscilLine
            drawBuffer_ptr = drawBuffers[drawBuffer_i]
            
            // Fill our vertex array with points
            for var i: GLfloat = 0.0; i < max; ++i {
                (oscilLine_ptr++).memory = i / max
                (oscilLine_ptr++).memory = Float32((drawBuffer_ptr++).memory)
            }
            
            // If we're drawing the newest line, draw it in solid green. Otherwise, draw it in a faded green.
            if drawBuffer_i == 0 {
                glColor4f(0.0, 1.0, 0.0, 1.0)
            } else {
                glColor4f(0.0, 1.0, 0.0, (0.24 * (1.0 - (GLfloat(drawBuffer_i) / GLfloat(kNumDrawBuffers)))))
            }
            
            // Set up vertex pointer,
            glVertexPointer(2, GL_FLOAT.ui, 0, oscilLine)
            
            // and draw the line.
            glDrawArrays(GL_LINE_STRIP.ui, 0, Int32(bufferManager.currentDrawBufferLength))
        }
        glPopMatrix()
        glPopMatrix()
    }
    
    private func cycleSpectrum() {
        var newFirst: UnsafeMutablePointer<SpectrumLinkedTexture>
        newFirst = UnsafeMutablePointer.alloc(1)
        newFirst.memory.nextTex = firstTex
        firstTex = newFirst
        
        var thisTex = firstTex
        repeat {
            if thisTex.memory.nextTex.memory.nextTex == nil {
                firstTex.memory.texName = thisTex.memory.nextTex.memory.texName
                thisTex.memory.nextTex.dealloc(1)
                thisTex.memory.nextTex = nil
            }
            thisTex = thisTex.memory.nextTex
        } while thisTex != nil
    }
    
    private func linearInterp<T: FloatArithmeticType>(valA: T, _ valB: T, _ fract: T) -> T {
        return valA + ((valB - valA) * fract)
    }
    private func linearInterpUInt8(valA: GLfloat, _ valB: GLfloat, _ fract: GLfloat) -> UInt8 {
        return UInt8(255.0 * linearInterp(valA, valB, fract))
    }
    
    private func renderFFTToTex() {
        self.cycleSpectrum()
        
        var texBitBuffer_ptr = texBitBuffer
        
        let numLevels = colorLevels.count
        
        let maxY = Int(CGRectGetHeight(spectrumRect))
        let bufferManager = audioController.bufferManagerInstance
        let fftLength = bufferManager.FFTOutputBufferLength
        for y in 0..<maxY {
            let yFract = CGFloat(y) / CGFloat(maxY - 1)
            let fftIdx = yFract * (CGFloat(fftLength) - 1)
            
            var fftIdx_i: Double = 0
            let fftIdx_f = modf(Double(fftIdx), &fftIdx_i)
            
            let lowerIndex = Int(fftIdx_i)
            var upperIndex = lowerIndex + 1
            upperIndex = (upperIndex == fftLength) ? fftLength - 1 : upperIndex
            
            let fft_l_fl = CGFloat(l_fftData[lowerIndex] + 80) / 64.0
            let fft_r_fl = CGFloat(l_fftData[upperIndex] + 80) / 64.0
            var interpVal = GLfloat(fft_l_fl * (1.0 - CGFloat(fftIdx_f)) + fft_r_fl * CGFloat(fftIdx_f))
            
            interpVal = sqrt(CLAMP(0.0, interpVal, 1.0))
            
            var newPx: UInt32 = 0xFF000000
            
            for level_i in 0 ..< numLevels-1  {
                let thisLevel = colorLevels[level_i]
                let nextLevel = colorLevels[level_i + 1]
                if thisLevel.interpVal <= GLfloat(interpVal) && nextLevel.interpVal >= GLfloat(interpVal) {
                    let fract = (interpVal - thisLevel.interpVal) / (nextLevel.interpVal - thisLevel.interpVal)
                    newPx =
                        UInt32(linearInterpUInt8(thisLevel.a, nextLevel.a, fract)) << 24
                        |
                        UInt32(linearInterpUInt8(thisLevel.r, nextLevel.r, fract)) << 16
                        |
                        UInt32(linearInterpUInt8(thisLevel.g, nextLevel.g, fract)) << 8
                        |
                        UInt32(linearInterpUInt8(thisLevel.b, nextLevel.b, fract))
                }
                
            }
            
            (texBitBuffer_ptr++).memory = newPx
        }
        
        glBindTexture(GL_TEXTURE_2D.ui, firstTex.memory.texName)
        glTexImage2D(GL_TEXTURE_2D.ui, 0, GL_RGBA, 1, 512, 0, GL_RGBA.ui, GL_UNSIGNED_BYTE.ui, texBitBuffer)
    }
    
    private func drawSpectrum() {
        // Clear the view
        glClear(GL_COLOR_BUFFER_BIT.ui)
        
        let bufferManager = audioController.bufferManagerInstance
        if bufferManager.hasNewFFTData {
            bufferManager.GetFFTOutput(l_fftData)
            self.renderFFTToTex()
        }
        
        glClear(GL_COLOR_BUFFER_BIT.ui)
        
        glEnable(GL_TEXTURE.ui)
        glEnable(GL_TEXTURE_2D.ui)
        
        glPushMatrix()
        glTranslatef(0.0, 480.0, 0.0)
        glRotatef(-90.0, 0.0, 0.0, 1.0)
        glTranslatef(spectrumRect.origin.x.f + spectrumRect.size.width.f, spectrumRect.origin.y.f, 0.0)
        
        let quadCoords: [GLfloat] = [
            0.0, 0.0,
            SPECTRUM_BAR_WIDTH.f, 0.0,
            0.0, 512.0,
            SPECTRUM_BAR_WIDTH.f, 512.0,
        ]
        
        let texCoords: [GLshort] = [
            0, 0,
            1, 0,
            0, 1,
            1, 1,
        ]
        
        glVertexPointer(2, GL_FLOAT.ui, 0, quadCoords)
        glEnableClientState(GL_VERTEX_ARRAY.ui)
        glTexCoordPointer(2, GL_SHORT.ui, 0, texCoords)
        glEnableClientState(GL_TEXTURE_COORD_ARRAY.ui)
        
        glColor4f(1.0, 1.0, 1.0, 1.0)
        
        glPushMatrix()
        for var thisTex = firstTex; thisTex != nil; thisTex = thisTex.memory.nextTex {
            glTranslatef(-(SPECTRUM_BAR_WIDTH).f, 0.0, 0.0)
            glBindTexture(GL_TEXTURE_2D.ui, thisTex.memory.texName)
            glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        }
        glPopMatrix()
        glPopMatrix()
        
        glFlush()
        
    }
    
    
    private func drawView(sender: AnyObject, forTime time: NSTimeInterval) {
        if !audioController.audioChainIsBeingReconstructed {  //hold off on drawing until the audio chain has been reconstructed
            if displayMode == .OscilloscopeWaveform || displayMode == .OscilloscopeFFT {
                if !initted_oscilloscope { self.setupViewForOscilloscope() }
                self.drawOscilloscope()
            } else if displayMode == .Spectrum {
                if !initted_spectrum { self.setupViewForSpectrum() }
                self.drawSpectrum()
            }
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        // If we're if waveform mode and not currently in a pinch event, and we've got two touches, start a pinch event
        if let eventTouches = event!.allTouches()
            where pinchEvent == nil && eventTouches.count == 2 && displayMode == .OscilloscopeWaveform {
            pinchEvent = event
            let t = Array(eventTouches)
            lastPinchDist = fabs(t[0].locationInView(self).x - t[1].locationInView(self).x)
            
            let hwSampleRate = audioController.sessionSampleRate
            let bufferManager = audioController.bufferManagerInstance
            sampleSizeText.text = String(format: "%td ms", bufferManager.currentDrawBufferLength / Int(hwSampleRate / 1000.0))
            self.addSubview(sampleSizeOverlay)
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        // If we are in a pinch event...
        if let eventTouches = event!.allTouches()
            where event == pinchEvent && eventTouches.count == 2 {
            var thisPinchDist: CGFloat
            var pinchDiff: CGFloat
            let t = Array(eventTouches)
            thisPinchDist = fabs(t[0].locationInView(self).x - t[1].locationInView(self).x)
            
            // Find out how far we traveled since the last event
            pinchDiff = thisPinchDist - lastPinchDist
            // Adjust our draw buffer length accordingly,
            let bufferManager = audioController.bufferManagerInstance
            var drawBufferLen = bufferManager.currentDrawBufferLength
            drawBufferLen -= 12 * Int(pinchDiff)
            drawBufferLen = CLAMP(kMinDrawSamples, drawBufferLen, kMaxDrawSamples)
            bufferManager.currentDrawBufferLength = drawBufferLen
            
            // and display the size of our oscilloscope window in our overlay view
            let hwSampleRate = audioController.sessionSampleRate
            sampleSizeText.text = String(format: "%td ms", drawBufferLen / Int(hwSampleRate / 1000.0))
            
            lastPinchDist = thisPinchDist
        }
    }
    
    
    private class func createRoundedRectPath(RECT: CGRect, var _ cornerRadius: CGFloat) -> CGPath {
        let path = CGPathCreateMutable()
        
        let maxRad = max(CGRectGetHeight(RECT) / 2.0, CGRectGetWidth(RECT) / 2.0)
        
        if cornerRadius > maxRad {cornerRadius = maxRad}
        
        let bl = RECT.origin
        var br = RECT.origin
        var tl = RECT.origin
        var tr = RECT.origin
        
        tl.y += RECT.size.height
        tr.y += RECT.size.height
        tr.x += RECT.size.width
        br.x += RECT.size.width
        
        CGPathMoveToPoint(path, nil, bl.x + cornerRadius, bl.y)
        CGPathAddArcToPoint(path, nil, bl.x, bl.y, bl.x, bl.y + cornerRadius, cornerRadius)
        CGPathAddLineToPoint(path, nil, tl.x, tl.y - cornerRadius)
        CGPathAddArcToPoint(path, nil, tl.x, tl.y, tl.x + cornerRadius, tl.y, cornerRadius)
        CGPathAddLineToPoint(path, nil, tr.x - cornerRadius, tr.y)
        CGPathAddArcToPoint(path, nil, tr.x, tr.y, tr.x, tr.y - cornerRadius, cornerRadius)
        CGPathAddLineToPoint(path, nil, br.x, br.y + cornerRadius)
        CGPathAddArcToPoint(path, nil, br.x, br.y, br.x - cornerRadius, br.y, cornerRadius)
        
        CGPathCloseSubpath(path)
        
        let ret = CGPathCreateCopy(path)
        return ret!
    }
    
    
    private func cycleOscilloscopeLines() {
        let bufferManager = audioController.bufferManagerInstance
        
        // Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
        let drawBuffers = bufferManager.drawBuffers
        for var drawBuffer_i = kNumDrawBuffers - 2; drawBuffer_i >= 0; drawBuffer_i-- {
            memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], size_t(bufferManager.currentDrawBufferLength))
        }
    }
    
    
    private func createGLTexture(inout texName: GLuint, fromCGImage img: CGImage) {
        var texW: size_t, texH: size_t
        
        let imgW = CGImageGetWidth(img)
        let imgH = CGImageGetHeight(img)
        
        // Find smallest possible powers of 2 for our texture dimensions
        for texW = 1; texW < imgW; texW *= 2 {}
        for texH = 1; texH < imgH; texH *= 2 {}
        
        // Allocated memory needed for the bitmap context
        let spriteData: UnsafeMutablePointer<GLubyte> = UnsafeMutablePointer.alloc(Int(texH * texW * 4))
        bzero(spriteData, texH * texW * 4)
        // Uses the bitmatp creation function provided by the Core Graphics framework.
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        let spriteContext = CGBitmapContextCreate(spriteData, texW, texH, 8, texW * 4, CGImageGetColorSpace(img), bitmapInfo.rawValue)
        
        // Translate and scale the context to draw the image upside-down (conflict in flipped-ness between GL textures and CG contexts)
        CGContextTranslateCTM(spriteContext, 0.0, texH.g)
        CGContextScaleCTM(spriteContext, 1.0, -1.0)
        
        // After you create the context, you can draw the sprite image to the context.
        CGContextDrawImage(spriteContext, CGRectMake(0.0, 0.0, imgW.g, imgH.g), img)
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &texName)
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D.ui, texName)
        // Speidfy a 2D texture image, provideing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D.ui, 0, GL_RGBA, GLsizei(texW), GLsizei(texH), 0, GL_RGBA.ui, GL_UNSIGNED_BYTE.ui, spriteData)
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D.ui, GL_TEXTURE_MIN_FILTER.ui, GL_LINEAR)
        
        // Enable use of the texture
        glEnable(GL_TEXTURE_2D.ui)
        // Set a blending function to use
        glBlendFunc(GL_SRC_ALPHA.ui, GL_ONE.ui)
        //glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        // Enable blending
        glEnable(GL_BLEND.ui)
        
        spriteData.dealloc(Int(texH * texW * 4))
    }
    
    override func touchesEnded(touches:Set<UITouch>, withEvent event: UIEvent?) {
        let bufferManager = audioController.bufferManagerInstance
        if event == pinchEvent {
            // If our pinch/zoom has ended, nil out the pinchEvent and remove the overlay view
            sampleSizeOverlay.removeFromSuperview()
            pinchEvent = nil
            return
        }
        
        // any tap in sonogram view will exit back to the waveform
        if displayMode == .Spectrum {
            audioController.playButtonPressedSound()
            displayMode = .OscilloscopeWaveform
            bufferManager.displayMode = displayMode
            return
        }
        
        // xy coord. offset for various devices
        let offsetY = (self.bounds.size.height - 480) / 2
        let offsetX = (self.bounds.size.width - 320) / 2
        
        let touch = touches.first!
        if CGRectContainsPoint(CGRectMake(offsetX, 15.0, 52.0, 99.0), touch.locationInView(self)) { // The Sonogram button was touched
            audioController.playButtonPressedSound()
            if displayMode == .OscilloscopeWaveform || displayMode == .OscilloscopeFFT {
                if !initted_spectrum { self.setupViewForSpectrum() }
                self.clearTextures()
                displayMode = .Spectrum
                bufferManager.displayMode = displayMode
            }
        } else if CGRectContainsPoint(CGRectMake(offsetX, offsetY + 105.0, 52.0, 99.0), touch.locationInView(self)) { // The Mute button was touched
            audioController.playButtonPressedSound()
            audioController.muteAudio = !audioController.muteAudio
            return
        } else if CGRectContainsPoint(CGRectMake(offsetX, offsetY + 210, 52.0, 99.0), touch.locationInView(self)) { // The FFT button was touched
            audioController.playButtonPressedSound()
            displayMode = (displayMode == .OscilloscopeWaveform) ? .OscilloscopeFFT :
                .OscilloscopeWaveform
            bufferManager.displayMode = displayMode
            return
        }
    }
    
    // Stop animating and release resources when they are no longer needed.
    deinit {
        self.stopAnimation()
        
        if EAGLContext.currentContext() === context {
            EAGLContext.setCurrentContext(nil)
        }
        
        oscilLine.dealloc(kDefaultDrawSamples * 2)
        //###
        l_fftData.dealloc(audioController.bufferManagerInstance.FFTOutputBufferLength)
        texBitBuffer.dealloc(512)
        var texPtr = firstTex
        while texPtr != nil {
            let nextPtr = texPtr.memory.nextTex
            texPtr.dealloc(1)
            texPtr = nextPtr
        }
        
    }
    
    
}