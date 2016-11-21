Strict

Public

' Imports (Public):
Import config
Import entity

Import brl.stream
Import brl.databuffer

Import regal.ioutil.util
Import regal.hash.external ' util

' Imports (Private):
Private

Import decode

Import regal.inflate

Public

' Constant variable(s):
Const PNG_ZLIB_HEADER_LENGTH:= 2
Const PNG_CHUNK_IDENT_LENGTH:= 4
Const PNG_FILTER_HEADER_LENGTH:= 1

' Image types:
Const PNG_IMAGE_TYPE_RGBA:= 0
'Const PNG_IMAGE_TYPE_ARGB:= 1
'Const PNG_IMAGE_TYPE_BGRA:= 2

' Color types:
Const PNG_COLOR_TYPE_GRAYSCALE:= 0
Const PNG_COLOR_TYPE_TRUECOLOR:= 2
Const PNG_COLOR_TYPE_INDEXED:= 3
Const PNG_COLOR_TYPE_GRAYSCALE_ALPHA:= 4
Const PNG_COLOR_TYPE_TRUECOLOR_ALPHA:= 6

' Compression methods:
Const PNG_COMPRESSION_METHOD_DEFLATE:= 0

' Filtering related:
Const PNG_FILTER_TYPE_NONE:= 0
Const PNG_FILTER_TYPE_SUB:= 1
Const PNG_FILTER_TYPE_UP:= 2
Const PNG_FILTER_TYPE_AVERAGE:= 3
Const PNG_FILTER_TYPE_PAETH:= 4

Const PNG_FILTER_METHOD_DEFAULT:= 0

' Functions:
Function GammaEnabled:Bool()
	#If REGAL_PNG_DISABLE_GAMMA_CORRECTION
		Return False
	#Else
		Return True
	#End
End

Function GetChannelMaxByType:Int(image_type:Int)
	Select (image_type)
		Case PNG_IMAGE_TYPE_RGBA ' PNG_IMAGE_TYPE_ARGB ' PNG_IMAGE_TYPE_BGRA
			Return 255
	End Select
	
	Return 0
End

' This returns the number of bytes needed to hold 'bits'.
Function BitDepthInBytes:Int(bits:Int)
	Return ((bits + 7) / 8)
End

' Encodes the input color data as an RGBA color.
' Color channels are represented between 0 and 255, with 255 being 100% opaque.
Function EncodeColor:Int(r:Int, g:Int, b:Int, a:Int=255) ' 0
	Local out_r:= ((r & $FF)) ' Shl 0
	Local out_g:= ((g & $FF) Shl 8)
	Local out_b:= ((b & $FF) Shl 16)
	Local out_a:= ((a & $FF) Shl 24)
	
	Return (out_r|out_g|out_b|out_a)
End

Function DecodeColor_R:Int(color:Int)
	Return ((color) & $FF)
End

Function DecodeColor_G:Int(color:Int)
	Return ((color Shr 8) & $FF)
End

Function DecodeColor_B:Int(color:Int)
	Return ((color Shr 16) & $FF)
End

Function DecodeColor_A:Int(color:Int)
	Return ((color Shr 24) & $FF)
End

' Currently just a wrapper for 'EncodeColor';
' useful for mapping bytes to integers.
Function EncodeInt:Int(a:Int, b:Int, c:Int, d:Int)
	Return EncodeColor(a, b, c, d)
End

' This reverses the bit-order in the byte specified.
' Example (Bits): 011 = 110
Function ReverseByte:Int(b:Int)
	b = (b & $FF)
	
	b = Lsr((b & $F0), 4) | Lsl((b & $0F), 4)
	b = Lsr((b & $CC), 2) | Lsl((b & $33), 2)
	b = Lsr((b & $AA), 1) | Lsl((b & $55), 1)
	
	Return b
End

' This allocates a 'DataBuffer' used to storing the contents of an uncompressed image.
Function AllocateImageData:DataBuffer(width:Int, height:Int, color_depth:Int=32)
	Return New DataBuffer(width * height * BitDepthInBytes(color_depth))
End

' This loads 'count' bytes from the inflation-stream specified using 'state' as the output.
' The return-value is an inflate response-code defined by the 'inflate' module.
' NOTE: This does not currently check against 'input', and instead uses 'state' for most work.
Function InflateBytes:Int(input:Stream, state:PNGDecodeState, count:Int)
	Local inflate_response:Int
	
	Local line_stream:= state.inflate_session.destination
	Local start_position:= line_stream.Position
	
	Repeat
		inflate_response = Inflate_Checksum(state.inflate_context, state.inflate_session, True)
	Until (inflate_response <> INF_OK Or line_stream.Position >= (start_position + count))
	
	Return inflate_response
End