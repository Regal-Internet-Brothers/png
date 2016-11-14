Strict

Public

#Rem
	NOTES:
		* All streams used to interact with this API must be big-endian.
		To process a little-endian (Default) 'Stream' object as big-endian,
		use 'regal.ioutil.EndianStreamManager' and co.
#End

' Friends:
Friend regal.png.decode
Friend regal.png.exceptions

' Imports (Public):
Import config

' Imports (Private):
Private

Import util
Import header
Import decode
Import imageview
Import exceptions

'Import regal.byteorder
Import regal.inflate
Import regal.hash.crc32

Import regal.ioutil.publicdatastream

'Import regal.retrostrings

Public

' Classes:
Class PNG Implements PNGEntity
	Private
		' Constant variable(s):
		Const ASCII_P:= 80
		Const ASCII_N:= 78
		Const ASCII_G:= 71
		
		' Fields:
		
		' Debug:
		#If REGAL_PNG_DEBUG_STREAMS ' REGAL_PNG_DEBUG
			Field _dbg_stream:Stream
		#End
		
		' An object containing the contents of an IHDR chunk.
		Field header:= New PNGHeader()
		
		' The final RGBA color-data used to represent a displayable image.
		Field image_data:DataBuffer
	Public
		' Constant variable(s):
		Const CHUNK_IDENT_LENGTH:= PNG_CHUNK_IDENT_LENGTH
		Const CHECKSUM_LENGTH:= 4
		
		' Chunk response codes (See 'DecodeChunk' for details):
		
		' This response code indicates that the chunk data provided by the
		' user was processed as well as this implementation was able to.
		' This does not always mean the operation was successful,
		' but that this implementation found no errors.
		Const CHUNK_RESPONSE_OK:= 0
		
		' This response code indicates that the chunk-data provided
		' is unknown and should be skipped for stability purposes.
		Const CHUNK_RESPONSE_SKIP:= 1
		
		#Rem
			This response code indicates that further chunk processing should not take place.
			
			When this response-code is provided, an end-of-stream state
			is assumed; including the relevant error checking associated.
		#End
		
		Const CHUNK_RESPONSE_EXIT:= 2
		
		' Color types:
		Const COLOR_TYPE_GRAYSCALE:= PNG_COLOR_TYPE_GRAYSCALE
		Const COLOR_TYPE_TRUECOLOR:= PNG_COLOR_TYPE_TRUECOLOR
		Const COLOR_TYPE_INDEXED:= PNG_COLOR_TYPE_INDEXED
		Const COLOR_TYPE_GRAYSCALE_ALPHA:= PNG_COLOR_TYPE_GRAYSCALE_ALPHA
		Const COLOR_TYPE_TRUECOLOR_ALPHA:= PNG_COLOR_TYPE_TRUECOLOR_ALPHA
		
		Const COLOR_TYPE_GREYSCALE:= COLOR_TYPE_GRAYSCALE
		Const COLOR_TYPE_GREYSCALE_ALPHA:= COLOR_TYPE_GRAYSCALE_ALPHA
		
		' Image types:
		Const IMAGE_TYPE_RGBA:= 0
		'Const IMAGE_TYPE_ARGB:= 1
		'Const IMAGE_TYPE_BGRA:= 2
		
		' Compression methods:
		Const COMPRESSION_METHOD_DEFLATE:= 0
		
		' Filtering methods:
		Const FILTER_METHOD_NONE:= 0
		Const FILTER_METHOD_SUB:= 1
		Const FILTER_METHOD_UP:= 2
		Const FILTER_METHOD_AVERAGE:= 3
		Const FILTER_METHOD_PAETH:= 4
		
		' Functions:
		
		#Rem
			This initializes an inbound 'PNG' object safely (Exception safety).
			
			The same verification behavior as the input constructor(s) applies here.
			
			The difference between this command and the constructor(s)
			is that this attempts to 'sandbox' errors in the loading process,
			including attempting to restore error-prone streams to their original states.
		#End
		
		Function Load:PNG(input:Stream, __length_check:Bool=False)
			Local stream_origin:= input.Position
			
			Try
				Return New PNG(input, __length_check)
			Catch png_error:PNGException
				' Nothing so far.
			Catch stream_error:StreamError
				If (stream_error.GetStream() = input) Then
					input.Seek(stream_origin)
				Else
					Throw stream_error
				Endif
			End Try
			
			Return Null
		End
		
		#Rem
			This is a utility function for reading palette-data from a PLTE chunk.
			
			This reads palette-data from 'input' into 'output'.
			The number of entries read is dependent on 'color_count' and 'color_offset'.
			The 'alpha' argument specifies the transparency shared by the loaded color entries.
		#End
		
		Function ReadPaletteData:Void(input:Stream, output:Int[], color_count:Int, color_offset:Int=0, alpha:Int=255)
			For Local entry:= color_offset Until color_count
				Local red:= input.ReadByte()
				Local green:= input.ReadByte()
				Local blue:= input.ReadByte()
				
				output[entry] = EncodeColor(red, green, blue, alpha)
			Next
		End
		
		#Rem
			This is a utility function used to detect a PNG data-stream.
			
			This reads from 'input' in order to ensure that the
			consumed data matches the PNG format's signature.
			
			The stream-position is restored if the signature is invalid,
			but left as-is if an exception is thrown.
			
			If the format was verified, the stream will begin at the beginning of
			the first chunk (IHDR) unless directed otherwise ('restore_anyway').
		#End
		
		Function VerifyPNG:Bool(input:Stream, restore_anyway:Bool=False, __length_check:Bool=False)
			Local position:= input.Position
			
			If (Not _VerifyPNG_Impl(input, __length_check)) Then
				input.Seek(position)
				
				Return False
			Endif
			
			If (restore_anyway) Then
				input.Seek(position)
			Endif
			
			Return True
		End
		
		' This is a utility function which returns a boolean value indicating
		' if the 'color_type' specified supports the 'depth' provided.
		' This does not reflect this implementation, but rather, the PNG specification.
		Function VerifyDepth:Bool(color_type:Int, depth:Int)
			Select (color_type)
				Case COLOR_TYPE_GRAYSCALE
					Select (depth)
						Case 1, 2, 4, 8, 16;
						Default; Return False
					End Select
				Case COLOR_TYPE_TRUECOLOR
					Select (depth)
						Case 8, 16;
						Default; Return False
					End Select
				Case COLOR_TYPE_INDEXED
					Select (depth)
						Case 1, 2, 4, 8;
						Default; Return False
					End Select
				Case COLOR_TYPE_GRAYSCALE_ALPHA
					Select (depth)
						Case 8, 16
						Default; Return False
					End Select
				Case COLOR_TYPE_TRUECOLOR_ALPHA
					Select (depth)
						Case 8, 16
						Default; Return False
					End Select
				Default
					Return False
			End Select
			
			' Return the default response.
			Return True
		End
		
		#Rem
			This is a utility function used to handle chunk-integrity verification.
			
			The return-value indicates if the serialized checksum matches the checksum of the input-chunk.
			
			If the checksums match, the input-stream will be positioned where it was before calling this function.
			After further chunk-processing instigated by the user, it should be noted that the CRC's location
			is at the end of the chunk, and should therefore be skipped later down the line.
			
			In the event the return-value is 'False', the stream will either move past both the
			chunk and CRC, or remain just before the CRC if 'update_position_on_error' is disabled.
		#End
		
		Function VerifyChunkIntegrity:Bool(input:Stream, chunk_begin:Int, chunk_length:Int, update_position_on_error:Bool=True)
			' Seek forward to view the CRC checksum of this chunk:
			input.Seek(chunk_begin + chunk_length)
			
			' Get the CRC checksum encoded in the input-stream.
			Local serial_crc_checksum:= input.ReadInt()
			
			' Log our current position.
			Local post_crc_position:= input.Position
			
			' The chunk-type is included in the CRC calculation.
			input.Seek(chunk_begin - CHUNK_IDENT_LENGTH)
			
			' Allocate a buffer for this segment of the file. (Chunk data and type)
			Local buffer_segment:= New DataBuffer(chunk_length + CHUNK_IDENT_LENGTH)
			
			' Read the file-segment from 'input'.
			input.ReadAll(buffer_segment, 0, buffer_segment.Length) ' chunk_length + CHUNK_IDENT_LENGTH
			
			' Generate a CRC32 hash from the segment we took.
			Local generated_crc_checksum:= CRC32(buffer_segment, buffer_segment.Length, 0)
			
			' Discard the buffer we allocated; no longer needed.
			buffer_segment.Discard()
			
			' Compare the two hashes:
			If (serial_crc_checksum = generated_crc_checksum) Then
				' Move back to where we started.
				input.Seek(chunk_begin)
				
				Return True
			Else
				If (update_position_on_error) Then
					' Seek past this chunk; invalid content.
					input.Seek(post_crc_position)
				Endif
			Endif
			
			Return False
		End
		
		#Rem
			This skips a chunk's data-segment, reporting debug information if requested.
			This returns 'True' if the operation was required to be performed.
			
			NOTES:
				* This will only return 'False' if the operation was unnecessary.
				In other words, this should always perform the action requested, barring exceptions.
		#End
		
		Function SkipChunkData:Bool(input:Stream, chunk_begin:Int, chunk_length:Int, position_check:Bool=True, __dbg_print:Bool=False)
			Local chunk_end:= (chunk_begin + chunk_length)
			
			If (Not position_check Or input.Position < chunk_end) Then
				#If REGAL_PNG_DEBUG_OUTPUT
					If (__dbg_print) Then
						Print("{ PNG CHUNK DATA SKIPPED } [" + chunk_begin + " -> " + chunk_end + "]")
					Endif
				#End
				
				input.Seek(chunk_end)
				
				Return True
			Endif
			
			Return False
		End
		
		Function SkipChunkChecksum:Void(input:Stream)
			' Skip the CRC32 checksum.
			SeekForward(input, CHECKSUM_LENGTH)
		End
		
		' This is largely used for debugging purposes.
		Function ColorTypeToString:String(color_type:Int)
			Select (color_type)
				Case COLOR_TYPE_GRAYSCALE
					Return "Grayscale"
				Case COLOR_TYPE_TRUECOLOR
					Return "Truecolor"
				Case COLOR_TYPE_INDEXED
					Return "Indexed"
				Case COLOR_TYPE_GRAYSCALE_ALPHA
					Return "Grayscale+Alpha"
				Case COLOR_TYPE_TRUECOLOR_ALPHA
					Return "Truecolor+Alpha"
			End Select
			
			Return ""
		End
		
		' Constructor(s):
		
		' If identification fails normally (Data mismatch),
		' this will restore the position of the stream.
		' However, a 'PNGIdentityError' object will be thrown.
		Method New(input:Stream, __length_check:Bool=False)
			If (Not VerifyPNG(input, False, __length_check)) Then
				Throw New PNGIdentityError(Self)
			Endif
			
			_dbg_init(input)
		End
		
		' Methods:
		
		#Rem
			This decodes an IHDR chunk's contents from 'input' into 'header'.
			
			This returns a boolean value indicating if the parameters defined
			by the data-stream are supported by this implementation.
			
			In the event of incompatibility, termination is always performed after loading,
			meaning the stream-position will always traverse the IHDR chunk.
			
			This also means the 'header' will always contain the correct deserialized information.
			
			With that said, however, if 'advanced_errors' is enabled, this command
			reserves the right to throw input-driven exceptions.
		#End
		
		Method IHDR:Bool(input:Stream, state:PNGDecodeState, header:PNGHeader, advanced_errors:Bool=False)
			' Read the header-data from 'input'.
			header.Read(input)
			
			If (advanced_errors) Then
				Select (header.color_type)
					' Acceptable values:
					Case COLOR_TYPE_GRAYSCALE;
					Case COLOR_TYPE_TRUECOLOR;
					Case COLOR_TYPE_INDEXED;
					Case COLOR_TYPE_GRAYSCALE_ALPHA;
					Case COLOR_TYPE_TRUECOLOR_ALPHA;
					
					' Unknown values:
					Default
						Throw New PNGDecodeError(Self, state, "Invalid color-type specified: " + header.color_type)
				End Select
			Endif
			
			' Report limitations:
			
			' Implementation-specific limitations:
			
			#Rem
				' This implementation does not support 64-bit color space.
				If (header.depth > 32) Then
					Return False
				Endif
			#End
			
			#Rem
				' Currently, only 8-bit colors are supported.
				If (header.depth <> 8) Then
					Return False
				Endif
			#End
			
			' Specification 'mandated' restraints:
			If (advanced_errors) Then
				If (Not VerifyDepth(header.color_type, header.depth)) Then
					Throw New PNGDecodeError(Self, state, "The '" + ColorTypeToString(header.color_type) + "' color-type does not support a depth of: " + header.depth)
				Endif
			Endif
			
			' Non-standard compression methods are not supported.
			If (header.compression_method <> COMPRESSION_METHOD_DEFLATE) Then
				Return False
			Endif
			
			Return True
		End
		
		Method PLTE:Void(input:Stream, state:PNGDecodeState, palette_data:Int[], advanced_errors:Bool=False) ' True
			PLTE(input, state, palette_data, palette_data.Length, 0, advanced_errors)
		End
		
		Method PLTE:Void(input:Stream, state:PNGDecodeState, palette_data:Int[], palette_length:Int, palette_offset:Int, advanced_errors:Bool=False) ' True
			ReadPaletteData(input, palette_data, palette_length, palette_offset)
		End
		
		' The return-value of this routine indicates if the chunk's contents were compatible and therefore processed.
		Method IDAT:Bool(input:Stream, state:PNGDecodeState, header:PNGHeader, image_buffer:DataBuffer, chunk_length:Int, initialize:Bool, advanced_errors:Bool=False)
			' Constant variable(s):
			Const ZLIB_HEADER_SIZE:= 2
			
			If (initialize) Then
				' Initialize the temporary line-buffer.
				state.InitializeLineBuffer(header)
				
				' Initialize an inflate session.
				state.inflate_session = New InfSession(input, New PublicDataStream(state.raw_image_line, state.raw_image_line.Length), 1)
				
				' Read the 'zlib' compression-header at the start of the chunk-data.
				' This also performs basic setup work for 'Inflate_Checksum'.
				Local zlib_header_response:= InfParseZLibHeader(state.inflate_session) ' CINFO
				
				' Check if an internal error was found while interpreting the compression-header:
				If (zlib_header_response = INF_DATA_ERROR) Then
					Return False
				Endif
			Else
				#If REGAL_PNG_SAFE
					state.inflate_session.source = input
				#End
			Endif
			
			Local initial_input_position:= input.Position
			Local chunk_end_position:= (initial_input_position + (chunk_length - ZLIB_HEADER_SIZE))
			
			Local inflate_response:Int
			
			Local current_height:= 0
			
			Local pixel_stride:= Self.PixelStride
			Local line_buffer:= state.raw_image_line
			
			Repeat
				Local line_stream:= state.inflate_session.destination
				
				' Ensure the inflation-stream outputs at the beginning of the line-buffer.
				line_stream.Seek(0)
				
				'DebugStop()
				
				' Read a line from the data-stream:
				While (line_stream.Position < line_buffer.Length)
					inflate_response = Inflate_Checksum(state.inflate_context, state.inflate_session, True) ' Inflate
					
					' Check if we're not continuing the line:
					If (inflate_response <> INF_OK) Then
						Exit
					Endif
				Wend
				
				' If we're not continuing, let the end of the function handle response-code behavior:
				If (inflate_response <> INF_OK) Then
					Exit
				Endif
				
				Local len:= line_buffer.Length
				Local pos:= line_stream.Position
				
				'DebugStop()
				
				' Get the filtering type from the line-buffer.
				Local filter_type:= line_buffer.PeekByte(0)
				
				'Print("filter_type["+current_height+"]: " + filter_type)
				
				Local line_view:= state.line_view
				Local color_channels:= line_view.Channels
				
				' Check which filtering type was specified:
				Select (filter_type)
					Case FILTER_METHOD_NONE
						' Nothing so far.
					Case FILTER_METHOD_SUB
						' Nothing so far.
					Case FILTER_METHOD_UP
						' Nothing so far.
					Case FILTER_METHOD_AVERAGE
						' Nothing so far.
					Case FILTER_METHOD_PAETH
						' Nothing so far.
				End Select
				
				Local buffer_line_offset:= ((header.width * current_height) * pixel_stride)
				
				Local image_position:= buffer_line_offset
				Local channel_position:= 0
				
				'DebugStop()
				
				For Local x:= 0 Until header.width
					Select (header.color_type)
						Case COLOR_TYPE_GRAYSCALE
						Case COLOR_TYPE_TRUECOLOR
						Case COLOR_TYPE_INDEXED
							Local color_index:= line_view.Get(channel_position)
							
							image_buffer.PokeInt(image_position, state.palette_data[color_index])
						Case COLOR_TYPE_GRAYSCALE_ALPHA
						Case COLOR_TYPE_TRUECOLOR_ALPHA
							DebugStop()
							
							Local r:= line_view.Get(channel_position)
							Local g:= line_view.Get(channel_position+1)
							Local b:= line_view.Get(channel_position+2)
							Local a:= line_view.Get(channel_position+3)
					End
					
					image_position += pixel_stride
					channel_position += color_channels
				Next
				
				current_height += 1
			Until (input.Position >= chunk_end_position)
			
			If (advanced_errors) Then
				' The 'INF_OK' response is only valid if the inflate data-stream is continued in another contiguous IDAT chunk.
				' Error handling of neighbouring chunks is performed by higher level routines and should therefore be ignored at this level.
				If (inflate_response <> INF_DONE And inflate_response <> INF_OK) Then
					Select (inflate_response)
						Case INF_DATA_ERROR
							Throw New PNGDecodeError(Self, state, "A critical data-error occurred while decoding an IDAT chunk: Internal Error")
						Case INF_CHKSUM_ERROR
							Throw New PNGDecodeError(Self, state, "A checksum mismatch occurred while decoding an IDAT chunk: Internal Error")
						Default
							#If REGAL_PNG_SAFE
								Throw New PNGDecodeError(Self, state, "An unknown error occurred while processing an IDAT chunk.")
							#End
					End Select
				Endif
			Endif
			
			' Make sure we inflated all of the intended data:
			If (input.Position < chunk_end_position) Then
				#If REGAL_PNG_DEBUG_OUTPUT
					Print("UNABLE TO LOAD ENTIRE IDAT CHUNK { Response: " + inflate_response + " } | CURRENT: " + input.Position + " | BEGIN: " + initial_input_position + " | END: " + chunk_end_position + " |")
				#End
				
				DebugStop()
				
				Return False
			Endif
			
			Return True
		End
		
		#Rem
			This decodes a PNG chunk to the best of this implementation's ability.
			
			If decoding could not be performed ('CHUNK_RESPONSE_SKIP', 'CHUNK_RESPONSE_EXIT', etc),
			the 'input' stream's position will be in an undefined state, and should be corrected.
			
			The return-value of this command provides a response-code indicating what should be
			done about the data provided. These response codes use the prefix 'CHUNK_RESPONSE'.
			
			This routine does not process the identity and length of
			a chunk, and should therefore be passed this information.
			
			To simplify this implementation, chunk identifiers are represented as 'Strings'.
			
			The 'prev_chunk_type' argument must contain either the previous
			chunk identifier, or in the case of first-execution, an empty 'String'.
		#End
		
		Method DecodeChunk:Int(input:Stream, state:PNGDecodeState, chunk_type:String, chunk_length:Int, prev_chunk_type:String, advanced_errors:Bool=False)
			' Check if we're done processing IDAT chunks:
			If (state.image_data_found And prev_chunk_type = "IDAT" And chunk_type <> "IDAT") Then
				state.image_data_complete = True
			Endif
			
			' Supported chunk-types (Segmented by required environment):
			Select (chunk_type)
				Case "IHDR" ' Image header.
					' State safety:
					If (state.header_found) Then
						Throw New PNGDecodeError(Self, state, "Only one IHDR chunk is allowed in a PNG data-stream.")
					Endif
					
					#If REGAL_PNG_SAFE ' If (advanced_errors) Then
						' Manually check against the constant length described by the PNG specification:
						If (chunk_length <> 13) Then
							Throw New PNGDecodeError(Self, state, "IHDR chunks must be exactly 13 bytes in length.")
						Endif
					#End ' EndIf
					
					' Update the state.
					state.header_found = True
					
					' Load and check the legitimacy of the header's content.
					If (Not IHDR(input, state, header, advanced_errors)) Then
						Throw New PNGDecodeError(Self, state, "Incompatible IHDR chunk detected.")
					Endif
					
					' Debugging related:
					#If REGAL_PNG_DEBUG_OUTPUT
						Print("IHDR [ " + header.width + "x" + header.height + " | " + header.depth + "-bit ] { color-type: " + header.color_type + ", compression: " + header.compression_method + ", filter: " + header.filter_method + ", interlace: " + header.interlace_method + " }")
					#End
				Default
					' State safety:
					If (Not state.header_found) Then
						'Throw New PNGDecodeError(Self, state, "A PNG data-stream must begin with an IHDR chunk.")
						
						Return CHUNK_RESPONSE_EXIT
					Endif
					
					' Supported chunks:
					Select (chunk_type)
						Case "PLTE" ' Palette data.
							' State safety:
							If (state.palette_found) Then
								If (Not state.custom_palette) Then
									Throw New PNGDecodeError(Self, state, "Only one PLTE chunk is allowed in a PNG data-stream.")
								Else
									Return CHUNK_RESPONSE_SKIP
								Endif
							Endif
							
							If (state.image_data_found) Then
								Throw New PNGDecodeError(Self, state, "PLTE chunk detected after IDAT chunk: Internal Error")
							Endif
							
							' Initialize the 'state' object's internal palette buffer.
							' Performing this action automatically assigns 'palette_found' appropriately.
							If (Not state.InitializePaletteBuffer(chunk_length) And advanced_errors)
								Throw New PNGDecodeError(Self, state, "PLTE chunks must have lengths divisible by 3 in order to hold every required color channel: Internal Error")
							Endif
							
							' Load and check the legitimacy of the described palette data.
							PLTE(input, state, state.palette_data, advanced_errors)
						Case "IDAT" ' Image data; multiple allowed.
							' State safety:
							If (state.image_data_complete) Then
								Throw New PNGDecodeError(Self, state, "Non-consecutive IDAT chunk detected, append contents: Internal Error")
							Endif
							
							If (Not state.palette_found And header.color_type = COLOR_TYPE_INDEXED) Then
								Throw New PNGDecodeError(Self, state, "PLTE chunk not found while using '" + ColorTypeToString(header.color_type) + "' color-type: Internal Error")
							Endif
							
							If (chunk_length > 0) Then
								Local first_chunk:= (Not state.image_data_found)
								
								' Update the state.
								state.image_data_found = True
								
								If (first_chunk) Then
									' TODO: Implement multiple image output types.
									image_data = AllocateImageData(header.width, header.height)
								Endif
								
								If (Not IDAT(input, state, header, image_data, chunk_length, first_chunk, advanced_errors)) Then
									Throw New PNGDecodeError(Self, state, "Incompatible IDAT chunk detected.")
								Endif
							Endif
						Default
							' End-detection and unsupported chunks:
							Select (chunk_type)
								Case "IEND" ' End-of-file; empty content.
									#Rem
										' State safety:
										If (advanced_errors And end_found) Then
											Throw New PNGDecodeError(Self, state, "Only one IEND chunk is allowed in a PNG data-stream.")
										Endif
									#End
									
									' Update the state.
									state.end_found = True
									
									Return CHUNK_RESPONSE_EXIT
								Default ' Unsupported chunk-type.
									SeekForward(input, chunk_length)
									
									Return CHUNK_RESPONSE_SKIP
							End Select
					End Select
			End Select
			
			' Tell the user that this chunk was decoded properly.
			Return CHUNK_RESPONSE_OK
		End
		
		#Rem
			This command performs a stateful decoding pass on 'input', as well as maintaining the internal
			state and performing many safety and integrity tests to ensure both stable and secure data processing.
			
			The return-value of this command is used to indicate bootstrapping behavior.
			
			If the returned value is 'True', operations are not complete, and should be
			continued by another call to this command at the user's discretion.
			
			If 'False', the PNG data-stream has been decoded. To build and retrieve correctly
			formatted image-data, please use an official access method.
			
			The 'advanced_errors' argument allows for detailed error checking of data validity.
			
			The 'integrity_checks' argument incurs significant overhead by ensuring the
			embeded CRC32 checksums match their corresponding data-segments.
			
			The 'fail_on_bad_integrity' argument is currently used for debugging purposes.
		#End
		
		Method Decode:Bool(input:Stream, state:PNGDecodeState, advanced_errors:Bool=False, integrity_checks:Bool=False, fail_on_bad_integrity:Bool=True)
			' If the state already reports the end of the stream, don't bother continuing:
			If (state.end_found) Then
				Return False
			Endif
			
			'DebugStop()
			
			' Retrieve the previous known chunk-type.
			Local prev_chunk_type:= state.ChunkName
			
			' Retrieve a new chunk length and type:
			Local chunk_length:= state.ReadChunkHeader(input)
			Local chunk_type:= state.ChunkName ' state.ChunkType
			
			Local chunk_begin:= input.Position
			
			' Check if integrity should be preserved:
			If (integrity_checks) Then
				' Verify the integrity of this chunk, and if 'fail_on_bad_integrity' is enabled, throw exceptions on mismatches:
				If (Not VerifyChunkIntegrity(input, chunk_begin, chunk_length, Not fail_on_bad_integrity) And fail_on_bad_integrity) Then
					Throw New PNGDecodeError(Self, state, "CRC checksum mismatch detected: file-integrity compromised {" + chunk_type + "}")
				Endif
			Endif
			
			#If REGAL_PNG_DEBUG_OUTPUT
				Print("PNG CHUNK {Type: " + chunk_type + ", Length: " + chunk_length + "} | BEGIN: " + chunk_begin + " | END: " + (chunk_begin + chunk_length) + " |")
			#End
			
			' Process a chunk from the data-stream.
			Local chunk_response:= DecodeChunk(input, state, chunk_type, chunk_length, prev_chunk_type, advanced_errors)
			
			' Until marked later, chunks are assumed to be decoded properly.
			Local chunk_skipped:Bool = (chunk_response = CHUNK_RESPONSE_SKIP)
			
			' Skip white-space as required to continue working with the data-stream:
			#If REGAL_PNG_SAFE_CHUNKS
				SkipChunkData(input, chunk_begin, chunk_length, True, Not chunk_skipped)
			#Else
				If (chunk_skipped) Then
					SkipChunkData(input, chunk_begin, chunk_length)
				Endif
			#End
			
			' Skip the CRC checksum of this chunk. (Checked optionally; see above)
			SkipChunkChecksum(input)
			
			' This reports 'True' if the data-stream was ended. (Soft error-checking, state enforcement, EOF, etc)
			Local end_of_stream:= ((chunk_response = CHUNK_RESPONSE_EXIT) Or state.end_found Or input.Eof())
			
			If (end_of_stream) Then
				' End-state error handling:
				If (Not state.header_found) Then
					Throw New PNGDecodeError(Self, state, "Unable to locate an IHDR chunk.")
				Endif
				
				If (Not state.image_data_found) Then
					Throw New PNGDecodeError(Self, state, "Unable to locate IDAT chunk(s).")
				Else
					' This condition is very unlikely, but still possible:
					If (Not state.image_data_complete) Then
						Throw New PNGDecodeError(Self, state, "Failed to build consecutive IDAT stream.")
					Endif
				Endif
				
				If (Not state.end_found) Then
					Throw New PNGDecodeError(Self, state, "Unable to locate an IEND chunk.")
				Endif
				
				If (Not state.palette_found And header.color_type = COLOR_TYPE_INDEXED) Then
					Throw New PNGDecodeError(Self, state, "PLTE chunk not found; a palette is required for color-type: '" + ColorTypeToString(COLOR_TYPE_INDEXED) + "'") ' header.color_type
				Endif
				
				' If this point is reached, the data-stream has ended successfully.
				Return False
			Endif
			
			' Tell the user to continue decoding the data-stream.
			Return True
		End
		
		' Properties:
		
		' This represents the current header data.
		' If a header has yet to be provided, this
		' will supply a default-initialized object.
		Method Header:PNGHeader() Property
			Return Self.header
		End
		
		#Rem
			This represents the internal image data.
			This will return 'Null' if a buffer isn't available.
			
			If an object is provided, its contents are undefined
			until all critical operations are complete (Decoding, etc).
		#End
		
		Method ImageData:DataBuffer() Property
			Return Self.image_data
		End
		
		' This specifies the internal image-buffer's color-layout.
		' This functionality is currently unfinished.
		Method ImageType:Int() Property
			Return IMAGE_TYPE_RGBA
		End
		
		' This specifies the stride for the current 'ImageType'.
		' This functionality is currently unfinished.
		Method PixelStride:Int() Property
			Return 4
		End
	Private
		' Functions:
		
		' This reports a boolean value, but does not handle seek-semantics.
		' Please use the 'VerifyPNG' command instead.
		Function _VerifyPNG_Impl:Bool(input:Stream, __length_check:Bool=False)
			' Constant variable(s):
			Const PNG_SIGNATURE_LENGTH:= 8
			
			If ((input.Length - input.Position) < PNG_SIGNATURE_LENGTH) Then
				Return False
			Endif
			
			' Fast version:
			'#Rem
			SeekForward(input, 1) ' Reserved
			
			If (input.ReadByte() <> ASCII_P Or input.ReadByte() <> ASCII_N Or input.ReadByte() <> ASCII_G) Then
			'If (input.ReadString(3, "ascii") <> "PNG") Then ' SeekForward(input, 3) ' PNG
				Return False
			Endif
			
			SeekForward(input, 2+1+1) ' Line-ending
			'#End
			
			Return True
		End
		
		' Constructor(s):
		Method New()
			' Empty implementation; reserved.
		End
		
		' Methods:
		Method _dbg_init:Void(stream:Stream) Final
			#If REGAL_PNG_DEBUG_STREAMS
				Self._dbg_stream = stream
			#End
		End
End