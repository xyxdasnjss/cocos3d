/*
 * CC3CAFResource.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2010-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3CAFResource.h for full API documentation.
 */

#import "CC3CAFResource.h"
#import "CC3DataStreams.h"
#import "CC3NodeAnimation.h"


@implementation CC3CAFResource

@synthesize animationDuration=_animationDuration;


#pragma mark Allocation and initialization

-(id) init {
	if ( (self = [super init]) ) {
		_nodeCount = 0;
		_animationDuration = 0;
	}
	return self;
}

-(BOOL) processFile: (NSString*) anAbsoluteFilePath {
	
	// Load the contents of the file and create a reader to parse those contents.
	NSData* cafData = [NSData dataWithContentsOfFile: anAbsoluteFilePath];
	if (cafData) {
		CC3DataReader* reader = [CC3DataReader readerOnData: cafData];
		reader.isBigEndian = self.isBigEndian;
		return [self readFrom: reader];
	} else {
		LogError(@"Could not load %@", anAbsoluteFilePath.lastPathComponent);
		return NO;
	}
}


#pragma mark File reading

/** Populates this resource from the content of the specified reader. */
-(BOOL)	readFrom: (CC3DataReader*) reader {
	BOOL wasRead = YES;

	wasRead = wasRead && [self readHeaderFrom: reader];
	CC3Assert(wasRead, @"%@ file type or version is invalid", self);

	if (_animationDuration > 0.0f)
		for (NSInteger nIdx = 0; nIdx < _nodeCount; nIdx++)
			wasRead = wasRead && [self readNodeFrom: reader];
	
	return wasRead;
}

/** Reads and validates the content header. */
-(BOOL)	readHeaderFrom: (CC3DataReader*) reader {
	//	[header]
	//		magic token              4       const     "CAF\0"
	//		file version             4       integer   eg. 1000
	//		duration                 4       float     length of animation in seconds
	//		number of tracks         4       integer
	
	// Verify ile type
	if (reader.readByte != 'C') return NO;
	if (reader.readByte != 'A') return NO;
	if (reader.readByte != 'F') return NO;
	if (reader.readByte != '\0') return NO;
	
	// File version
	NSInteger version = reader.readInteger;

	// Animation duration
	_animationDuration = reader.readFloat;
	
	// Number of nodes (tracks)
	_nodeCount = reader.readInteger;

	LogRez(@"Read header CAF version %i with duration %.3f seconds and containing %i nodes",
		   version, _animationDuration, _nodeCount);

	return !reader.wasReadBeyondEOF;
}

/** Reads a single node and its animation from the content in the specified reader. */
-(BOOL)	readNodeFrom: (CC3DataReader*) reader {
	//	[tracks]
	//		bone id                  4       integer   index to bone
	//		number of keyframes      4       integer

	// Node index and keyframe count
	NSInteger calNodeIdx = reader.readInteger;
	NSInteger frameCount = reader.readInteger;
	if (reader.wasReadBeyondEOF) return NO;

	// If no animation content, skip this node
	if (frameCount <= 0) return YES;

	// Create and populate the animation instance
	CC3ArrayNodeAnimation* anim = [CC3ArrayNodeAnimation animationWithFrameCount: frameCount];
	if ( ![self populateAnimation: anim from: reader] ) return NO;

	// Create the node, add the animation to it, and add it to the nodes array
	CC3CALNode* calNode = [CC3CALNode node];
	calNode.calIndex = calNodeIdx;
	calNode.animation = anim;
	[self.nodes addObject: calNode];

	LogRez(@"Loaded node with CAL index %i with %i keyframes of animation", calNodeIdx, frameCount);
	return YES;
}

/** Populates the specified animation from the content in the specified reader. */
-(BOOL)	populateAnimation: (CC3ArrayNodeAnimation*) anim from: (CC3DataReader*) reader {
	//	[keyframes]
	//		time                   4       float     time of keyframe in seconds
	//		translation x          4       float     relative translation to parent bone
	//		translation y          4       float
	//		translation z          4       float
	//		rotation x             4       float     relative rotation to parent bone
	//		rotation y             4       float     stored as a quaternion
	//		rotation z             4       float
	//		rotation w             4       float

	// Allocate the animation content arrays
	ccTime* frameTimes = anim.allocateFrameTimes;
	CC3Vector* locations = anim.allocateLocations;
	CC3Quaternion* quaternions = anim.allocateQuaternions;

	NSInteger frameCount = anim.frameCount;
	for (NSInteger fIdx = 0; fIdx < frameCount; fIdx++) {
		
		// Frame time, normalized to range between 0 and 1.
		frameTimes[fIdx] = CLAMP(reader.readFloat / _animationDuration, 0.0f, 1.0f);

		// Location at frame
		locations[fIdx].x = reader.readFloat;
		locations[fIdx].y = reader.readFloat;
		locations[fIdx].z = reader.readFloat;

		// Rotation at frame
		quaternions[fIdx].x = reader.readFloat;
		quaternions[fIdx].y = reader.readFloat;
		quaternions[fIdx].z = reader.readFloat;
		quaternions[fIdx].w = reader.readFloat;
	}
	
	return !reader.wasReadBeyondEOF;
}

@end