Strict

Public

' Imports (Public):
Import config
Import entity

Import brl.stream
Import brl.databuffer

Import regal.ioutil.util

' Imports (Private):
' Nothing so far.

' Constant variable(s):
Const PNG_CHUNK_IDENT_LENGTH:= 4

' Functions:

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

' Currently just a wrapper for 'EncodeColor';
' useful for mapping bytes to integers.
Function EncodeInt:Int(a:Int, b:Int, c:Int, d:Int)
	Return EncodeColor(a, b, c, d)
End

' This allocates a 'DataBuffer' used to storing the contents of an uncompressed image.
Function AllocateImageData:DataBuffer(width:Int, height:Int, color_depth:Int=32)
	Return New DataBuffer(width * height * BitDepthInBytes(color_depth))
End