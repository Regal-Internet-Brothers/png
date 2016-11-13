Strict

Public

' Imports (Public):
Import config

' Imports (Private):
Private

Import util

Import regal.sizeof
Import regal.byteorder

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
		
		Method New(data:DataBuffer, channels:Int, depth:Int)
			Self.data = data
			Self.channels = channels
			Self.depth = depth
		End
		
		' Methods:
		Method Get:Int(index:Int)
			Local address:= IndexToAddress(index)
			Local channel:= IndexToChannel(index)
			
			Return ((GetRaw(address, DepthInBytes) Shr (channel * BitsPerChannel)) & BitMask)
		End
		
		Method Set:Void(index:Int, value:Int)
			'DebugStop()
			
			Local address:= IndexToAddress(index)
			Local channel:= IndexToChannel(index)
			
			Local depth_in_bytes:= DepthInBytes
			
			Local current_value:= GetRaw(address, depth_in_bytes)
			
			Local out_value:= ((value & BitMask) Shl (channel * BitsPerChannel))
			
			SetRaw(address, depth_in_bytes, (current_value | out_value))
		End
		
		' This reads a raw value of size 'value_size' bytes from 'address'.
		' This is used internally to handle memory-mapping.
		Method GetRaw:Int(address:Int, value_size:Int)
			Select (value_size)
				Case 1
					Return data.PeekByte(address)
				Case 2
					Return data.PeekShort(address)
				Case 3
					Local value:Int
					
					' Read 3 bytes into a 32-bit integer:
					value = (data.PeekByte(address + SizeOf_Short) & $FF)
					value Shl= 16
					value |= (data.PeekShort(address) & $FFFF)
				Case 4
					Return data.PeekInt(address)
			End Select
			
			Return 0
		End
		
		' This writes a raw value of size 'value_size' bytes to 'address'.
		' This is used internally to handle memory-mapping.
		Method SetRaw:Void(address:Int, value_size:Int, value:Int)
			Select (value_size)
				Case 1
					data.PokeByte(address, value)
				Case 2
					data.PokeShort(address, value)
				Case 3
					Local a:= (value & $FFFF)
					Local b:= ((value Shr 16) & $FF)
					
					data.PokeShort(address, a)
					data.PokeByte((address + SizeOf_Short), b)
				Case 4
					data.PokeInt(address, value)
			End Select
		End
		
		' This retrieves the raw value of the color entry specified.
		' For details, see 'Poke'.
		Method Peek:Int(entry_index:Int) Final
			Return GetRaw(IndexToAddress(entry_index), DepthInBytes)
		End
		
		' This manually assigns a raw value to a color entry.
		' Color entries are 'DepthInBytes' sized collections of color channels,
		' which therefore affect multiple channels when modified.
		' To manage individual channels by their exact indices, use 'Set' and 'Get'.
		Method Poke:Void(entry_index:Int, value:Int) Final
			SetRaw(IndexToAddress(entry_index), DepthInBytes, value)
		End
		
		' This converts an index to an aligned memory address.
		' Essentially, the output is the first byte allocated
		' to the mapped color channel and its first index.
		' This is mostly useful for internal functionality, and may be disregarded.
		Method IndexToAddress:Int(index:Int)
			Return ((index / channels) * DepthInBytes)
		End
		
		' This converts a global index used for contiguous data-access to
		' a local channel index used for bitwise manipulation.
		Method IndexToChannel:Int(index:Int)
			Return (index Mod channels)
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
		
		' This specifies the minimum number of bytes required to store 'Depth'.
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
			
			Return (Pow(2, bits_per_channel) - 1)
		End
	Protected
		' Fields:
		Field data:DataBuffer
		
		Field channels:Int
		Field depth:Int
End