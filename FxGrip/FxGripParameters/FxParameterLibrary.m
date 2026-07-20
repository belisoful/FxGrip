


- (BOOL)flagNotAnimatable {
	return flagNotAnimatable(self.parameterFlags);
}


- (void)setFlagNotAnimatable:(BOOL)notAnimatable {
	if (flagNotAnimatable(self.parameterFlags) && !notAnimatable) {
		self.parameterFlags &= ~kFxParameterFlag_NOT_ANIMATABLE;
		
	} else if (!flagNotAnimatable(self.parameterFlags) && notAnimatable) {
		self.parameterFlags |= kFxParameterFlag_NOT_ANIMATABLE;
	}
}



- (BOOL)flagDontSave {
	return flagDontSave(self.parameterFlags);
}


- (void)setFlagDontSave:(BOOL)dontSave {
	if (flagDontSave(self.parameterFlags) && !dontSave) {
		self.parameterFlags &= ~kFxParameterFlag_DONT_SAVE;
		
	} else if (!flagDontSave(self.parameterFlags) && dontSave) {
		self.parameterFlags |= kFxParameterFlag_DONT_SAVE;
	}
}




- (BOOL)flagCurveEditorHidden {
	return flagCurveEditorHidden(self.parameterFlags);
}


- (void)setFlagCurveEditorHidden:(BOOL)curveEditorHidden {
	if (flagCurveEditorHidden(self.parameterFlags) && !curveEditorHidden) {
		self.parameterFlags &= ~kFxParameterFlag_CURVE_EDITOR_HIDDEN;
		
	} else if (!flagCurveEditorHidden(self.parameterFlags) && curveEditorHidden) {
		self.parameterFlags |= kFxParameterFlag_CURVE_EDITOR_HIDDEN;
	}
}





- (BOOL)flagCustomUI {
	return flagCustomUI(self.parameterFlags);
}


- (void)setFlagCustomUI:(BOOL)customUI {
	if (flagCustomUI(self.parameterFlags) && !customUI) {
		self.parameterFlags &= ~kFxParameterFlag_CUSTOM_UI;
		
	} else if (!flagCustomUI(self.parameterFlags) && customUI) {
		self.parameterFlags |= kFxParameterFlag_CUSTOM_UI;
	}
}



- (BOOL)flagUseFullViewWidth {
	return flagUseFullViewWidth(self.parameterFlags);
}


- (void)setFlagUseFullViewWidth:(BOOL)useFullViewWidth {
	if (flagUseFullViewWidth(self.parameterFlags) && !useFullViewWidth) {
		self.parameterFlags &= ~kFxParameterFlag_USE_FULL_VIEW_WIDTH;
		
	} else if (!flagUseFullViewWidth(self.parameterFlags) && useFullViewWidth) {
		self.parameterFlags |= kFxParameterFlag_USE_FULL_VIEW_WIDTH;
	}
}
