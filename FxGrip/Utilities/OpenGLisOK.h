/*!
	@file       OpenGLisOK.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     OpenGLisOK
	@abstract   Silences the OpenGL deprecation warnings for translation units that use legacy GL.
	@discussion Introduced in FxGrip 0.1.0. Apple deprecated OpenGL on macOS, so every use of a
	            GL symbol emits a warning. A translation unit that still calls OpenGL imports this
	            header first to define GL_SILENCE_DEPRECATION before the GL headers.
*/

#ifndef OpenGLisOK_h
#define OpenGLisOK_h

#ifndef GL_SILENCE_DEPRECATION
#define GL_SILENCE_DEPRECATION
#endif

#endif
