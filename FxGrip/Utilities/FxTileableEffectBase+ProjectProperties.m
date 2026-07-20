//
//  FxGripOOBParameterAccess.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxTileableEffectBase+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"


@implementation FxTileableEffectBase (ProjectProperties)

/*!
	@method     -documentID
	@discussion This returns 0 when there is no Project.  This also returns 0 when in a project within Motion.
				When used in Final Cut Pro, each instance of the plugin has its own documentId
	@result     NSUInteger	The serial number of the Plugin Instance within the document.
 */
- (NSUInteger)projectDocumentID
{
	NSError *error = nil;
	NSUInteger docId = 0;
	docId = [self projectDocumentIDWithError:&error];
	if (error) {
		NSLog(@"Error: getting documentIDWithError: %@", error);
	}
	return docId;
}

- (BOOL)isProjectMotion
{
	return self.projectDocumentID == 0;
}

- (BOOL)isProjectFinalCutPro
{
	return self.projectDocumentID != 0;
}

- (NSUInteger)projectDocumentIDWithError:(NSError**)error
{
	NSUInteger documentId = 0;
#if DEBUG
	if((
#endif
	   [self.apiManager.projectAPIv1 documentID:&documentId error:error]
#if !DEBUG
		;
#else
			)) {
		NSLog(@"%s(%llu) - Document ID is %d", __func__, self.apiManager.sessionID, (int)documentId);
	} else {
		NSLog(@"Error: %s(%llu) - Document ID error %@", __func__, self.apiManager.sessionID, *error);
	}
#endif
	return documentId;
}


// @todo,  document what this is
- (NSURL* _Nullable)projectMediaFolder
{
   NSError *error = nil;
   return [self projectMediaFolderWithError:&error];
}


-(NSURL* _Nullable)projectMediaFolderWithError:(NSError * _Nullable *)error
{
	NSURL *mediaFolder = nil;
	
	if ([self.apiManager.projectAPIv1 mediaFolderURL:&mediaFolder error:error]) {
		NSLog(@"%s(%llu) - Document Media Folder is %@", __func__, self.apiManager.sessionID, [mediaFolder standardizedURL]);
	} else {
		NSLog(@"%s(%llu) - no media folder", __func__, self.apiManager.sessionID);
	}
	return mediaFolder;
}

- (float)projectAspectRatio
{
	NSError *error = nil;
	return [self projectAspectRatioWithError:&error];
}

- (float)projectAspectRatioWithError:(NSError * _Nullable *)error
{
	float aspectFloat = 0.0;
	
	if ([self.apiManager.projectAPIv2 projectAspectRatio:&aspectFloat error:error]) {
		return aspectFloat;
	}
	return kAspectRatio16x9;
}


@end
