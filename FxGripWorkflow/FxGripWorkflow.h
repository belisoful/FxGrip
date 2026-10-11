/*!
	@file       FxGripWorkflow.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflow
	@abstract   The umbrella header for the FxGripWorkflow framework.
	@discussion Introduced in FxGrip 0.1.0. FxGripWorkflow is the companion framework a Final Cut Pro
	            workflow extension links. It supplies the principal view controller base, the Final
	            Cut Pro host client, and the mailbox client that reaches the plug-in instances built
	            on FxGrip. It links FxGrip for the FCPXML model and the mailbox.
*/

#import <Foundation/Foundation.h>

/*! The framework's version number, as Xcode emits it for a linked framework. */
FOUNDATION_EXPORT double FxGripWorkflowVersionNumber;

/*! The framework's version string, as Xcode emits it for a linked framework. */
FOUNDATION_EXPORT const unsigned char FxGripWorkflowVersionString[];

#import <FxGripWorkflow/FxGripFinalCutHost.h>
#import <FxGripWorkflow/FxGripWorkflowClient.h>
#import <FxGripWorkflow/FxGripWorkflowViewController.h>
