/*!
	@file       FxGripOSCShaderTypes.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOSCShaderTypes
	@abstract   Shared vertex, buffer-index, and texture-index types for the FxGrip OSC Metal pipeline.
	@discussion Introduced in FxGrip 0.1.0. The types are compiled by both the Objective-C draw kit and
	            the Metal shaders, so the two agree on buffer layout. The vertex structs carry
	            viewport-centered pixel positions; the index enums name the argument-table slots the
	            vertex and fragment shaders read.
*/

#ifndef FxGripOSCShaderTypes_h
#define FxGripOSCShaderTypes_h

#include <simd/simd.h>

/*!
	@enum       FxGripOSCVertexInputIndex
	@abstract   Vertex-shader buffer indices for the FxGrip OSC pipeline.
*/
typedef enum FxGripOSCVertexInputIndex {
	FxGripOSCVertexInputIndexVertices		= 0,
	FxGripOSCVertexInputIndexViewportSize	= 1,
} FxGripOSCVertexInputIndex;

/*!
	@enum       FxGripOSCFragmentInputIndex
	@abstract   Fragment-shader buffer indices for the FxGrip OSC pipeline.
*/
typedef enum FxGripOSCFragmentInputIndex {
	FxGripOSCFragmentInputIndexColor		= 0,
} FxGripOSCFragmentInputIndex;

/*!
	@enum       FxGripOSCFragmentTextureIndex
	@abstract   Fragment-shader texture indices for the FxGrip OSC textured pipeline.
*/
typedef enum FxGripOSCFragmentTextureIndex {
	FxGripOSCFragmentTextureIndexColor		= 0,
} FxGripOSCFragmentTextureIndex;

/*!
	@struct     FxGripOSCVertex
	@abstract   One on-screen-control vertex, in viewport-centered pixel coordinates.
	@discussion The origin sits at the viewport center; y grows upward. The vertex
				shader divides by half the viewport size to reach clip space.
*/
typedef struct FxGripOSCVertex {
	vector_float2	position;
} FxGripOSCVertex;

/*!
	@struct     FxGripOSCTexturedVertex
	@abstract   One textured on-screen-control vertex.
	@discussion position is in the same viewport-centered pixel space as
				FxGripOSCVertex; texCoord samples the fragment texture, with (0, 0)
				at the texture's top-left and (1, 1) at its bottom-right.
*/
typedef struct FxGripOSCTexturedVertex {
	vector_float2	position;
	vector_float2	texCoord;
} FxGripOSCTexturedVertex;

#endif /* FxGripOSCShaderTypes_h */
