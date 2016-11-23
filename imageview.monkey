Strict

Public

' Imports (Public):
Import config

' Imports (Private):
Private

Import util

Import regal.sizeof
Import regal.byteorder
Import regal.util.math

Public

' This maps a 'DataBuffer' to bit-length color entries based on the available channels and color-depth.
' Regular indices wrap to the next color entry; for example, 24-bit RGB at index 3 will begin at the second color entry.
Class ImageView
	Public
		' Constructor(s):
		
		#Rem
			The 'data' argument should be at least as long as the number of
			bytes required to store one pixel of 'depth' size.
			
			The 'channels' argument specifies how many
			divisions of 'depth' will be available per-pixel.
			
			The 'depth' argument specifies how many bits are allocated to each pixel.
			
			The maximum number of bits allowed per-channel is 32, with a maximum depth of: (32 * channels)
			
			For example, this means a view with 4 channels cannot exceed a depth of 128 (4*32),
			as that would require integer types larger than 32-bit.
		#End
		
		Method New(data:DataBuffer, channels:Int, depth:Int, offset:Int=0)
			Self.data = data
			Self.channels = channels
			Self.depth = depth
			Self.offset = offset
		End
		
		' Methods:
		Method Get:Int(index:Int, big_endian:Bool=False)
			Local address:= IndexToAddress(index)
			Local channel:= IndexToChannel(index)
			
			'DebugStop()
			
			Local depth_in_bytes:= DepthInBytes
			Local bytes_per_channel:= BytesPerChannel
			Local channel_stride:= BitsPerChannel ' bytes_per_channel * 8
			
			If (bytes_per_channel >= SizeOf_Integer) Then ' =
				address += (channel * bytes_per_channel) ' SizeOf_Integer
				
				channel_stride = 0
			Endif
			
			Local value_size:Int
			
			If (depth_in_bytes > 4) Then
				value_size = bytes_per_channel
			Else
				value_size = depth_in_bytes
			Endif
			
			Local raw:= GetRaw(address, value_size, big_endian)
			
			If (BitsPerChannel = 1) Then
				raw = ReverseByte(raw)
				
				Return (raw Shr channel) & 1
			Endif
			
			Local bmsk:= BitMask
			Local out:= (raw Shr (channel * channel_stride)) & bmsk
			
			Return out
		End
		
		Method Set:Void(index:Int, value:Int, big_endian:Bool=False)
			Local address:= IndexToAddress(index)
			Local channel:= IndexToChannel(index)
			
			Local depth_in_bytes:= DepthInBytes
			Local bytes_per_channel:= BytesPerChannel
			Local channel_stride:= BitsPerChannel ' bytes_per_channel * 8
			
			If (bytes_per_channel >= SizeOf_Integer) Then ' =
				address += (channel * bytes_per_channel) ' SizeOf_Integer
				
				channel_stride = 0
			Endif
			
			Local value_size:Int
			
			If (depth_in_bytes > 4) Then
				value_size = bytes_per_channel
			Else
				value_size = depth_in_bytes
			Endif
			
			Local out_value:Int
			
			Local is_encapsulated:= ((channels = 1) And (value_size = depth_in_bytes))
			
			If (Not is_encapsulated) Then
				Local current_value:= GetRaw(address, value_size, big_endian)
				
				out_value = (Lsl((value & BitMask), (channel * channel_stride)) | current_value)
			Else
				out_value = value
			Endif
			
			SetRaw(address, value_size, out_value, big_endian)
		End
		
		' This reads a raw value of size 'value_size' bytes from 'address'.
		' This is used internally to handle memory-mapping.
		Method GetRaw:Int(address:Int, value_size:Int, big_endian:Bool=False)
			Local offset_address:= (address + offset)
			
			' Make sure this address is valid, and if not, return zero:
			If (offset_address < 0) Then
				Return 0
			Endif
			
			Select (value_size)
				Case 1
					Return data.PeekByte(offset_address)
				Case 2
					Local value:= data.PeekShort(offset_address)
					
					If (big_endian) Then
						Return NToHS(value)
					Endif
					
					Return value
				Case 3
					If (big_endian) Then
						Local a:= (data.PeekByte(offset_address) & $FF)
						Local b:= (data.PeekByte((offset_address + 1)) & $FF)
						Local c:= (data.PeekByte((offset_address + 2)) & $FF)
						
						Return (c | (b Shl 8) | (a Shl 16))
					Else
						Local value:Int
						
						' Read 3 bytes into a 32-bit integer:
						value = (data.PeekByte(offset_address + SizeOf_Short) & $FF)
						value Shl= 16
						value |= (data.PeekShort(offset_address) & $FFFF)
						
						Return value
					Endif
				Case 4
					Local value:= data.PeekInt(offset_address)
					
					If (big_endian) Then
						Return NToHL(value)
					Endif
					
					Return value
			End Select
			
			Return 0
		End
		
		' This writes a raw value of size 'value_size' bytes to 'address'.
		' This is used internally to handle memory-mapping.
		Method SetRaw:Void(address:Int, value_size:Int, value:Int, big_endian:Bool=False)
			Local offset_address:= (address + offset)
			
			' Make sure this address is valid:
			If (offset_address < 0) Then
				Return
			Endif
			
			Select (value_size)
				Case 1
					data.PokeByte(offset_address, value)
				Case 2
					If (big_endian) Then
						value = HToNS(value)
					Endif
					
					data.PokeShort(offset_address, value)
				Case 3
					If (big_endian) Then
						Local a:= ((value Shr 16) & $FF)
						Local b:= ((value Shr 8) & $FF)
						Local c:= (value & $FF)
						
						data.PokeByte(offset_address, a)
						data.PokeByte((offset_address + 1), b)
						data.PokeByte((offset_address + 2), c)
					Else
						Local a:= (value & $FFFF)
						Local b:= ((value Shr 16) & $FF)
						
						data.PokeShort(offset_address, a)
						data.PokeByte((offset_address + SizeOf_Short), b)
					Endif
				Case 4
					If (big_endian) Then
						value = HToNL(value)
					Endif
					
					data.PokeInt(offset_address, value)
			End Select
		End
		
		' This retrieves the raw value of the color entry specified.
		' For details, see 'Poke'.
		Method Peek:Int(entry_index:Int, big_endian:Bool=False) Final
			Return GetRaw(IndexToAddress(entry_index), DepthInBytes, big_endian)
		End
		
		' This manually assigns a raw value to a color entry.
		' Color entries are 'DepthInBytes' sized collections of color channels,
		' which therefore affect multiple channels when modified.
		' To manage individual channels by their exact indices, use 'Set' and 'Get'.
		Method Poke:Void(entry_index:Int, value:Int, big_endian:Bool=False) Final
			SetRaw(IndexToAddress(entry_index), DepthInBytes, value, big_endian)
		End
		
		' This converts an index to an aligned memory address.
		' Essentially, the output is the first byte allocated
		' to the mapped color channel and its first index.
		' This is mostly useful for internal functionality, and may be disregarded.
		Method IndexToAddress:Int(index:Int)
			Local offset:Int
			
			If (index = 0) Then
				Return 0
			Elseif (index > 0) Then
				offset = (index / channels)
			Else
				offset = ((index - (channels - 1)) / channels)
			Endif
			
			Local bits_per_channel:= BitsPerChannel
			
			If (bits_per_channel < 8) Then
				Return ((offset * bits_per_channel) / 8)
			Endif
			
			Return (offset * DepthInBytes)
		End
		
		' This converts a global index used for contiguous data-access to
		' a local channel index used for bitwise manipulation.
		Method IndexToChannel:Int(index:Int)
			Local channels:Int
			
			Local bits_per_channel:= BitsPerChannel
			
			If (bits_per_channel < 8) Then
				channels = (8 / bits_per_channel)
			Else
				channels = Self.channels
			Endif
			
			If (index = 0) Then
				Return 0
			Elseif (index > 0) Then
				Return (index Mod channels)
			Else
				Local i:= index
				
				While (i < 0)
					i += channels
				Wend
				
				Return i
			Endif
		End
		
		' Properties:
		
		' This returns a reference to the buffer this view is mapping into color data.
		Method Data:DataBuffer() Property
			Return Self.data
		End
		
		' This specifies how many color channels are mapped in this view.
		Method Channels:Int() Property
			Return Self.channels
		End
		
		' This specifies how many bits are mapped to each pixel.
		Method Depth:Int() Property
			Return Self.depth
		End
		
		' This specifies the starting point of this view in 'Data'.
		Method Offset:Int() Property
			Return Self.offset
		End
		
		' This property allows modification of the starting point of this view.
		' Modifying this property does not yield changes to
		' the contents of 'Data', only its representation.
		Method Offset:Void(value:Int) Property
			Self.offset = Max(value, 0)
		End
		
		' This specifies the minimum number of bytes required to store 'Depth'.
		' In other words, this specifies how many bytes are required to store a pixel.
		Method DepthInBytes:Int() Property
			Return BitDepthInBytes(Depth)
		End
		
		' This specifies how many bits are available in each color channel.
		Method BitsPerChannel:Int() Property
			Return (Self.depth / Self.channels)
		End
		
		' This specifies the minimum number of bytes required to store a color channel.
		Method BytesPerChannel:Int() Property
			Return BitDepthInBytes(BitsPerChannel)
		End
		
		' This provides the bit-mask used to restrict color channels' values for I/O.
		Method BitMask:Int() Property
			Local bits_per_channel:= BitsPerChannel
			
			If (bits_per_channel >= 32) Then
				Return $FFFFFFFF
			Endif
			
			Return (Int(Pow(2, bits_per_channel)) - 1)
		End
	Protected
		' Fields:
		Field data:DataBuffer
		
		Field channels:Int
		Field depth:Int
		Field offset:Int
End