//
//  EAGLView.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/1.
//
//
/*

 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass

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
    
    
    func CLAMP<T: Comparable>(_ min: T, _ x: T, _ max: T) -> T {return x < min ? min : (x > max ? max : x)}
    
    
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
        var nextTex: UnsafeMutablePointer<SpectrumLinkedTexture>?
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
    
    private var animationTimer: Timer?
    private var animationInterval: TimeInterval = 0
    private var animationStarted: TimeInterval = 0
    
    private var sampleSizeOverlay: UIImageView!
    private var sampleSizeText: UILabel!
    
    private var initted_oscilloscope: Bool = false
    private var initted_spectrum: Bool = false
    private var texBitBuffer: UnsafeMutablePointer<UInt32> =  UnsafeMutablePointer.allocate(capacity: 512)
    private var spectrumRect: CGRect = CGRect()
    
    private var bgTexture: GLuint = 0
    private var muteOffTexture: GLuint = 0
    private var muteOnTexture: GLuint = 0
    private var fftOffTexture: GLuint = 0
    private var fftOnTexture: GLuint = 0
    private var sonoTexture: GLuint = 0
    
    private var displayMode: AudioController.aurioTouchDisplayMode = .oscilloscopeFFT
    
    private var firstTex: UnsafeMutablePointer<SpectrumLinkedTexture>? = nil
    
    private var pinchEvent: UIEvent?
    private var lastPinchDist: CGFloat = 0.0
    private var l_fftData: UnsafeMutablePointer<Float32>!
    private var oscilLine: UnsafeMutablePointer<GLfloat>!
    
    private var audioController: AudioController = AudioController()
    
    
    // You must implement this
    override class var layerClass: AnyClass {
        return CAEAGLLayer.self
    }
    
    //The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
    required init?(coder: NSCoder) {
        // Set up our overlay view that pops up when we are pinching/zooming the oscilloscope
        super.init(coder: coder)
        
        self.frame = UIScreen.main.bounds
        
        // Get the layer
        let eaglLayer = self.layer as! CAEAGLLayer
        
        eaglLayer.isOpaque = true
        
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking : false,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
        ]
        
        context = EAGLContext(api: .openGLES1)
        
        if context == nil || !EAGLContext.setCurrent(context) || !self.createFramebuffer() {
            fatalError("cannot initialize EAGLView")
        }
        
        // Enable multi touch so we can handle pinch and zoom in the oscilloscope
        self.isMultipleTouchEnabled = true
        
        l_fftData = UnsafeMutablePointer.allocate(capacity: audioController.bufferManagerInstance.FFTOutputBufferLength)
        bzero(l_fftData, size_t(audioController.bufferManagerInstance.FFTOutputBufferLength * MemoryLayout<Float32>.size))
        
        oscilLine = UnsafeMutablePointer.allocate(capacity: kDefaultDrawSamples * 2)
        bzero(oscilLine, size_t(kDefaultDrawSamples * 2 * MemoryLayout<GLfloat>.size))
        
        animationInterval = 1.0 / 60.0
        
        self.setupView()
        self.drawView()
        
        displayMode = .oscilloscopeWaveform
        
        // Set up our overlay view that pops up when we are pinching/zooming the oscilloscope
        var img_ui: UIImage? = nil
        // Draw the rounded rect for the bg path using this convenience function
        let bgPath = EAGLView.createRoundedRectPath(CGRect(x: 0, y: 0, width: 110, height: 234), 15.0)
        
        let cs = CGColorSpaceCreateDeviceRGB()
        // Create the bitmap context into which we will draw
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        let cxt = CGContext(data: nil, width: 110, height: 234, bitsPerComponent: 8, bytesPerRow: 4*110, space: cs, bitmapInfo: bitmapInfo.rawValue)
        cxt?.setFillColorSpace(cs)
        let fillClr: [CGFloat] = [0.0, 0.0, 0.0, 0.7]
        cxt?.setFillColor(fillClr)
        // Add the rounded rect to the context...
        cxt?.addPath(bgPath)
        // ... and fill it.
        cxt?.fillPath()
        
        // Make a CGImage out of the context
        let img_cg = cxt?.makeImage()
        // Make a UIImage out of the CGImage
        img_ui = UIImage(cgImage: img_cg!)
        
        // Create the image view to hold the background rounded rect which we just drew
        sampleSizeOverlay = UIImageView(image: img_ui)
        sampleSizeOverlay.frame = CGRect(x: 190, y: 124, width: 110, height: 234)
        
        // Create the text view which shows the size of our oscilloscope window as we pinch/zoom
        sampleSizeText = UILabel(frame: CGRect(x: -62, y: 0, width: 234, height: 234))
        sampleSizeText.textAlignment = NSTextAlignment.center
        sampleSizeText.textColor = UIColor.white
        sampleSizeText.text = NSLocalizedString("0000 ms", comment: "")
        sampleSizeText.font = UIFont.boldSystemFont(ofSize: 36.0)
        // Rotate the text view since we want the text to draw top to bottom (when the device is oriented vertically)
        sampleSizeText.transform = CGAffineTransform(rotationAngle: .pi/2)
        sampleSizeText.backgroundColor = UIColor.clear
        
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
        EAGLContext.setCurrent(context)
        self.destroyFramebuffer()
        self.createFramebuffer()
        self.drawView()
    }
    
    @discardableResult
    private func createFramebuffer() -> Bool {
        glGenFramebuffersOES(1, &viewFramebuffer)
        glGenRenderbuffersOES(1, &viewRenderbuffer)
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES.ui, viewFramebuffer)
        glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, viewRenderbuffer)
        context.renderbufferStorage(GL_RENDERBUFFER_OES.l, from: (self.layer as! EAGLDrawable))
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
        animationTimer = Timer.scheduledTimer(timeInterval: animationInterval, target: self, selector: #selector(self.drawView as () -> ()), userInfo: nil, repeats: true)
        animationStarted = Date.timeIntervalSinceReferenceDate
        audioController.startIOUnit()
    }
    
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        audioController.stopIOUnit()
    }
    
    
    private func setAnimationInterval(_ interval: TimeInterval) {
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
    @objc func drawView() {
        // the NSTimer seems to fire one final time even though it's been invalidated
        // so just make sure and not draw if we're resigning active
        if self.applicationResignedActive { return }
        
        // Make sure that you are drawing to the current context
        EAGLContext.setCurrent(context)
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES.ui, viewFramebuffer)
        self.drawView(self, forTime: Date.timeIntervalSinceReferenceDate - animationStarted)
        
        glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, viewRenderbuffer)
        context.presentRenderbuffer(GL_RENDERBUFFER_OES.l)
    }
    
    
    private func setupViewForOscilloscope() {
        var img: CGImage
        
        // Load our GL textures
        
        img = UIImage(named: "oscilloscope.png")!.cgImage!
        
        self.createGLTexture(&bgTexture, fromCGImage: img)
        
        img = UIImage(named: "fft_off.png")!.cgImage!
        self.createGLTexture(&fftOffTexture, fromCGImage: img)
        
        img = UIImage(named: "fft_on.png")!.cgImage!
        self.createGLTexture(&fftOnTexture, fromCGImage: img)
        
        img = UIImage(named: "mute_off.png")!.cgImage!
        self.createGLTexture(&muteOffTexture, fromCGImage: img)
        
        img = UIImage(named: "mute_on.png")!.cgImage!
        self.createGLTexture(&muteOnTexture, fromCGImage: img)
        
        img = UIImage(named: "sonogram.png")!.cgImage!
        self.createGLTexture(&sonoTexture, fromCGImage: img)
        
        initted_oscilloscope = true
    }
    
    
    private func clearTextures() {
        bzero(texBitBuffer, size_t(MemoryLayout<UInt32>.size * 512))
        
        var curTex = firstTex
        while curTex != nil {
            glBindTexture(GL_TEXTURE_2D.ui, (curTex?.pointee.texName)!)
            glTexImage2D(GL_TEXTURE_2D.ui, 0, GL_RGBA, 1, 512, 0, GL_RGBA.ui, GL_UNSIGNED_BYTE.ui, texBitBuffer)
            curTex = curTex?.pointee.nextTex
        }
    }
    
    private func setupViewForSpectrum() {
        glClearColor(0.0, 0.0, 0.0, 0.0)
        
        spectrumRect = CGRect(x: 10.0, y: 10.0, width: 460.0, height: 300.0)
        
        // The bit buffer for the texture needs to be 512 pixels, because OpenGL textures are powers of
        // two in either dimensions. Our texture is drawing a strip of 300 vertical pixels on the screen,
        // so we need to step up to 512 (the nearest power of 2 greater than 300).
        texBitBuffer = UnsafeMutablePointer.allocate(capacity: 512)
        
        // Clears the view with black
        glClearColor(0.0, 0.0, 0.0, 1.0)
        
        glEnableClientState(GL_VERTEX_ARRAY.ui)
        glEnableClientState(GL_TEXTURE_COORD_ARRAY.ui)
        
        let texCount = Int(ceil(spectrumRect.width / CGFloat(SPECTRUM_BAR_WIDTH)))
        var texNames: UnsafeMutablePointer<GLuint>
        
        texNames = UnsafeMutablePointer.allocate(capacity: texCount)
        glGenTextures(GLsizei(texCount), texNames)
        
        var curTex: UnsafeMutablePointer<SpectrumLinkedTexture>? = nil
        firstTex = UnsafeMutablePointer.allocate(capacity: 1)
        firstTex?.pointee.texName = texNames[0]
        firstTex?.pointee.nextTex = nil
        curTex = firstTex
        
        bzero(texBitBuffer, size_t(MemoryLayout<UInt32>.size * 512))
        
        glBindTexture(GL_TEXTURE_2D.ui, (curTex?.pointee.texName)!)
        glTexParameteri(GL_TEXTURE_2D.ui, GL_TEXTURE_MIN_FILTER.ui, GL_NEAREST)
        
        for i in 1..<texCount {
            curTex?.pointee.nextTex = UnsafeMutablePointer.allocate(capacity: 1)
            curTex = curTex?.pointee.nextTex
            curTex?.pointee.texName = texNames[i]
            curTex?.pointee.nextTex = nil
            
            glBindTexture(GL_TEXTURE_2D.ui, (curTex?.pointee.texName)!)
            glTexParameteri(GL_TEXTURE_2D.ui, GL_TEXTURE_MIN_FILTER.ui, GL_NEAREST)
        }
        
        // Enable use of the texture
        glEnable(GL_TEXTURE_2D.ui)
        // Set a blending function to use
        glBlendFunc(GL_ONE.ui, GL_ONE_MINUS_SRC_ALPHA.ui)
        // Enable blending
        glEnable(GL_BLEND.ui)
        
        initted_spectrum = true
        
        texNames.deallocate()
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
        glBindTexture(GL_TEXTURE_2D.ui, (displayMode == .oscilloscopeFFT) ? fftOnTexture : fftOffTexture)
        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        glPopMatrix()
        
        let bufferManager = audioController.bufferManagerInstance
        let drawBuffers = bufferManager.drawBuffers
        if displayMode == .oscilloscopeFFT {
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
                    
                    drawBuffers[0]?[y] = Float32(CLAMP(0.0, interpVal, 1.0))
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
            drawBuffer_ptr = drawBuffers[drawBuffer_i]!
            
            // Fill our vertex array with points
            var i: GLfloat = 0.0
            while i < max {
                oscilLine_ptr.pointee = i / max
                oscilLine_ptr += 1
                oscilLine_ptr.pointee = Float32(drawBuffer_ptr.pointee)
                oscilLine_ptr += 1
                drawBuffer_ptr += 1
                i += 1.0
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
        newFirst = UnsafeMutablePointer.allocate(capacity: 1)
        newFirst.pointee.nextTex = firstTex
        firstTex = newFirst
        
        var thisTex = firstTex
        repeat {
            if thisTex?.pointee.nextTex?.pointee.nextTex == nil {
                firstTex?.pointee.texName = (thisTex?.pointee.nextTex?.pointee.texName)!
                thisTex?.pointee.nextTex?.deallocate()
                thisTex?.pointee.nextTex = nil
            }
            thisTex = thisTex?.pointee.nextTex
        } while thisTex != nil
    }
    
    private func linearInterp<T: FloatingPoint>(_ valA: T, _ valB: T, _ fract: T) -> T {
        return valA + ((valB - valA) * fract)
    }
    private func linearInterpUInt8(_ valA: GLfloat, _ valB: GLfloat, _ fract: GLfloat) -> UInt8 {
        return UInt8(255.0 * linearInterp(valA, valB, fract))
    }
    
    private func renderFFTToTex() {
        self.cycleSpectrum()
        
        var texBitBuffer_ptr = texBitBuffer
        
        let numLevels = colorLevels.count
        
        let maxY = Int(spectrumRect.height)
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
            
            texBitBuffer_ptr.pointee = newPx
            texBitBuffer_ptr += 1
        }
        
        glBindTexture(GL_TEXTURE_2D.ui, (firstTex?.pointee.texName)!)
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
        var thisTex = firstTex
        while thisTex != nil {
            glTranslatef(-(SPECTRUM_BAR_WIDTH).f, 0.0, 0.0)
            glBindTexture(GL_TEXTURE_2D.ui, (thisTex?.pointee.texName)!)
            glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
            thisTex = thisTex?.pointee.nextTex
        }
        glPopMatrix()
        glPopMatrix()
        
        glFlush()
        
    }
    
    
    private func drawView(_ sender: AnyObject, forTime time: TimeInterval) {
        if !audioController.audioChainIsBeingReconstructed {  //hold off on drawing until the audio chain has been reconstructed
            if displayMode == .oscilloscopeWaveform || displayMode == .oscilloscopeFFT {
                if !initted_oscilloscope { self.setupViewForOscilloscope() }
                self.drawOscilloscope()
            } else if displayMode == .spectrum {
                if !initted_spectrum { self.setupViewForSpectrum() }
                self.drawSpectrum()
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If we're if waveform mode and not currently in a pinch event, and we've got two touches, start a pinch event
        if
            let eventTouches = event!.allTouches,
            pinchEvent == nil && eventTouches.count == 2 && displayMode == .oscilloscopeWaveform
        {
            pinchEvent = event
            let t = Array(eventTouches)
            lastPinchDist = fabs(t[0].location(in: self).x - t[1].location(in: self).x)
            
            let hwSampleRate = audioController.sessionSampleRate
            let bufferManager = audioController.bufferManagerInstance
            sampleSizeText.text = String(format: "%td ms", bufferManager.currentDrawBufferLength / Int(hwSampleRate / 1000.0))
            self.addSubview(sampleSizeOverlay)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If we are in a pinch event...
        if
            let eventTouches = event!.allTouches,
            event == pinchEvent && eventTouches.count == 2
        {
            var thisPinchDist: CGFloat
            var pinchDiff: CGFloat
            let t = Array(eventTouches)
            thisPinchDist = fabs(t[0].location(in: self).x - t[1].location(in: self).x)
            
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
    
    
    private class func createRoundedRectPath(_ RECT: CGRect, _ _cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        let maxRad = max(RECT.height / 2.0, RECT.width / 2.0)
        
        var cornerRadius = _cornerRadius
        if cornerRadius > maxRad {cornerRadius = maxRad}
        
        let bl = RECT.origin
        var br = RECT.origin
        var tl = RECT.origin
        var tr = RECT.origin
        
        tl.y += RECT.size.height
        tr.y += RECT.size.height
        tr.x += RECT.size.width
        br.x += RECT.size.width
        
        path.move(to: CGPoint(x: bl.x + cornerRadius, y: bl.y))
        path.addArc(tangent1End: CGPoint(x: bl.x, y: bl.y), tangent2End: CGPoint(x: bl.x, y: bl.y + cornerRadius), radius: cornerRadius)
        path.addLine(to: CGPoint(x: tl.x, y: tl.y - cornerRadius))
        path.addArc(tangent1End: CGPoint(x: tl.x, y: tl.y), tangent2End: CGPoint(x: tl.x + cornerRadius, y: tl.y), radius: cornerRadius)
        path.addLine(to: CGPoint(x: tr.x - cornerRadius, y: tr.y))
        path.addArc(tangent1End: CGPoint(x: tr.x, y: tr.y), tangent2End: CGPoint(x: tr.x, y: tr.y - cornerRadius), radius: cornerRadius)
        path.addLine(to: CGPoint(x: br.x, y: br.y + cornerRadius))
        path.addArc(tangent1End: CGPoint(x: br.x, y: br.y), tangent2End: CGPoint(x: br.x - cornerRadius, y: br.y), radius: cornerRadius)
        
        path.closeSubpath()
        
        let ret = path.copy()
        return ret!
    }
    
    
    private func cycleOscilloscopeLines() {
        let bufferManager = audioController.bufferManagerInstance
        
        // Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
        let drawBuffers = bufferManager.drawBuffers
        for drawBuffer_i in stride(from: (kNumDrawBuffers - 2), through: 0, by: -1) {
//        for var drawBuffer_i = kNumDrawBuffers - 2; drawBuffer_i >= 0; drawBuffer_i -= 1 {
            memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], size_t(bufferManager.currentDrawBufferLength))
        }
    }
    
    
    private func createGLTexture(_ texName: inout GLuint, fromCGImage img: CGImage) {
        var texW: size_t, texH: size_t
        
        let imgW = img.width
        let imgH = img.height
        
        // Find smallest possible powers of 2 for our texture dimensions
        texW = 1; while texW < imgW {texW *= 2}
        texH = 1; while texH < imgH {texH *= 2}
        
        // Allocated memory needed for the bitmap context
        let spriteData: UnsafeMutablePointer<GLubyte> = UnsafeMutablePointer.allocate(capacity: Int(texH * texW * 4))
        bzero(spriteData, texH * texW * 4)
        // Uses the bitmatp creation function provided by the Core Graphics framework.
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let spriteContext = CGContext(data: spriteData, width: texW, height: texH, bitsPerComponent: 8, bytesPerRow: texW * 4, space: img.colorSpace!, bitmapInfo: bitmapInfo.rawValue)
        
        // Translate and scale the context to draw the image upside-down (conflict in flipped-ness between GL textures and CG contexts)
        spriteContext?.translateBy(x: 0.0, y: texH.g)
        spriteContext?.scaleBy(x: 1.0, y: -1.0)
        
        // After you create the context, you can draw the sprite image to the context.
        spriteContext?.draw(img, in: CGRect(x: 0.0, y: 0.0, width: imgW.g, height: imgH.g))
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
        
        spriteData.deallocate()
    }
    
    override func touchesEnded(_ touches:Set<UITouch>, with event: UIEvent?) {
        let bufferManager = audioController.bufferManagerInstance
        if event == pinchEvent {
            // If our pinch/zoom has ended, nil out the pinchEvent and remove the overlay view
            sampleSizeOverlay.removeFromSuperview()
            pinchEvent = nil
            return
        }
        
        // any tap in sonogram view will exit back to the waveform
        if displayMode == .spectrum {
            audioController.playButtonPressedSound()
            displayMode = .oscilloscopeWaveform
            bufferManager.displayMode = displayMode
            return
        }
        
        // xy coord. offset for various devices
        let offsetY = (self.bounds.size.height - 480) / 2
        let offsetX = (self.bounds.size.width - 320) / 2
        
        let touch = touches.first!
        if CGRect(x: offsetX, y: 15.0, width: 52.0, height: 99.0).contains(touch.location(in: self)) { // The Sonogram button was touched
            audioController.playButtonPressedSound()
            if displayMode == .oscilloscopeWaveform || displayMode == .oscilloscopeFFT {
                if !initted_spectrum { self.setupViewForSpectrum() }
                self.clearTextures()
                displayMode = .spectrum
                bufferManager.displayMode = displayMode
            }
        } else if CGRect(x: offsetX, y: offsetY + 105.0, width: 52.0, height: 99.0).contains(touch.location(in: self)) { // The Mute button was touched
            audioController.playButtonPressedSound()
            audioController.muteAudio = !audioController.muteAudio
            return
        } else if CGRect(x: offsetX, y: offsetY + 210, width: 52.0, height: 99.0).contains(touch.location(in: self)) { // The FFT button was touched
            audioController.playButtonPressedSound()
            displayMode = (displayMode == .oscilloscopeWaveform) ? .oscilloscopeFFT :
                .oscilloscopeWaveform
            bufferManager.displayMode = displayMode
            return
        }
    }
    
    // Stop animating and release resources when they are no longer needed.
    deinit {
        self.stopAnimation()
        
        if EAGLContext.current() === context {
            EAGLContext.setCurrent(nil)
        }
        
        oscilLine?.deallocate()
        //###
        l_fftData?.deallocate()
        texBitBuffer.deallocate()
        var texPtr = firstTex
        while texPtr != nil {
            let nextPtr = texPtr?.pointee.nextTex
            texPtr?.deallocate()
            texPtr = nextPtr
        }
        
    }
    
    
}
