//
//  MIKAppDelegate.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKAppDelegate.h"
#import "MIKMIDISequence.h"
#import "MIKMIDINoteOnCommand.h"

@implementation MIKAppDelegate

- (IBAction)loadFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowedFileTypes:@[@"mid", @"midi"]];
	[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) return;
		[self loadMIDIFile:[[openPanel URL] path]];
	}];
}

#pragma mark - MIKMIDISequenceViewDelegate

- (void)midiSequenceView:(MIKMIDISequenceView *)sequenceView receivedDroppedMIDIFiles:(NSArray *)midiFiles
{
	[self loadMIDIFile:[midiFiles firstObject]];
}

#pragma mark - Private

- (void)loadMIDIFile:(NSString *)path
{
	NSError *error = nil;
	MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:[NSURL fileURLWithPath:path] error:&error];
	for (MIKMIDITrack *track in sequence.tracks) {
		NSLog(@"track %p", track);
	}
	if (!sequence) {
		NSLog(@"Error loading MIDI file: %@", error);
	} else {
		NSLog(@"Loaded MIDI file: %@", sequence);
		self.trackView.sequence = sequence;
	}
}

@end
