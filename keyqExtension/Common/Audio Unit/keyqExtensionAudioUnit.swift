//
//  keyqExtensionAudioUnit.swift
//  keyqExtension
//
//  Created by Dean Turpin on 12/01/2026.
//

import AVFoundation

public class keyqExtensionAudioUnit: AUAudioUnit, @unchecked Sendable
{
	// C++ Objects
	var kernel = keyqExtensionDSPKernel()
    var processHelper: AUProcessHelper?
    var inputBus = BufferedInputBus()

	private var outputBus: AUAudioUnitBus?
    private var _inputBusses: AUAudioUnitBusArray!
    private var _outputBusses: AUAudioUnitBusArray!

	@objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
		let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
		try super.init(componentDescription: componentDescription, options: options)
		outputBus = try AUAudioUnitBus(format: format)
        outputBus?.maximumChannelCount = 2
        
        // Create the input and output busses.
        inputBus.initialize(format, 8);

        // Create the input and output bus arrays.
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [inputBus.bus!])
        
        // Create the input and output bus arrays.
		_outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus!])
        
        processHelper = AUProcessHelper(&kernel, &inputBus)
	}

    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }
    
    public override var channelCapabilities: [NSNumber] {
        get {
            return [NSNumber(value: 2), NSNumber(value: 2)]
        }
    }

    public override var  maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernel.maximumFramesToRender()
        }

        set {
            kernel.setMaximumFramesToRender(newValue)
        }
    }

    public override var  shouldBypassEffect: Bool {
        get {
            return kernel.isBypassed()
        }

        set {
            kernel.setBypass(newValue)
        }
    }
	
    // MARK: - Rendering
    public override var internalRenderBlock: AUInternalRenderBlock {
        return processHelper!.internalRenderBlock()
    }

    // Allocate resources required to render.
    // Subclassers should call the superclass implementation.
    public override func allocateRenderResources() throws {
        let inputChannelCount = self.inputBusses[0].format.channelCount
        let outputChannelCount = self.outputBusses[0].format.channelCount
		
        if outputChannelCount != inputChannelCount {
            setRenderResourcesAllocated(false)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
        }

        inputBus.allocateRenderResources(self.maximumFramesToRender);

		kernel.setMusicalContextBlock(self.musicalContextBlock)
        kernel.initialize(Int32(inputChannelCount), Int32(outputChannelCount), outputBus!.format.sampleRate)

        processHelper?.setChannelCount(inputChannelCount, outputChannelCount)

		try super.allocateRenderResources()
	}

    // Deallocate resources allocated in allocateRenderResourcesAndReturnError:
    // Subclassers should call the superclass implementation.
    public override func deallocateRenderResources() {
        
        // Deallocate your resources.
        kernel.deInitialize()
        
        super.deallocateRenderResources()
    }

	public func setupParameterTree(_ parameterTree: AUParameterTree) {
		self.parameterTree = parameterTree

		// Set the Parameter default values before setting up the parameter callbacks
		for param in parameterTree.allParameters {
            kernel.setParameter(param.address, param.value)
		}

		setupParameterCallbacks()
	}

	private func setupParameterCallbacks() {
		// implementorValueObserver is called when a parameter changes value.
		parameterTree?.implementorValueObserver = { [weak self] param, value -> Void in
            self?.kernel.setParameter(param.address, value)
		}

		// implementorValueProvider is called when the value needs to be refreshed.
		parameterTree?.implementorValueProvider = { [weak self] param in
            return self!.kernel.getParameter(param.address)
		}

		// A function to provide string representations of parameter values.
		parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
			guard let value = valuePtr?.pointee else {
				return "-"
			}
			return NSString.localizedStringWithFormat("%.f", value) as String
		}
	}
	
	// MARK: - FFT Data Access
	public func getFFTMagnitudes() -> [Float] {
		var magnitudes = [Float]()
		let count = kernel.getFFTMagnitudesCount()
		magnitudes.reserveCapacity(Int(count))
		
		for i in 0..<count {
			magnitudes.append(kernel.getFFTMagnitude(i))
		}
		return magnitudes
	}
	
	public func getSampleRate() -> Float {
		return kernel.getSampleRate()
	}
	
	public func getFFTSize() -> UInt32 {
		return kernel.getFFTSize()
	}
	
	// MARK: - Peak Detection Access
	public struct DetectedPeak {
		public let frequency: Float
		public let magnitude: Float
		public let midiNote: Int
		public let noteIndex: Int
		public let octave: Int
		public let centsDeviation: Float
		
		public var noteName: String {
			let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
			return "\(names[noteIndex])\(octave)"
		}
	}
	
	public func getDetectedPeaks() -> [DetectedPeak] {
		var peaks = [DetectedPeak]()
		let count = kernel.getPeakCount()
		peaks.reserveCapacity(Int(count))
		
		for i in 0..<count {
			let peak = DetectedPeak(
				frequency: kernel.getPeakFrequency(i),
				magnitude: kernel.getPeakMagnitude(i),
				midiNote: Int(kernel.getPeakMidiNote(i)),
				noteIndex: Int(kernel.getPeakNoteIndex(i)),
				octave: Int(kernel.getPeakOctave(i)),
				centsDeviation: kernel.getPeakCents(i)
			)
			peaks.append(peak)
		}
		return peaks
	}
}
