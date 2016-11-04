Strict

Public

' Preprocessor related:
#REGAL_PNG_DEBUG_OUTPUT = True

' Imports:
Import brl.filestream

Import regal.png
Import regal.ioutil.endianstream

Import mojo2

' Classes:
Class Application Extends App
	Method OnCreate:Int()
		SetUpdateRate(0)
		
		graphics = New Canvas(Null)
		
		Try
			Local file_path:= "monkey://data/test.png"
			
			Local file:= New EndianStreamManager<FileStream>(FileStream.Open(file_path, "r"), True)
			
			Local png_file:PNG
			
			Local position:= file.Position
			
			Try
				Local state:= New PNGDecodeState()
				
				png_file = PNG.Load(file)
				
				While (Not file.Eof())
					If (Not png_file.Decode(file, state, True, True)) Then
						Exit
					Endif
					
					Print("|PASS COMPLETE|")
				Wend
			Catch png_error:PNGException
				Error(png_error.ToString())
			End Try
			
			file.Close()
			
			Local header:= png_file.Header
			
			Local width:= header.width
			Local height:= header.height
			
			Local imageData:DataBuffer
			
			image = New Image(width, height, 0.5, 0.5, Image.Managed)
			
			'image.WritePixels(0, 0, width, height, imageData)
			
			'HideMouse()
		Catch E:StreamError
			Error(E)
			
			Throw E
		End Try
		
		Return 0
	End
	
	Method OnUpdate:Int()
		If (KeyHit(KEY_ESCAPE)) Then
			Return OnClose()
		Endif
		
		Return 0
	End
	
	Method OnRender:Int()
		graphics.Clear(1.0, 0.0, 0.0)
		
		Local x:= (DeviceWidth() / 2) ' MouseX()
		Local y:= (DeviceHeight() / 2) ' MouseY()
		
		'graphics.DrawImage(image, x, y, 0.0, 3.0, 3.0)
		graphics.DrawImage(image, x, y)
		
		graphics.Flush()
		
		Return 0
	End
	
	Method OnResize:Int()
		Local devWidth:= DeviceWidth()
		Local devHeight:= DeviceHeight()
		
		graphics.SetViewport(0, 0, devWidth, devHeight)
		graphics.SetProjection2d(0, devWidth, 0, devHeight)
		
		Return Super.OnResize()
	End
	
	Field graphics:Canvas
	
	Field image:Image
End

' Functions:
Function Main:Int()
	New Application()
	
	Return 0
End