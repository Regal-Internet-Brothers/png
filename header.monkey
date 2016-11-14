Strict

Public

' Imports (Public):
Import config

' Imports (Private):
Private

Import util

Public

' Classes:

' The contents of an IHDR chunk; PNG header information.
Class PNGHeader Implements PNGEntity Final
	' Methods:
	Method Read:Void(input:Stream)
		Self.width = input.ReadInt()
		Self.height = input.ReadInt()
		
		Self.depth = input.ReadByte()
		Self.color_type = input.ReadByte()
		Self.compression_method = input.ReadByte()
		Self.filter_method = input.ReadByte()
		Self.interlace_method = input.ReadByte()
	End
	
	' Properties:
	Method ByteDepth:Int() Property
		Return BitDepthInBytes(depth)
	End
	
	Method ColorChannels:Int() Property
		Select (color_type)
			Case PNG_COLOR_TYPE_GRAYSCALE
				Return 1
			Case PNG_COLOR_TYPE_TRUECOLOR
				Return 3
			Case PNG_COLOR_TYPE_INDEXED
				Return 1
			Case PNG_COLOR_TYPE_GRAYSCALE_ALPHA
				Return 2
			Case PNG_COLOR_TYPE_TRUECOLOR_ALPHA
				Return 4
		End Select
		
		Return 0
	End
	
	' Fields:
	Field width:Int, height:Int ' UInt, UInt
	Field depth:Int ' Byte
	Field color_type:Int ' Byte
	Field compression_method:Int ' Byte
	Field filter_method:Int ' Byte
	Field interlace_method:Int ' Byte
End