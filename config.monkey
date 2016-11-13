Strict

Public

' Preprocessor related:
#If CONFIG = "debug"
	#REGAL_PNG_DEBUG = True
#End

#REGAL_PNG_SAFE = True

#If REGAL_PNG_SAFE
	#REGAL_PNG_SAFE_CHUNKS = True
#End

#If REGAL_PNG_DEBUG
	#REGAL_PNG_DEBUG_STREAMS = True
	#REGAL_PNG_DEBUG_STATES = True
#End