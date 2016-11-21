Strict

Public

' Friends:
Friend regal.png.image
Friend regal.png.util

' Imports (Public):
Import config

' Imports (Private):
Private

Import util
Import header
Import image
Import imageview

Import regal.inflate

'#If REGAL_PNG_SAFE
Import regal.util.memory
'#End

Public

' Classes:
Class PNGDecodeState Implements PNGEntity Final
	Public
		' Functions:
		
		' This retrieves a color from 'line_view' at 'channel' and optionally scales it to 'scale_max'.
		Function GetColor:Int(line_view:ImageView, channel:Int, scaled:Bool, scale_max:Int=$FF)
			Local value:= line_view.Get(channel)
			
			If (scaled And value > 0) Then
				Return Min(Int(Float(value) * (Float(scale_max) / Float(line_view.BitMask))), scale_max)
			Endif
			
			Return value
		End
		
		' The return-value of this function indicates if the operation was successful.
		Function TransferPixel:Bool(image_buffer:DataBuffer, line_view:ImageView, image_position:Int, channel_position:Int, color_type:Int, scale_colors:Bool=True, palette_data:Int[]=[])
			Select (color_type)
				Case PNG_COLOR_TYPE_GRAYSCALE
					Local gray:= GetColor(line_view, channel_position, scale_colors)
					
					'DebugStop()
					
					image_buffer.PokeInt(image_position, EncodeColor(gray, gray, gray))
				Case PNG_COLOR_TYPE_TRUECOLOR
					Local r:= GetColor(line_view, channel_position, scale_colors)
					Local g:= GetColor(line_view, (channel_position + 1), scale_colors)
					Local b:= GetColor(line_view, (channel_position + 2), scale_colors)
					
					image_buffer.PokeInt(image_position, EncodeColor(r, g, b))
				Case PNG_COLOR_TYPE_INDEXED
					Local color_index:= line_view.Get(channel_position)
					
					image_buffer.PokeInt(image_position, palette_data[color_index])
				Case PNG_COLOR_TYPE_GRAYSCALE_ALPHA
					Local gray:= GetColor(line_view, channel_position, scale_colors)
					Local alpha:= GetColor(line_view, (channel_position + 1), scale_colors)
					
					'DebugStop()
					
					image_buffer.PokeInt(image_position, EncodeColor(gray, gray, gray, alpha))
				Case PNG_COLOR_TYPE_TRUECOLOR_ALPHA
					Local r:= GetColor(line_view, channel_position, scale_colors)
					Local g:= GetColor(line_view, (channel_position + 1), scale_colors)
					Local b:= GetColor(line_view, (channel_position + 2), scale_colors)
					Local a:= GetColor(line_view, (channel_position + 3), scale_colors)
					
					image_buffer.PokeInt(image_position, EncodeColor(r, g, b, a))
				Default
					' The color-type specified is unsupported.
					Return False
			End
			
			' Return the default response.
			Return True
		End
		
		' Constructor(s):
		Method New()
			' Nothing so far.
		End
		
		' Destructor(s):
		
		' This routine is currently experimental.
		Method Close:Void()
			Self.inflate_context = Null
			Self.inflate_session = Null
		End
		
		' Methods:
		
		' This reads the identity of a chunk; represented by the 'ChunkName' property.
		' The return-value is the size of the subsequent chunk-segment.
		Method ReadChunkHeader:Int(input:Stream)
			Self.chunk_length = input.ReadInt()
			Self.chunk_type = input.ReadString(PNG_CHUNK_IDENT_LENGTH, "ascii")
			
			Return Self.chunk_length
		End
		
		' This initializes the internal scan-line buffer.
		Method InitializeLineBuffer:Bool(header:PNGHeader)
			#If REGAL_PNG_SAFE
				If (Self.line_buffer <> Null) Then
					Return False
				Endif
			#End
			
			' Example of line layout for indexed PNG:
			' FILTER | 0 2 0 0 1 1 1 0 0 2 0
			' FILTER | 0 2 0 1 0 0 0 1 0 2 0
			' FILTER | 3 2 0 0 1 1 1 0 0 2 3
			
			' Where 'FILTER' is a one-byte filtering mode referenced
			' in the header, but still available on each line.
			
			Local line_length:= header.LineLength
			
			' Allocate a raw image buffer to store decoded output from the data-stream.
			' The size of this buffer is the maximum number of bytes required
			' to store two lines of pixels from the data-stream described by 'header'.
			Self.line_buffer = New DataBuffer(line_length * 2)
			
			'#If REGAL_PNG_SAFE Or CONFIG = "debug"
			SetBuffer(Self.line_buffer, 0)
			'#End
			
			' Create an image-view of our line-buffer.
			Self.line_view = New ImageView(Self.line_buffer, header.ColorChannels, header.TotalDepth, line_length)
			
			#If REGAL_PNG_SAFE
				Return (Self.line_buffer <> Null) ' And (Self.line_buffer.Length > 0)
			#Else
				Return True
			#End
		End
		
		Method InitializePaletteBuffer:Bool(chunk_length:Int)
			' Ensure this chunk's length is divisible by 3 (RGB):
			If ((chunk_length Mod 3) <> 0) Then
				Return False
			Endif
			
			Self.Palette(New Int[chunk_length / 3], False)
			
			' Return the default response.
			Return True ' Self.palette_found
		End
		
		' This applies the contents of 'data' to the internal palette buffer.
		' NOTE: If palettes aren't used in the decoding process, this will fail.
		' The return-value of this method indicates if the desired operation took place.
		Method PatchPalette:Bool(data:Int[], count:Int, data_offset:Int=0, internal_offset:Int=0)
			If ((internal_offset+count) > Self.palette_data.Length Or (data_offset + count) > data.Length) Then
				Return False
			Endif
			
			For Local index:= 0 Until count
				Self.palette_data[(internal_offset + index)] = data[(data_offset + index)]
			Next
			
			' Return the default response.
			Return True
		End
		
		Method PatchPalette:Bool(data:Int[])
			Return PatchPalette(data, data.Length)
		End
		
		' Decoding routines:
		
		' This decodes the raw contents of a line from the inflation-stream.
		' The 'file' argument must reference a valid 'PNG' object.
		' The return-value of this command is an inflation response-code.
		Method DecodeLine:Int(file:PNG, line_view:ImageView, line_length:Int) ' header:PNGHeader
			Local inflate_response:Int
			
			Local line_stream:= Self.inflate_session.destination
			Local line_buffer:= line_view.Data ' line_stream.Data ' Self.line_buffer
			
			Local start_position:= line_stream.Position
			
			'DebugStop()
			
			' Not the most efficient approach, but it works:
			If (start_position = line_stream.Length) Then
				' Make a copy of the second line and place it at the beginning of the buffer.
				line_buffer.CopyBytes(line_length, line_buffer, 0, line_length)
				
				' Now that the previous line has been copied to the beginning, seek back
				' to the middle of the stream so that the current line may be placed there.
				start_position = line_stream.Seek(line_length)
				
				' Update the line-view to begin at the current line.
				'line_view.Offset = line_length
			Endif
			
			' Get the filtering type from the input-stream, then fix the output-position:
			inflate_response = InflateBytes(line_stream, Self, PNG_FILTER_HEADER_LENGTH)
			
			' Check if we should continue:
			If (inflate_response <> INF_OK) Then
				Return inflate_response
			Endif
			
			' Load the filter-type from the line-stream.
			'Self.filter_type = (line_stream.ReadByte() & $FF)
			Self.filter_type = (line_buffer.PeekByte(line_view.Offset) & $FF)
			
			' Seek back to where we were.
			line_stream.Seek(start_position)
			
			' Read a line from the data-stream:
			While (line_stream.Position < (start_position + line_length))
				inflate_response = Inflate_Checksum(Self.inflate_context, Self.inflate_session, True) ' Inflate
				
				' Check if we're not continuing the line:
				If (inflate_response <> INF_OK) Then
					Exit ' Return inflate_response
				Endif
			Wend
			
			Return inflate_response
		End
		
		' The return-value of this command indicates if the line was
		' filtered according to the filtering type specified.
		Method FilterLine:Bool(line_view:ImageView, line_width:Int, line_length:Int, filter_type:Int, filter_method:Int=PNG_FILTER_METHOD_DEFAULT)
			Local line_buffer:= line_view.Data
			
			Local offset:= line_view.Offset
			Local stride:= line_view.DepthInBytes
			
			' Check which filtering type was specified:
			Select (filter_type)
				Case PNG_FILTER_TYPE_NONE
					Return True
				Case PNG_FILTER_TYPE_SUB
					Return FilterLine_Sub(line_buffer, line_length, offset, stride)
				Case PNG_FILTER_TYPE_UP
					Return FilterLine_Up(line_buffer, line_length, offset, stride)
				Case PNG_FILTER_TYPE_AVERAGE
					Return FilterLine_Average(line_buffer, line_length, offset, stride)
				Case PNG_FILTER_TYPE_PAETH
					Return FilterLine_Paeth(line_buffer, line_length, offset, stride)
			End Select
			
			' Return the default response.
			Return False
		End
		
		' The first filter-type using filter-method zero.
		Method FilterLine_Sub:Bool(line_buffer:DataBuffer, line_length:Int, view_offset:Int, pixel_stride:Int)
			Local left_position:= 0
			
			For Local I:= pixel_stride Until line_length
				Local position:= (view_offset + I)
				
				Local x:= (line_buffer.PeekByte(position) & $FF) ' Current
				Local a:= (line_buffer.PeekByte(view_offset + left_position) & $FF) ' Left
				
				line_buffer.PokeByte(position, ((x + a) & $FF))
				
				left_position += 1
			Next
			
			Return True
		End
		
		' The second filter-type using filter-method zero.
		Method FilterLine_Up:Bool(line_buffer:DataBuffer, line_length:Int, view_offset:Int, pixel_stride:Int)
			For Local I:= 0 Until line_length
				Local position:= (view_offset + I)
				
				Local x:= (line_buffer.PeekByte(position) & $FF) ' Current
				Local b:= (line_buffer.PeekByte(I) & $FF) ' Up
				
				line_buffer.PokeByte(position, ((x + b) & $FF))
			Next
			
			Return True
		End
		
		' The third filter-type using filter-method zero.
		Method FilterLine_Average:Bool(line_buffer:DataBuffer, line_length:Int, view_offset:Int, pixel_stride:Int)
			For Local I:= 0 Until line_length
				Local position:= (view_offset + I)
				
				Local x:= (line_buffer.PeekByte(position) & $FF) ' Current
				
				Local a:Int ' Left
				
				Local left_offset:= (I - pixel_stride)
				
				If (left_offset < 0) Then
					a = 0
				Else
					a = (line_buffer.PeekByte(left_offset + view_offset) & $FF)
				Endif
				
				Local b:= (line_buffer.PeekByte(I) & $FF) ' Up
				
				line_buffer.PokeByte(position, (x + ((a + b) / 2)) & $FF) ' Shr 1
			Next
			
			Return True
		End
		
		' The fourth and final filter-type defined for filter-method zero.
		Method FilterLine_Paeth:Bool(line_buffer:DataBuffer, line_length:Int, view_offset:Int, pixel_stride:Int)
			For Local I:= 0 Until line_length
				Local position:= (view_offset + I)
				
				Local x:= (line_buffer.PeekByte(position) & $FF) ' Current
				
				Local a:Int
				Local c:Int
				
				Local left_offset:= (I - pixel_stride)
				
				If (left_offset < 0) Then
					a = 0
					c = 0
				Else
					a = (line_buffer.PeekByte(view_offset + left_offset) & $FF) ' Left
					c = (line_buffer.PeekByte(left_offset) & $FF) ' Top-Left
				Endif
				
				Local b:= (line_buffer.PeekByte(I) & $FF) ' Up
				
				Local p:= (a + b - c)
				
				Local pa:= Abs(p - a)
				Local pb:= Abs(p - b)
				Local pc:= Abs(p - c)
				
				Local pr:Int
				
				If (pa <= pb And pa <= pc) Then
					pr = a
				Elseif (pb <= pc) Then
					pr = b
				Else
					pr = c
				Endif
				
				line_buffer.PokeByte(position, ((x + pr) & $FF))
			Next
			
			Return True
		End
		
		' This transfers the contents of 'line_view' into 'image_buffer'.
		Method TransferLine:Void(image_buffer:DataBuffer, line_view:ImageView, line_width:Int, pixel_stride:Int, color_type:Int, scale_colors:Bool) ' palette_data:Int[]
			Local color_channels:= line_view.Channels
			
			Local image_position:= ((line_width * Self.current_height) * pixel_stride)
			Local channel_position:= 0
			
			For Local x:= 0 Until line_width
				TransferPixel(image_buffer, line_view, image_position, channel_position, color_type, scale_colors, palette_data) ' Self.palette_data
				
				image_position += pixel_stride
				channel_position += color_channels
			Next
		End
		
		' Properties:
		
		' This specifies if the IHDR chunk has been loaded.
		' To view the header's contents, see 'Header'.
		Method HeaderFound:Bool() Property
			Return Self.header_found
		End
		
		#Rem
			This specifies if all valid image data has been loaded.
			
			This does not take final image-creation into account,
			only that all raw data has been retrieved inflated correctly.
			
			By definition, if this property reports 'True',
			'ImageDataFound' must also report 'True'.
		#End
		
		Method ImageDataComplete:Bool() Property
			Return Self.image_data_complete
		End
		
		' This specifies if at least one IDAT chunk has been loaded.
		Method ImageDataFound:Bool() Property
			Return Self.image_data_found
		End
		
		' This specifies if a PLTE was loaded
		Method PaletteFound:Bool() Property
			Return Self.palette_found
		End
		
		Method EndFound:Bool() Property
			Return Self.end_found
		End
		
		' The length of the current chunk. (Same as the return-value of 'ReadChunkHeader')
		Method ChunkLength:Int() Property
			Return Self.chunk_length
		End
		
		' The name (ASCII String) of the current (Last acquired) chunk.
		Method ChunkName:String() Property
			Return Self.chunk_type ' chunk_name
		End
		
		' The integral equivalent of 'ChunkName'.
		Method ChunkType:Int() Property
			Local name:= Self.ChunkName
			
			Return EncodeInt(name[0], name[1], name[2], name[3])
		End
		
		' This represents the current palette data.
		' If palette data has yet to be provided,
		' this will supply an empty array.
		Method Palette:Int[]() Property ' UInt[]
			Return Self.palette_data
		End
		
		' This is used to manually assign/override the internal palette buffer.
		' The palette data specified must be at least as large as the current palette buffer.
		' For variable palette sizes, you must patch the existing buffer using 'PatchPalette'.
		Method Palette:Bool(data:Int[], __custom:Bool=True) Property
			' Empty palettes are automatically invalid:
			If (data.Length = 0) Then
				Return False
			Endif
			
			#If REGAL_PNG_SAFE
				If (data.Length < Self.palette_data.Length) Then
					Return False
				Endif
			#End
			
			Self.palette_data = data
			Self.palette_found = (data.Length > 0) ' (Self.palette_data.Length > 0)
			Self.custom_palette = __custom
			
			Return True
		End
	Private
		' Global variable(s):
		Global __inf_ctx:= New InfContext()
	Protected
		' Fields:
		
		#Rem
			This stores the current Y coordinate in the targeted 'PNG' object's image-buffer.
			This variable is stored here in order to preserve its state between multiple decode-passes.
		#End
		
		Field current_height:Int
		
		#Rem
			The last known filter-type associated with
			the current segment of the line-buffer.
			
			This should not be confused with 'PNGHeader.filter_method',
			which specifies a filtering method for early error detection.
		#End
		
		Field filter_type:Int
		
		' Chunk meta-data:
		Field chunk_length:Int
		Field chunk_type:String ' chunk_name
		
		' Flags:
		Field header_found:Bool
		Field image_data_found:Bool
		Field image_data_complete:Bool
		Field palette_found:Bool
		Field end_found:Bool
		
		Field custom_palette:Bool
		
		' Image-data:
		
		' An array of integers representing RGB(A) colors loaded from
		' a required PLTE chunk when using 'COLOR_TYPE_INDEXED'.
		Field palette_data:Int[] ' UInt[]
		
		' Output:
		
		' A buffer containing the current line-data last taken from a decompression stream.
		' NOTE: This buffer also contains the filter-type header before the image-data.
		Field line_buffer:DataBuffer
		
		' A view of 'line_buffer' offset by the filter-type header.
		Field line_view:ImageView
		
		' Inflation functionality:
		
		' This stores a reference to the shared inflation-session used to decode IDAT blocks.
		Field inflate_session:InfSession
		
		' This stores a reference to a global/shared inflation context.
		Field inflate_context:= __inf_ctx
End