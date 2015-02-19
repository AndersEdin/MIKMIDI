//
//  MIKMIDISynthesizer.m
//  
//
//  Created by Andrew Madsen on 2/19/15.
//
//

#import "MIKMIDISynthesizer.h"
#import "MIKMIDICommand.h"

@implementation MIKMIDISynthesizer

- (instancetype)init
{
	return [self initWithAudioUnitDescription:[[self class] appleSynthComponentDescription]];
}

- (instancetype)initWithAudioUnitDescription:(AudioComponentDescription)componentDescription
{
	self = [super init];
	if (self) {
		_componentDescription = componentDescription;
		if (![self setupAUGraph]) return nil;
	}
	return self;
}

- (void)dealloc
{
	self.graph = NULL;
}

#pragma mark - Public

- (BOOL)selectInstrument:(MIKMIDISynthesizerInstrument *)instrument;
{
	if (!instrument) return NO;
	if (!self.isUsingAppleSynth) return NO;
	
	MusicDeviceInstrumentID instrumentID = instrument.instrumentID;
	for (UInt8 channel = 0; channel < 16; channel++) {
		// http://lists.apple.com/archives/coreaudio-api/2002/Sep/msg00015.html
		UInt8 bankSelectMSB = (instrumentID >> 16) & 0x7F;
		UInt8 bankSelectLSB = (instrumentID >> 8) & 0x7F;
		UInt8 programChange = instrumentID & 0x7F;
		
		UInt32 bankSelectStatus = 0xB0 | channel;
		UInt32 programChangeStatus = 0xC0 | channel;
		
		AudioUnit instrumentUnit = self.instrument;
		OSStatus err = MusicDeviceMIDIEvent(instrumentUnit, bankSelectStatus, 0x00, bankSelectMSB, 0);
		if (err) {
			NSLog(@"MusicDeviceMIDIEvent() (MSB Bank Select) failed with error %d in %s.", err, __PRETTY_FUNCTION__);
			return NO;
		}
		
		err = MusicDeviceMIDIEvent(instrumentUnit, bankSelectStatus, 0x20, bankSelectLSB, 0);
		if (err) {
			NSLog(@"MusicDeviceMIDIEvent() (LSB Bank Select) failed with error %d in %s.", err, __PRETTY_FUNCTION__);
			return NO;
		}
		
		err = MusicDeviceMIDIEvent(instrumentUnit, programChangeStatus, programChange, 0, 0);
		if (err) {
			NSLog(@"MusicDeviceMIDIEvent() (Program Change) failed with error %d in %s.", err, __PRETTY_FUNCTION__);
			return NO;
		}
	}
	
	return YES;
}


#pragma mark - Private

#pragma mark Audio Graph

- (BOOL)setupAUGraph
{
	AUGraph graph;
	OSStatus err = 0;
	if ((err = NewAUGraph(&graph))) {
		NSLog(@"Unable to create AU graph: %i", err);
		return NO;
	}
	
	AudioComponentDescription outputcd = {0};
	outputcd.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
	outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
#else
	outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
	
	outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	AUNode outputNode;
	if ((err = AUGraphAddNode(graph, &outputcd, &outputNode))) {
		NSLog(@"Unable to add ouptput node to graph: %i", err);
		return NO;
	}
	
	AudioComponentDescription instrumentcd = self.componentDescription;
	
	AUNode instrumentNode;
	if ((err = AUGraphAddNode(graph, &instrumentcd, &instrumentNode))) {
		NSLog(@"Unable to add instrument node to AU graph: %i", err);
		return NO;
	}
	
	if ((err = AUGraphOpen(graph))) {
		NSLog(@"Unable to open AU graph: %i", err);
		return NO;
	}
	
	AudioUnit instrumentUnit;
	if ((err = AUGraphNodeInfo(graph, instrumentNode, NULL, &instrumentUnit))) {
		NSLog(@"Unable to get instrument AU unit: %i", err);
		return NO;
	}
	
	if ((err = AUGraphConnectNodeInput(graph, instrumentNode, 0, outputNode, 0))) {
		NSLog(@"Unable to connect instrument to output: %i", err);
		return NO;
	}
	
	if ((err = AUGraphInitialize(graph))) {
		NSLog(@"Unable to initialize AU graph: %i", err);
		return NO;
	}
	
#if !TARGET_OS_IPHONE
	// Turn down reverb which is way too high by default
	if (instrumentcd.componentSubType == kAudioUnitSubType_DLSSynth) {
		if ((err = AudioUnitSetParameter(instrumentUnit, kMusicDeviceParam_ReverbVolume, kAudioUnitScope_Global, 0, -120, 0))) {
			NSLog(@"Unable to set reverb level to -120: %i", err);
		}
	}
#endif
	
	if ((err = AUGraphStart(graph))) {
		NSLog(@"Unable to start AU graph: %i", err);
		return NO;
	}
	
	self.graph = graph;
	self.instrument = instrumentUnit;
	
	return YES;
}

#pragma mark - Instruments

- (BOOL)isUsingAppleSynth
{
	AudioComponentDescription description = self.componentDescription;
	AudioComponentDescription appleSynthDescription = [[self class] appleSynthComponentDescription];
	if (description.componentManufacturer != appleSynthDescription.componentManufacturer) return NO;
	if (description.componentType != appleSynthDescription.componentType) return NO;
	if (description.componentSubType != appleSynthDescription.componentSubType) return NO;
	if (description.componentFlags != appleSynthDescription.componentFlags) return NO;
	if (description.componentFlagsMask != appleSynthDescription.componentFlagsMask) return NO;
	return YES;
}

+ (AudioComponentDescription)appleSynthComponentDescription
{
	AudioComponentDescription instrumentcd = (AudioComponentDescription){0};
	instrumentcd.componentManufacturer = kAudioUnitManufacturer_Apple;
	instrumentcd.componentType = kAudioUnitType_MusicDevice;
#if TARGET_OS_IPHONE
	instrumentcd.componentSubType = kAudioUnitSubType_Sampler;
#else
	instrumentcd.componentSubType = kAudioUnitSubType_DLSSynth;
#endif
	return instrumentcd;
}

#pragma mark - Properties

- (void)setGraph:(AUGraph)graph
{
	if (graph != _graph) {
		if (_graph) DisposeAUGraph(_graph);
		_graph = graph;
	}
}

- (void)handleMIDIMessages:(NSArray *)commands
{
	for (MIKMIDICommand *command in commands) {
		OSStatus err = MusicDeviceMIDIEvent(self.instrument, command.commandType, command.dataByte1, command.dataByte2, 0);
		if (err) NSLog(@"Unable to send MIDI command to synthesizer %@: %i", command, err);
	}
}

@end