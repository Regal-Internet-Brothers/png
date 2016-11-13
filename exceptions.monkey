Strict

Public

#Rem
	PNG exception types, throwable when performing operations using PNG data-streams.
#End

' Imports (Public):
Import config

' Imports (Private):
Private

Import util
Import image
Import decode

Public

' Exceptions:
Class PNGException Extends Throwable
	' Constructor(s):
	Method New(entity:PNGEntity)
		Self.entity = entity
	End
	
	' Methods:
	Method ToString:String()
		Return "An error occured while processing a PNG file."
	End
	
	' Fields:
	Field entity:PNGEntity
End

Class PNGInputException Extends PNGException
	Public
		' Constructor(s):
		
		' The 'state' argument is not guaranteed to reference an object.
		Method New(content:PNG, state:PNGDecodeState) ' state:PNGDecodeState=Null
			Super.New(content)
			
			Self.content = content
			Self.state = state
		End
		
		' Methods (Abstract):
		Method ToString:String() Abstract
		
		' Properties:
		Method Content:PNG() Property
			Return Self.content
		End
		
		Method State:PNGDecodeState() Property
			Return Self.state
		End
	Private
		' Fields:
		Field content:PNG
		Field state:PNGDecodeState
End

Class PNGIdentityError Extends PNGInputException
	' Constructor(s):
	Method New(content:PNG, state:PNGDecodeState=Null)
		Super.New(content, state)
	End
	
	' Methods:
	Method ToString:String()
		Return "Unable to decode the input as a PNG data-stream."
	End
End

Class PNGDecodeError Extends PNGInputException
	Public
		' Constructor(s):
		Method New(content:PNG, state:PNGDecodeState, message:String)
			Super.New(content, state)
			
			Self.message = message
		End
		
		' Methods:
		Method ToString:String()
			Local output:= "PNG DECODE ERROR: ~q" + message + "~q"
			
			#If REGAL_PNG_DEBUG
				#If REGAL_PNG_DEBUG_STATES
					output += " { " + state.ChunkName + "[" + state.ChunkLength + "] }"
				#End
				
				#If REGAL_PNG_DEBUG_STREAMS
					output += " | POSITION: " + Content._dbg_stream.Position
				#End
			#End
			
			Return output
		End
		
		' Properties:
		Method Message:String() Property
			Return message
		End
	Private
		' Fields:
		Field message:String
End