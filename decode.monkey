Strict

Public

' Friends:
Friend regal.png.image

' Imports (Public):
Import config

' Imports (Private):
Private

Import util
Import header
Import imageview

Import regal.inflate

'#If REGAL_PNG_SAFE
Import regal.util.memory
'#End

Public

' Classes:
Class PNGDecodeState Implements PNGEntity Final
	Public
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
			' Constant variable(s):
			Const FILTER_HEADER_SIZE:= 1
			
			#If REGAL_PNG_SAFE
				If (Self.raw_image_line <> Null) Then
					Return False
				Endif
			#End
			
			' Example of line layout for indexed PNG:
			' FILTER | 0 2 0 0 1 1 1 0 0 2 0
			' FILTER | 0 2 0 1 0 0 0 1 0 2 0
			' FILTER | 3 2 0 0 1 1 1 0 0 2 3
			
			' Where 'FILTER' is a one-byte filtering mode referenced
			' in the header, but still available on each line.
			
			' Allocate a raw image buffer to store decoded output from the data-stream.
			' The size of this buffer is the maximum number of bytes required
			' to store a line from the data-stream described by 'header'.
			Self.raw_image_line = New DataBuffer((header.width * header.ByteDepth) + FILTER_HEADER_SIZE)
			
			#If REGAL_PNG_SAFE Or CONFIG = "debug"
				SetBuffer(Self.raw_image_line, 0)
			#End
			
			' Create an image-view of our line-buffer.
			Self.line_view = New ImageView(Self.raw_image_line, header.ColorChannels, header.depth, FILTER_HEADER_SIZE)
			
			#If REGAL_PNG_SAFE
				Return (Self.raw_image_line <> Null) ' And (Self.raw_image_line.Length > 0)
			#Else
				Return True
			#End
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
	Private
		' Global variable(s):
		Global __inf_ctx:= New InfContext()
	Protected
		' Fields:
		
		' Chunk meta-data:
		Field chunk_length:Int
		Field chunk_type:String ' chunk_name
		
		' Flags:
		Field header_found:Bool
		Field image_data_found:Bool
		Field image_data_complete:Bool
		Field palette_found:Bool
		Field end_found:Bool
		
		' Output:
		
		' A buffer containing the current line-data last taken from a decompression stream.
		' NOTE: This buffer also contains the filter-type header before the image-data.
		Field raw_image_line:DataBuffer
		
		' A view of 'raw_image_line' offset by the filter-type header.
		Field line_view:ImageView
		
		' Inflation functionality:
		
		' This stores a reference to the shared inflation-session used to decode IDAT blocks.
		Field inflate_session:InfSession
		
		' This stores a reference to a global/shared inflation context.
		Field inflate_context:= __inf_ctx
End