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
	
	' This specifies the accumulative color-depth of a pixel.
	' For bits-per-pixel, use the 'depth' field.
	Method TotalDepth:Int() Property
		Return (depth * ColorChannels)
	End
	
	' This specifies how many bytes are needed to store a pixel.
	Method ByteDepth:Int() Property ' PixelLength
		Return BitDepthInBytes(TotalDepth)
	End
	
	' This specifies how many bytes are required to store a line of pixels.
	Method LineLength:Int() Property
		Return BitDepthInBytes((depth * ColorChannels) * width) ' (width * ByteDepth)
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