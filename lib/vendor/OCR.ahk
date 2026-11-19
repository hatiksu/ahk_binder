#Requires AutoHotkey v2

class OCR {
    static Version => "2.0.0"
    static IID_IRandomAccessStream := "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}"
         , IID_IPicture            := "{7BF80980-BF32-101A-8BBB-00AA00300CAB}"
         , IID_IAsyncInfo          := "{00000036-0000-0000-C000-000000000046}"
         , IID_IAsyncOperation_OcrResult        := "{c7d7118e-ae36-59c0-ac76-7badee711c8b}"
         , IID_IAsyncOperation_SoftwareBitmap   := "{c4a10980-714b-5501-8da2-dbdacce70f73}"
         , IID_IAsyncOperation_BitmapDecoder    := "{aa94d8e9-caef-53f6-823d-91b6e8340510}"
         , IID_IAsyncOperationCompletedHandler_OcrResult        := "{989c1371-444a-5e7e-b197-9eaaf9d2829a}"
         , IID_IAsyncOperationCompletedHandler_SoftwareBitmap   := "{b699b653-33ed-5e2d-a75f-02bf90e32619}"
         , IID_IAsyncOperationCompletedHandler_BitmapDecoder    := "{bb6514f2-3cfb-566f-82bc-60aabd302d53}"
         , IID_IPdfDocumentStatics := "{433A0B5F-C007-4788-90F2-08143D922599}"
         , Vtbl_GetDecoder := {bmp:6, jpg:7, jpeg:7, png:8, tiff:9, gif:10, jpegxr:11, ico:12}
         , PerformanceMode := 0
         , DisplayImage := 0

    class IBase {
        __OCR := OCR
        __New(ptr?) {
            if IsSet(ptr) {
                if !ptr
                    throw ValueError('Invalid IUnknown interface pointer', -2, this.__Class)
                else if IsObject(ptr) {
                    if ptr.HasProp("Relative")
                        this.DefineProp("Relative", {value: ptr.Relative})
                    ptr := 0
                }
            }
            this.DefineProp("ptr", {Value:ptr ?? 0})
        }
        __Delete() => this.ptr ? ObjRelease(this.ptr) : 0
    }

    static __New() {
        this.LanguageFactory := this.CreateClass("Windows.Globalization.Language", ILanguageFactory := "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")
        this.SoftwareBitmapFactory := this.CreateClass("Windows.Graphics.Imaging.SoftwareBitmap", "{c99feb69-2d62-4d47-a6b3-4fdb6a07fdf8}")
        this.BitmapTransform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")
        this.BitmapDecoderStatics := this.CreateClass("Windows.Graphics.Imaging.BitmapDecoder", IBitmapDecoderStatics := "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}")
        this.BitmapEncoderStatics := this.CreateClass("Windows.Graphics.Imaging.BitmapEncoder", IBitmapDecoderStatics := "{a74356a7-a4e4-4eb9-8e40-564de7e1ccb2}")
        this.SoftwareBitmapStatics := this.CreateClass("Windows.Graphics.Imaging.SoftwareBitmap", ISoftwareBitmapStatics := "{df0385db-672f-4a9d-806e-c2442f343e86}")
        this.OcrEngineStatics := this.CreateClass("Windows.Media.Ocr.OcrEngine", IOcrEngineStatics := "{5BFFA85A-3384-3540-9940-699120D428A8}")
        ComCall(6, this.OcrEngineStatics, "uint*", &MaxImageDimension:=0)
        this.MaxImageDimension := MaxImageDimension
        DllCall("Dwmapi\DwmIsCompositionEnabled", "Int*", &compositionEnabled:=0)
        this.CAPTUREBLT := compositionEnabled ? 0 : 0x40000000
        this.GrayScaleMCode := this.MCode((A_PtrSize = 4) 
        ? "2,x86:VVdWU4PsCIt8JCiLdCQki0QkIMHvAg+v94k0JIX2dH+FwHR7jTS9AAAAAIl0JASLdCQcjRyGMfaNtCYAAAAAkItEJByNDLCNtCYAAAAAZpCLEYPBBInQD7buwegQae1OAgAAD7bAacAsAQAAAegPtuqB4gAAAP9r7W4B6MHoConFCcLB4AjB5RAJ6gnQiUH8Odl1vAH+A1wkBDs0JHKhg8QIMcBbXl9dww==" 
        : "2,x64:V1ZTQcHpAkSJxkiJy0GJ00EPr/GF9nRnRTHAhdJ0YJBEicEPH0QAAInIg8EBTI0Ug0GLEonQD7b+wegQaf9OAgAAD7bAacAsAQAAAfgPtvqB4gAAAP9r/24B+MHoConHCcLB4AjB5xAJ+gnCQYkSRDnZdbRFAchFActBOfByoTHAW15fww==")
        this.InvertColorsMCode := this.MCode((A_PtrSize = 4)
        ? "2,x86:VVdWU4PsCItsJCiLfCQki0QkIMHtAg+v/Yk8JIX/dGeFwHRjjTytAAAAAIl8JASLfCQcjTSHMf+NtCYAAAAAkItEJByNDLiNtCYAAAAAZpCLEYPBBInQidOB4v8AAP/30PfTgPL/JQAA/wCB4wD/AAAJ2AnQiUH8OfF11AHvA3QkBDs8JHK5g8QIMcBbXl9dww=="
        : "2,x64:V1ZTQcHpAkSJx0iJzonTQQ+v+YX/dFNFMcCF0nRMZpBEicEPH0QAAInIg8EBTI0chkGLE4nQQYnSgeL/AAD/99BB99KA8v8lAAD/AEGB4gD/AABECdAJ0EGJAznLdclFAchEActBOfhytjHAW15fww==")
        this.MonochromeMCode := this.MCode((A_PtrSize = 4)
        ? "2,x86:VVdWU4PsDIt0JCyLTCQoi0QkJIt8JDDB7gIPr86JNCSJTCQEhcl0aYXAdGXB5gIx7Yl0JAiLdCQgjTSGjXQmAItEJCCNDKiNtCYAAAAAZpCLEYnTD7bGD7bSwesQacCWAAAAD7bba9Ida9tNAdgB0MHoCDn4dinHAf////+DwQQ58XXMAywkA3QkCDlsJAR3r4PEDDHAW15fXcONdCYAkMcBAAAA/4PBBDnxdaMDLCQDdCQIOWwkBHeG69U="
        : "2,x64:VVdWU4t0JEhBwekCRInHSInLQYnTQQ+v+YX/dFyF0nRYRTHADx9AAESJwQ8fRAAAichMjRSDQYsSidUPtsYPttLB7RBpwJYAAABAD7bta9Ida+1NAegB0MHoCDnwdiGDwQFBxwL/////QTnLdcJFAchFActEOcd3rzHAW15fXcODwQFBxwIAAAD/RDnZdaFFAchFActEOcd3juvd")
    }

    static Call(RandomAccessStreamOrSoftwareBitmap, Options:=0) {
        local SoftwareBitmap := 0, RandomAccessStream := 0, lang:="FirstFromAvailableLanguages", width, height, x := 0, y := 0, w := 0, h := 0, scale, grayscale, invertcolors, monochrome, OcrResult := this.Result(), Result, transform := 0, decoder := 0
        this.__ExtractTransformParameters(Options, &transform)
        scale := transform.scale, grayscale := transform.grayscale, invertcolors := transform.invertcolors, monochrome := transform.monochrome, rotate := transform.rotate, flip := transform.flip
        this.__ExtractNamedParameters(Options, "x", &x, "y", &y, "w", &w, "h", &h, "language", &lang, "lang", &lang, "decoder", &decoder)
        this.LoadLanguage(lang)
        local customRegion := x || y || w || h

        try SoftwareBitmap := ComObjQuery(RandomAccessStreamOrSoftwareBitmap, "{689e0708-7eef-483f-963f-da938818e073}")
        if SoftwareBitmap {
            ComCall(8, SoftwareBitmap, "uint*", &width:=0)
            ComCall(9, SoftwareBitmap, "uint*", &height:=0)
            this.ImageWidth := width, this.ImageHeight := height
            if (Floor(width*scale) > this.MaxImageDimension) or (Floor(height*scale) > this.MaxImageDimension)
               throw ValueError("Image is too big - " width "x" height ".`nIt should be maximum - " this.MaxImageDimension " pixels (with scale applied)")
            if scale != 1 || customRegion || rotate || flip
                SoftwareBitmap := this.TransformSoftwareBitmap(SoftwareBitmap, &width, &height, scale, rotate, flip, x?, y?, w?, h?)
            goto SoftwareBitmapCommon
        }
        RandomAccessStream := RandomAccessStreamOrSoftwareBitmap

        if decoder {
            ComCall(this.Vtbl_GetDecoder.%decoder%, this.BitmapDecoderStatics, "ptr", DecoderGUID:=Buffer(16))
            ComCall(15, this.BitmapDecoderStatics, "ptr", DecoderGUID, "ptr", RandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        } else
            ComCall(14, this.BitmapDecoderStatics, "ptr", RandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
            this.WaitForAsync(&BitmapDecoder)

        BitmapFrame := ComObjQuery(BitmapDecoder, IBitmapFrame := "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
        ComCall(12, BitmapFrame, "uint*", &width:=0)
        ComCall(13, BitmapFrame, "uint*", &height:=0)
        if (width > this.MaxImageDimension) or (height > this.MaxImageDimension)
           throw ValueError("Image is too big - " width "x" height ".`nIt should be maximum - " this.MaxImageDimension " pixels")

        BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, IBitmapFrameWithSoftwareBitmap := "{FE287C9A-420C-4963-87AD-691436E08383}")
        OcrResult.ImageWidth := width, OcrResult.ImageHeight := height
        if !(customRegion || rotate || flip) && (width < 40 || height < 40 || scale != 1) {
            scale := scale = 1 ? 40.0 / Min(width, height) : scale
            ComCall(7, this.BitmapTransform, "int", width := Floor(width*scale))
            ComCall(9, this.BitmapTransform, "int", height := Floor(height*scale))
            ComCall(8, BitmapFrame, "uint*", &BitmapPixelFormat:=0)
            ComCall(9, BitmapFrame, "uint*", &BitmapAlphaMode:=0)
            ComCall(8, BitmapFrameWithSoftwareBitmap, "uint", BitmapPixelFormat, "uint", BitmapAlphaMode, "ptr", this.BitmapTransform, "uint", IgnoreExifOrientation := 0, "uint", DoNotColorManage := 0, "ptr*", SoftwareBitmap:=this.IBase())
        } else {
            ComCall(6, BitmapFrameWithSoftwareBitmap, "ptr*", SoftwareBitmap:=this.IBase())
        }
        this.WaitForAsync(&SoftwareBitmap)
        if customRegion || rotate || flip || scale != 1
            SoftwareBitmap := this.TransformSoftwareBitmap(SoftwareBitmap, &width, &height, scale, rotate, flip, x?, y?, w?, h?)

        SoftwareBitmapCommon:

        if (grayscale || invertcolors || monochrome || this.DisplayImage) {
            ComCall(15, SoftwareBitmap, "int", 2, "ptr*", &BitmapBuffer := 0)
            MemoryBuffer := ComObjQuery(BitmapBuffer, "{fbc4dd2a-245b-11e4-af98-689423260cf8}")
            ComCall(6, MemoryBuffer, "ptr*", &MemoryBufferReference := 0)
            BufferByteAccess := ComObjQuery(MemoryBufferReference, "{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
            ComCall(3, BufferByteAccess, "ptr*", &SoftwareBitmapByteBuffer:=0, "uint*", &BufferSize:=0)
           
            if grayscale
                DllCall(this.GrayScaleMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "cdecl uint")

            if monochrome
                DllCall(this.MonochromeMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "uint", monochrome, "cdecl uint")
            
            if invertcolors
                DllCall(this.InvertColorsMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "cdecl uint")
    
            if this.DisplayImage {
                local hdc := DllCall("GetDC", "ptr", 0, "ptr"), bi := Buffer(40, 0), hbm
                NumPut("uint", 40, "int", width, "int", -height, "ushort", 1, "ushort", 32, bi)
                hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &ppvBits:=0, "ptr", 0, "uint", 0, "ptr")
                DllCall("ntdll\memcpy", "ptr", ppvBits, "ptr", SoftwareBitmapByteBuffer, "uint", BufferSize, "cdecl")
                DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc, "Int")
                this.DisplayHBitmap(hbm)
            }
            
            BufferByteAccess := "", ObjRelease(MemoryBufferReference), MemoryBuffer := "", ObjRelease(BitmapBuffer)
        }

        ComCall(6, this.OcrEngine, "ptr", SoftwareBitmap, "ptr*", Result:=ComValue(13,0))
        this.WaitForAsync(&Result)
        OcrResult.Ptr := Result.Ptr, ObjAddRef(OcrResult.ptr)

        if RandomAccessStream is this.IBase
            this.CloseIClosable(RandomAccessStream)
        if SoftwareBitmap is this.IBase
            this.CloseIClosable(SoftwareBitmap)

        if scale != 1 || x != 0 || y != 0
            this.NormalizeCoordinates(OcrResult, scale, x, y)

        return OcrResult
    }

    static ClearAllHighlights() => this.Result.Prototype.Highlight("clearall")

    class Result extends OCR.Common {
        Text {
            get {
                ComCall(8, this, "ptr*", &hAllText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hAllText, "uint*", &length:=0, "ptr")
                this.DefineProp("Text", {Value:StrGet(buf, "UTF-16")})
                this.__OCR.DeleteHString(hAllText)
                return this.Text
            }
        }

        TextAngle {
            get => (ComCall(7, this, "double*", &value:=0), value)
        }

        Lines {
            get {
                ComCall(6, this, "ptr*", LinesList:=ComValue(13, 0))
                ComCall(7, LinesList, "int*", &count:=0)
                lines := []
                loop count {
                    ComCall(6, LinesList, "int", A_Index-1, "ptr*", Line:=this.__OCR.Line(this)) 
                    lines.Push(Line)
                }
                this.DefineProp("Lines", {Value:lines})
                return lines
            }
        }

        Words {
            get {
                local words := [], line, word
                for line in this.Lines
                    for word in line.Words
                        words.Push(word)
                this.DefineProp("Words", {Value:words})
                return words
            }
        }

        BoundingRect {
            get => this.DefineProp("BoundingRect", {Value:this.__OCR.WordsBoundingRect(this.Words*)}).BoundingRect
        }

        FindString(Needle, Options := "") => this.__FindString(Needle, Options, 0)

        FindStrings(Needle, Options := "") => this.__FindString(Needle, Options, true)

        __FindString(Needle, Options, All) {
            local CaseSense := false, IgnoreLinebreaks := false, AllowOverlap := false, i := 1, SearchFunc, x, y, w, h
            local currentHaystack, fullHaystackLinebreaks := "`n", offset := 0, line, counter := 0, x1, y1, x2, y2, result, results := [], word

            if !(Needle is String)
                throw TypeError("Needle is required to be a string, not type " Type(Needle), -1)
            if Trim(Needle, " `t`n`r") == ""
                throw ValueError("Needle cannot be an empty string", -1)

            this.__OCR.__ExtractNamedParameters(Options, "CaseSense", &CaseSense, "IgnoreLinebreaks", &IgnoreLinebreaks, "AllowOverlap", &AllowOverlap, "i", &i, "SearchFunc", &SearchFunc, "x", &x, "y", &y, "w", &w, "h", &h)

            if !IsSet(SearchFunc)
                SearchFunc := (haystack, needle, &foundstr) => (pos := InStr(haystack, needle, casesense), foundstr := SubStr(haystack, pos, StrLen(needle)), pos)

            if (IsSet(x) || IsSet(y) || IsSet(w) || IsSet(h)) {
                x1 := x ?? -100000, y1 := y ?? -100000, x2 := IsSet(w) ? x + w : 100000, y2 := IsSet(h) ? y + h : 100000 
            }

            tokenizedHaystack := [IgnoreLinebreaks ? " " : "`n"]
            for Line in this.Lines {
                fullHaystackLinebreaks .= line.Text "`n"
                for Word in Line.Words
                    tokenizedHaystack.Push(Word, " ")
                tokenizedHaystack.Pop()
                tokenizedHaystack.Push(IgnoreLinebreaks ? " " : "`n")
            }

            fullHaystackNoLinebreaks := StrReplace(fullHaystackLinebreaks, "`n", " ")
            fullHaystack := IgnoreLinebreaks ? fullHaystackNoLinebreaks : fullHaystackLinebreaks

            Needle := RegExReplace(StrReplace(Needle, "`t", " "), " +", " ")

            fullFirst := SubStr(Needle, 1, 1) ~= "[ \n]", fullLast := SubStr(Needle, -1, 1) ~= "[ \n]"

            currentHaystack := fullHaystack
            Loop {
                if !(loc := SearchFunc(currentHaystack, Needle, &foundNeedle))
                    break

                if IsObject(foundNeedle)
                    foundNeedle := foundNeedle[]

                foundLen := AllowOverlap ? 1 : StrLen(foundNeedle)
                currentHaystack := SubStr(currentHaystack, loc + foundLen)
                offset += loc + foundLen - 1

                if ++counter < i
                    continue

                tokenizedNeedle := []
                for wsNeedle in wsSplit := StrSplit(foundNeedle, " ") {
                    for lbNeedle in lbSplit := StrSplit(wsNeedle, "`n") {
                        tokenizedNeedle.Push(lbNeedle, "`n")
                    }
                    if lbSplit.Length
                        tokenizedNeedle.Pop()
                    tokenizedNeedle.Push(" ")
                }
                tokenizedNeedle.Pop()
                
                preceding := SubStr(fullHaystackNoLinebreaks, 1, offset - foundLen)
                StrReplace(preceding, " ",,, &startingWord:=0)
                startingWord := startingWord*2 + fullFirst - 1

                foundNeedle := "", foundWords := [], foundLines := [], line := this.__OCR.Line(this), line.DefineProp("Words", {value:[]}), line.DefineProp("Text", {value:""})
                Loop tokenizedNeedle.Length {
                    word := tokenizedHaystack[startingWord + A_Index]
                    if (word == "`n") {
                        foundNeedle .= line.Text
                        line.Text := RTrim(line.Text), foundLines.Push(line)
                        line := this.__OCR.Line(this), line.DefineProp("Words", {value:[]}), line.DefineProp("Text", {value:""})
                    }
                    if !IsObject(word)
                        continue
                    If IsSet(x1) && (word.x < x1 || word.y < y1 || word.x+word.w > x2 || word.y+word.h > y2) {
                        counter--
                        continue 2
                    }
                    line.Words.Push(word), line.Text .= word.Text " "
                    foundWords.Push(word)
                }
                if line.Text {
                    foundNeedle .= line.Text
                    line.Text := RTrim(line.Text), foundLines.Push(line)
                }

                result := this.Clone(), ObjAddRef(this.ptr)
                result.DefineProp("BoundingRect", {value: this.__OCR.WordsBoundingRect(foundWords*)})
                result.DefineProp("Lines", {value: foundLines})
                result.DefineProp("Words", {value: foundWords})
                result.DefineProp("Text", {value: foundNeedle})
                if All {
                    results.Push(result)
                } else
                    return result
            }
            if All
                return results

            throw TargetError('The target string "' Needle '" was not found', -1)
        }
    
        Filter(callback) {
            if !HasMethod(callback)
                throw ValueError("Filter callback must be a function", -1)
            local result := this.Clone(), line, croppedLines := [], croppedText := "", croppedWords := [], lineText := "", word
            ObjAddRef(result.ptr)
            for line in result.Lines {
                croppedWords := [], lineText := ""
                for word in line.Words {
                    if callback(word)
                        croppedWords.Push(word), lineText .= word.Text " "
                }
                if croppedWords.Length {
                    line := this.__OCR.Line()
                    line.DefineProp("Text", {value:Trim(lineText)})
                    line.DefineProp("Words", {value:croppedWords})
                    croppedLines.Push(line)
                    croppedText .= lineText
                }
            }
            result.DefineProp("Lines", {Value:croppedLines})
            result.DefineProp("Text", {Value:Trim(croppedText)})
            result.DefineProp("Words", this.__OCR.Result.Prototype.GetOwnPropDesc("Words"))
            return result
        }
    
        Crop(x1:=-100000, y1:=-100000, x2:=100000, y2:=100000) => this.Filter((word) => word.x >= x1 && word.y >= y1 && (word.x+word.w) <= x2 && (word.y+word.h) <= y2)
    }
    class Line extends OCR.Common {
        Text {
            get {
                ComCall(7, this, "ptr*", &hText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
                text := StrGet(buf, "UTF-16")
                this.__OCR.DeleteHString(hText)
                this.DefineProp("Text", {Value:text})
                return text
            }
        }

        Words {
            get {
                ComCall(6, this, "ptr*", WordsList:=ComValue(13, 0))
                ComCall(7, WordsList, "int*", &WordsCount:=0)
                words := []
                loop WordsCount {
                   ComCall(6, WordsList, "int", A_Index-1, "ptr*", Word:=this.__OCR.Word(this))
                   words.Push(Word)
                }
                this.DefineProp("Words", {Value:words})
                return words
            }
        }

        BoundingRect {
            get => this.DefineProp("BoundingRect", {Value:this.__OCR.WordsBoundingRect(this.Words*)}).BoundingRect
        }
    }

    class Word extends OCR.Common {
        Text {
            get {
                ComCall(7, this, "ptr*", &hText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
                text := StrGet(buf, "UTF-16")
                this.__OCR.DeleteHString(hText)
                this.DefineProp("Text", {Value:text})
                return text
            }
        }

        BoundingRect {
            get {
                ComCall(6, this, "ptr", RECT := Buffer(16, 0))
                this.DefineProp("x", {Value:Integer(NumGet(RECT, 0, "float"))})
                , this.DefineProp("y", {Value:Integer(NumGet(RECT, 4, "float"))})
                , this.DefineProp("w", {Value:Integer(NumGet(RECT, 8, "float"))})
                , this.DefineProp("h", {Value:Integer(NumGet(RECT, 12, "float"))})
                return this.DefineProp("BoundingRect", {Value:{x:this.x, y:this.y, w:this.w, h:this.h}}).BoundingRect
            }
        }
    }

    class Common extends OCR.IBase {
        x {
            get => this.BoundingRect.x
        } 
        y {
            get => this.BoundingRect.y
        }
        w {
            get => this.BoundingRect.w
        }
        h {
            get => this.BoundingRect.h
        }
    
        Highlight(showTime?, color:="Red", d:=2) {
            static Guis := Map()
            local x, y, w, h, key, oObj, GuiObj, iw, ih
            if IsSet(showTime) {
                if showTime = "clearall" {
                    for key, oObj in Guis {
                        try oObj.GuiObj.Destroy()
                        SetTimer(oObj.TimerObj, 0)
                    }
                    Guis := Map()
                    return this
                } else if showTime = "clear" {
                    if Guis.Has(this) {
                        try Guis[this].GuiObj.Destroy()
                        SetTimer(Guis[this].TimerObj, 0)
                        Guis.Delete(this)
                    }
                    return this
                }
            }
    
            if !IsSet(showTime) {
                if Guis.Has(this) {
                    try Guis[this].GuiObj.Destroy()
                    SetTimer(Guis[this].TimerObj, 0)
                    Guis.Delete(this)
                    return this
                } else
                    showTime := 2000
            }
    
            x := this.x, y := this.y, w := this.w, h := this.h
            if this.HasProp("Relative") {
                if this.Relative.HasProp("CoordMode") {
                    if this.Relative.CoordMode = "Client"
                        WinGetClientPos(&rX, &rY,,, this.Relative.hWnd), x += rX, y += rY
                    else if this.Relative.CoordMode = "Window"
                        WinGetPos(&rX, &rY,,, this.Relative.hWnd), x += rX, y += rY
                }
                x += this.Relative.HasProp("x") ? this.Relative.x : 0
                y += this.Relative.HasProp("y") ? this.Relative.y : 0
            }
    
            if !Guis.Has(this) {
                Guis[this] := {}
                Guis[this].GuiObj := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
                Guis[this].TimerObj := ObjBindMethod(this, "Highlight", "clear")
            }
            GuiObj := Guis[this].GuiObj
            GuiObj.BackColor := color
            iw:= w+d, ih:= h+d, w:=w+d*2, h:=h+d*2, x:=x-d, y:=y-d
            WinSetRegion("0-0 " w "-0 " w "-" h " 0-" h " 0-0 " d "-" d " " iw "-" d " " iw "-" ih " " d "-" ih " " d "-" d, GuiObj.Hwnd)
            GuiObj.Show("NA x" . x . " y" . y . " w" . w . " h" . h)
    
            if showTime > 0 {
                Sleep(showTime)
                this.Highlight()
            } else if showTime < 0
                SetTimer(Guis[this].TimerObj, -Abs(showTime))
            return this
        }
        ClearHighlight() => this.Highlight("clear")
    
        Click(WhichButton?, ClickCount?, DownOrUp?) {
            local x := this.x, y := this.y, w := this.w, h := this.h, mode := "Screen", hwnd
            if this.HasProp("Relative") {
                if this.Relative.HasProp("CoordMode") {
                    if this.Relative.CoordMode = "Window"
                        mode := "Window", hwnd := this.Relative.Hwnd
                    else if this.Relative.CoordMode = "Client"
                        mode := "Client", hwnd := this.Relative.Hwnd
                    if IsSet(hwnd) && !WinActive(hwnd) {
                        WinActivate(hwnd)
                        WinWaitActive(hwnd,,1)
                    }
                }
                x += this.Relative.HasProp("x") ? this.Relative.x : 0
                y += this.Relative.HasProp("y") ? this.Relative.y : 0
            }
            oldCoordMode := A_CoordModeMouse
            CoordMode "Mouse", mode
            Click(x+w//2, y+h//2, WhichButton?, ClickCount?, DownOrUp?)
            CoordMode "Mouse", oldCoordMode
        }
    
        ControlClick(WinTitle?, WinText?, WhichButton?, ClickCount?, Options?, ExcludeTitle?, ExcludeText?) {
            local x := this.x, y := this.y, w := this.w, h := this.h, hWnd
            if this.HasProp("Relative") {
                x += this.Relative.HasProp("x") ? this.Relative.x : 0
                y += this.Relative.HasProp("y") ? this.Relative.y : 0
            }
            if this.HasProp("Relative") && this.Relative.HasProp("CoordMode") && (this.Relative.CoordMode = "Client" || this.Relative.CoordMode = "Window") {
                mode := this.Relative.CoordMode, hWnd := this.Relative.hWnd
                if mode = "Window" {
                    RECT := Buffer(16, 0), pt := Buffer(8, 0)
                    DllCall("user32\GetWindowRect", "Ptr", hWnd, "Ptr", RECT)
                    winX := NumGet(RECT, 0, "Int"), winY := NumGet(RECT, 4, "Int")
                    NumPut("int", winX+x, "int", winY+y, pt)
                    DllCall("user32\ScreenToClient", "Ptr", hWnd, "Ptr", pt)
                    x := NumGet(pt,0,"int"), y := NumGet(pt,4,"int")
                }
            } else if IsSet(WinTitle) {
                hWnd := WinExist(WinTitle, WinText?, ExcludeTitle?, ExcludeText?)
                pt := Buffer(8), NumPut("int",x,pt), NumPut("int", y,pt,4)
                DllCall("ScreenToClient", "Int", Hwnd, "Ptr", pt)
                x := NumGet(pt,0,"int"), y := NumGet(pt,4,"int")
            } else
                throw TargetError("ControlClick needs to be called either after a OCR.FromWindow result or with a WinTitle argument")
                
            ControlClick("X" (x+w//2) " Y" (y+h//2), hWnd,, WhichButton?, ClickCount?, Options?)
        }
    
        OffsetCoordinates(offsetX?, offsetY?) {
            if !IsSet(offsetX) || !IsSet(offsetY) {
                if this.HasOwnProp("Relative") {
                    offsetX := this.Relative.HasProp("x") ? this.Relative.X : 0
                    offsetY := this.Relative.HasProp("y") ? this.Relative.Y : 0
                } else
                    throw Error("No Relative property found",, -1)
            }
            if offsetX = 0 && offsetY = 0
                return this
            local word
            for word in this.Words
                word.x += offsetX, word.y += offsetY, word.BoundingRect := {X:word.x, Y:word.y, W:word.w, H:word.h}
            return this
        }
    }

    static FromFile(FileName, Options:=0) {
        if !(fe := FileExist(FileName)) or InStr(fe, "D")
            throw TargetError("File `"" FileName "`" doesn't exist", -1)
        GUID := this.CLSIDFromString(this.IID_IRandomAccessStream)
        DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID, "ptr*", IRandomAccessStream:=this.IBase())
        if IsObject(Options) && !Options.HasProp("Decoder")
            Options.Decoder := this.Vtbl_GetDecoder.HasOwnProp(ext := StrSplit(FileName, ".")[-1]) ? ext : ""
        return this(IRandomAccessStream, Options)
    }

    static FromPDF(FileName, Options:=0, Start:=1, End?, Password:="") {
        this.__ExtractNamedParameters(Options, "lang", &lang, "start", &Start, "end", &End, "password", &Password)
        if !(fe := FileExist(FileName)) or InStr(fe, "D")
            throw TargetError("File `"" FileName "`" doesn't exist", -1)

        DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID := this.CLSIDFromString(this.IID_IRandomAccessStream), "ptr*", IRandomAccessStream:=ComValue(13,0))
        PdfDocument := this.__OpenPdfDocument(IRandomAccessStream, Password)
        this.CloseIClosable(IRandomAccessStream)
        if !IsSet(End) {
            ComCall(7, PdfDocument, "uint*", &End:=0)
            if !End
                throw Error("Unable to get PDF page count", -1)
        }
        local results := []
        Loop (End+1-Start)
            results.Push(this.FromPDFPage(PdfDocument, Start+(A_Index-1), Options))
        return results
    }

    static GetPdfPageCount(FileName, Password:="") {
        DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID := this.CLSIDFromString(this.IID_IRandomAccessStream), "ptr*", IRandomAccessStream:=ComValue(13,0))
        PdfDocument := this.__OpenPdfDocument(IRandomAccessStream, Password)
        this.CloseIClosable(IRandomAccessStream)
        ComCall(7, PdfDocument, "uint*", &PageCount:=0)
        if !PageCount
            throw Error("Unable to get PDF page count", -1)
        
        return PageCount
    }

    static GetPdfPageProperties(FileName, Page, Password:="") {
        DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID := this.CLSIDFromString(this.IID_IRandomAccessStream), "ptr*", IRandomAccessStream:=ComValue(13,0))
        PdfDocument := this.__OpenPdfDocument(IRandomAccessStream, Password)
        this.CloseIClosable(IRandomAccessStream)
        ComCall(6, PdfDocument, "uint", Page-1, "ptr*", PdfPage:=ComValue(13, 0))
        ComCall(10, PdfPage, "ptr*", Size:=Buffer(8, 0))
        ComCall(12, PdfPage, "uint*", &Rotation:=0)
        ComCall(12, PdfPage, "float*", &PreferredZoom:=0)
        return {Width: NumGet(Size, 0, "float"), Height: NumGet(size, 4, "float"), Rotation: Rotation*90, PreferredZoom:PreferredZoom}
    }

    static FromPDFPage(FileName, Page, Options:=0, Password:="") {
        local scale := 1, x := 0, y := 0, w := 0, h := 0
        if IsObject(Options)
            Options := Options.Clone()
        this.__ExtractNamedParameters(Options, "Password", &Password, "scale", &scale, "x", &x, "y", &y, "w", &w, "h", &h)
        if FileName is String {
            if !(fe := FileExist(FileName)) or InStr(fe, "D")
                throw TargetError("File `"" FileName "`" doesn't exist", -1)
            GUID := this.CLSIDFromString(this.IID_IRandomAccessStream)
            DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID, "ptr*", IRandomAccessStream:=ComValue(13, 0))
            PdfDocument := this.__OpenPdfDocument(IRandomAccessStream, Password)
        } else
            PdfDocument := FileName
        ComCall(6, PdfDocument, "uint", Page-1, "ptr*", PdfPage:=ComValue(13, 0))
        InMemoryRandomAccessStream := this.CreateClass("Windows.Storage.Streams.InMemoryRandomAccessStream")
        PdfPageRenderOptions := this.CreateClass("Windows.Data.Pdf.PdfPageRenderOptions")
        ComCall(15, PdfPageRenderOptions, "uint", true)
        if x || y || w || h {
            rect := Buffer(16, 0), NumPut("float", x, "float", y, "float", w, "float", h, rect)
            ComCall(7, PdfPageRenderOptions, "ptr", rect)
            Options.w := Options.w*scale, Options.h := Options.h*scale
            Options.DeleteProp("x"), Options.DeleteProp("y"), Options.DeleteProp("w"), Options.DeleteProp("h")
        }
        if (scale != 1) {
            ComCall(10, PdfPage, "ptr", Size:=Buffer(8, 0))
            ComCall(9, PdfPageRenderOptions, "uint", Floor((w || NumGet(size, 0, "float"))*scale))
            ComCall(11, PdfPageRenderOptions, "uint", Floor((h || NumGet(size, 4, "float"))*scale))
            Options.DeleteProp("scale")
        }
        ComCall(7, PdfPage, "ptr", InMemoryRandomAccessStream, "ptr", PdfPageRenderOptions, "ptr*", asyncInfo:=ComValue(13, 0))
        this.WaitForAsync(&asyncInfo)
        if FileName is String
            this.CloseIClosable(IRandomAccessStream)
        PdfPage := "", PdfDocument := "", IRandomAccessStream := ""
        OcrResult := this(InMemoryRandomAccessStream, Options)
        if scale != 1
            this.NormalizeCoordinates(OcrResult, scale)
        return OcrResult
    }

    static FromWindow(WinTitle:="", Options:=0, WinText:="", ExcludeTitle:="", ExcludeText:="") {
        local result, coordsmode := A_CoordModePixel, onlyClientArea := coordsMode = "Client", mode := 4, X := 0, Y := 0, W := 0, H := 0, sX, sY, hBitMap, hwnd, customRect := 0, transform := 0
        if !Options && Type(WinTitle) = "Object"
            Options := WinTitle, WinTitle := ""
        if IsObject(Options)
            Options := Options.Clone()
        this.__ExtractTransformParameters(Options, &transform)
        this.__ExtractNamedParameters(Options, "x", &x, "y", &y, "w", &w, "width", &w, "h", &h, "height", &h, "mode", &mode, "WinTitle", &WinTitle, "WinText", &WinText, "ExcludeTitle", &ExcludeTitle, "ExcludeText", &ExcludeText)
        this.__DeleteProps(Options, "x", "y", "w", "width", "h", "height", "scale", "mode")
        if (x !=0 || y != 0 || w != 0 || h != 0)
            customRect := 1
        if !(hWnd := WinExist(WinTitle, WinText, ExcludeTitle, ExcludeText))
            throw TargetError("Target window not found", -1)
        if DllCall("IsIconic", "uptr", hwnd)
            DllCall("ShowWindow", "uptr", hwnd, "int", 4)
        if mode < 4 && mode&1 {
            oldStyle := WinGetExStyle(hwnd), i := 0
            WinSetTransparent(255, hwnd)
            While (WinGetTransparent(hwnd) != 255 && ++i < 30)
                Sleep 100
        }

        WinGetPos(&wX, &wY, &wW, &wH, hWnd)
        If onlyClientArea {
            WinGetClientPos(&cX, &cY, &cW, &cH, hWnd)
            W := W || cW, H := H || cH, sX := X + cX, sY := Y + cY
        } else {
            W := W || wW, H := H || wH, sX := X + wX, sY := Y + wY
        }

        if mode = 5 {
            SoftwareBitmap := this.CreateDirect3DSoftwareBitmapFromWindow(hWnd)

            local sbW := SoftwareBitmap.W, sbH := SoftwareBitmap.H, sbX := SoftwareBitmap.X, sbY := SoftwareBitmap.Y
            local offsetX := 0, offsetY := 0

            if transform.scale != 1 || transform.rotate || transform.flip || customRect || onlyClientArea {
                local tX := X, tY := Y, tW := W, tH := H
                if onlyClientArea
                    tX -= SoftwareBitmap.X-cX, tY -= SoftwareBitmap.Y-cY
                else
                    tX -= SoftwareBitmap.X-wX, tY -= SoftwareBitmap.Y-wY
                if tX < 0
                    tW += tX, offsetX := -tX, tX := 0
                if tY < 0
                    tH += tY, offsetY := -tY, tY := 0
                tW := Min(sbW-tX, tW), tH := Min(sbH-tY, tH)

                SoftwareBitmap := this.TransformSoftwareBitmap(SoftwareBitmap, &sbW, &sbH, transform.scale, transform.rotate, transform.flip, tX, tY, tW, tH)
                this.__DeleteProps(Options, "scale", "rotate", "flip")
            } else
                offsetX := sbX-wX, offsetY := sbY-wY
            result := this(SoftwareBitmap, Options)
        } else {
            hBitMap := this.CreateHBitmap(X, Y, W, H, {hWnd:hWnd, onlyClientArea:onlyClientArea, mode:(mode//2)}, transform.scale)
            if mode&1
                WinSetExStyle(oldStyle, hwnd)
            SoftwareBitmap := this.HBitmapToSoftwareBitmap(hBitMap,, transform)
            this.__DeleteProps(Options, "invertcolors", "grayscale", "monochrome")
            result := this(SoftwareBitmap, Options)
        }

        result.Relative := {CoordMode:coordsmode, hWnd:hWnd}
        if coordsmode = "Screen"
            x += sX, y += sY
        this.NormalizeCoordinates(result, transform.scale, x, y)
        if mode = 5 && !onlyClientArea
            result.OffsetCoordinates(offsetX, offsetY)
        return result
    }

    static FromMonitor(Monitor?, Options:=0) {
        if !Options && IsSet(Monitor) && IsObject(Monitor)
            Options := Monitor, Monitor := unset
        this.__ExtractNamedParameters(Options, "Monitor", &Monitor)
        MonitorGet(monitor?, &Left, &Top, &Right, &Bottom)
        return this.FromRect(Left, Top, Right-Left, Bottom-Top, Options)
    }

    static FromDesktop(Options:=0) => this.FromRect(SysGet(76), SysGet(77), SysGet(78), SysGet(79), Options)

    static FromRect(x, y, w, h, Options:=0) {
        local transform := 0, result
        if IsObject(Options)
            Options := Options.Clone()
        this.__ExtractTransformParameters(Options, &transform)
        this.__DeleteProps(Options, "scale", "invertcolors", "grayscale")
        local scale := transform.scale
            , hBitmap := this.CreateHBitmap(X, Y, W, H,, scale)
            , SoftwareBitmap := this.HBitmapToSoftwareBitmap(hBitmap,, transform)
            , result := this(SoftwareBitmap, Options)
        return this.NormalizeCoordinates(result, scale, x, y)
    }

    static FromBitmap(Bitmap, Options:=0, hDC?) {
        local result, pDC, hBitmap, hBM2, oBM, oBM2, pBitmapInfo := Buffer(32, 0), W, H, scale, transform := 0
        if IsObject(Options)
            Options := Options.Clone()
        this.__ExtractTransformParameters(Options, &transform)
        scale := transform.scale
        this.__ExtractNamedParameters(Options, "hDC", &hDC)
        this.__DeleteProps(Options, "scale", "invertcolors", "grayscale")
        if !DllCall("GetObject", "ptr", Bitmap, "int", pBitmapInfo.Size, "ptr", pBitmapInfo) {
            DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", Bitmap, "UPtr*", &hBitmap:=0, "Int", 0xffffffff)
            DllCall("GetObject", "ptr", hBitmap, "int", pBitmapInfo.Size, "ptr", pBitmapInfo)
            Bitmap := 0
        } else
            hBitmap := Bitmap

        W := NumGet(pBitmapInfo, 4, "int"), H := NumGet(pBitmapInfo, 8, "int")

        if scale != 1 || (W && H && (W < 40 || H < 40)) {
            sW := Ceil(W * scale), sH := Ceil(H * scale)

            hDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
            , oBM := DllCall("SelectObject", "Ptr", hDC, "Ptr", hBitmap, "Ptr")
            , pDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
            , hBM2 := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", Max(40, sW), "Int", Max(40, sH), "Ptr")
            , oBM2 := DllCall("SelectObject", "Ptr", pDC, "Ptr", hBM2, "Ptr")
            if sW < 40 || sH < 40
                DllCall("StretchBlt", "Ptr", pDC, "Int", 0, "Int", 0, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr", hDC, "Int", 0, "Int", 0, "Int", 1, "Int", 1, "UInt", 0x00CC0020 | this.CAPTUREBLT)
            PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
            , DllCall("StretchBlt", "Ptr", pDC, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", hDC, "Int", 0, "Int", 0, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
            , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
            , DllCall("SelectObject", "Ptr", pDC, "Ptr", oBM2)
            , DllCall("SelectObject", "Ptr", hDC, "Ptr", oBM)
            , DllCall("DeleteDC", "Ptr", hDC)
            SoftwareBitmap := this.HBitmapToSoftwareBitmap(hBM2, pDC, transform)
            result := this(SoftwareBitmap, Options)
            this.NormalizeCoordinates(result, scale)
            DllCall("DeleteDC", "Ptr", pDC)
            , DllCall("DeleteObject", "UPtr", hBM2)
            goto End
        }
        result := this(this.HBitmapToSoftwareBitmap(hBitmap, hDC?, transform), Options)
        End:
        if !Bitmap
            DllCall("DeleteObject", "UPtr", hBitmap)
        return result
    } 

    static GetAvailableLanguages() {
        ComCall(7, this.OcrEngineStatics, "ptr*", &LanguageList := 0)
        ComCall(7, LanguageList, "int*", &count := 0)
        Loop count {
            ComCall(6, LanguageList, "int", A_Index - 1, "ptr*", &Language := 0)
            ComCall(6, Language, "ptr*", &hText := 0)
            buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length := 0, "ptr")
            text .= StrGet(buf, "UTF-16") "`n"
            this.DeleteHString(hText)
            ObjRelease(Language)
        }
        ObjRelease(LanguageList)
        return text
    }

    static LoadLanguage(lang:="FirstFromAvailableLanguages") {
        local hString, Language:=ComValue(13, 0), OcrEngine:=ComValue(13, 0)
        if this.HasOwnProp("CurrentLanguage") && this.HasOwnProp("OcrEngine") && this.CurrentLanguage = lang
            return
        if HasMethod(lang)
            lang := lang()
        if (lang = "FirstFromAvailableLanguages")
            ComCall(10, this.OcrEngineStatics, "ptr*", OcrEngine)
        else {
            hString := this.CreateHString(lang)
            , ComCall(6, this.LanguageFactory, "ptr", hString, "ptr*", Language)
            , this.DeleteHString(hString)
            , ComCall(9, this.OcrEngineStatics, "ptr", Language, "ptr*", OcrEngine)
        }
        if (OcrEngine.ptr = 0)
            Throw Error(lang = "FirstFromAvailableLanguages" ? "Failed to use FirstFromAvailableLanguages for OCR:`nmake sure the primary language pack has OCR capabilities installed.`n`nAlternatively try `"en-us`" as the language." : "Can not use language `"" lang "`" for OCR, please install language pack.")
        this.OcrEngine := OcrEngine, this.CurrentLanguage := lang
    }

    static WordsBoundingRect(words*) {
        if !words.Length
            throw ValueError("This function requires at least one argument", -1)
        local X1 := 100000000, Y1 := 100000000, X2 := -100000000, Y2 := -100000000, word
        for word in words {
            X1 := Min(word.x, X1), Y1 := Min(word.y, Y1), X2 := Max(word.x+word.w, X2), Y2 := Max(word.y+word.h, Y2)
        }
        return {X:X1, Y:Y1, W:X2-X1, H:Y2-Y1, X2:X2, Y2:Y2}
    }
    
    static WaitText(needle, timeout:=-1, func?, casesense:=False, comparefunc?) {
        local endTime := A_TickCount+timeout, result, line, total
        if !IsSet(func)
            func := this.FromDesktop
        if !IsSet(comparefunc)
            comparefunc := InStr.Bind(,,casesense)
        While timeout > 0 ? (A_TickCount < endTime) : 1 {
            result := func(), total := ""
            for line in result.Lines
                total .= line.Text "`n"
            if comparefunc(Trim(total, "`n"), needle)
                return result
        }
        return
    }

    static Cluster(objs, eps_x:=-1, eps_y:=-1, minPts:=1, compareFunc?, &noise?) {
        local clusters := [], start := 0, cluster, word
        visited := Map(), clustered := Map(), C := [], c_n := 0, sum := 0, noise := IsSet(noise) && (noise is Array) ? noise : []
        if !IsObject(objs) || !(objs is Array)
            throw ValueError("objs argument must be an Array", -1)
        if !objs.Length
            return []
        if IsSet(compareFunc) && !HasMethod(compareFunc)
            throw ValueError("compareFunc must be a valid function", -1)

        if !IsSet(compareFunc) {
            if (eps_y < 0) {
                for point in objs
                    sum += point.h
                eps_y := (sum // objs.Length) // 2
            }
            compareFunc := (p1, p2) => Abs(p1.y+p1.h//2-p2.y-p2.h//2)<eps_y && (eps_x < 0 || (Abs(p1.x+p1.w-p2.x)<eps_x || Abs(p1.x-p2.x-p2.w)<eps_x))
        }

        for point in objs {
            visited[point] := 1, neighbourPts := [], RegionQuery(point)
            if !clustered.Has(point) {
                C.Push([]), c_n += 1, C[c_n].Push(point), clustered[point] := 1
                ExpandCluster(point)
            }
            if C[c_n].Length < minPts
                noise.Push(C[c_n]), C.RemoveAt(c_n), c_n--
        }

        for cluster in C {
            this.SortArray(cluster,,"x")
            br := this.Common(), br.DefineProp("BoundingRect", {value:this.WordsBoundingRect(cluster*)}), br.DefineProp("Words", {value:cluster}), br.DefineProp("Text", {value: ""})
            for word in cluster
                br.Text .= word.Text " "
            br.Text := RTrim(br.Text)
            clusters.Push(br)
        }
        this.SortArray(clusters,,"y")
        return clusters

        ExpandCluster(P) {
            local point
            for point in neighbourPts {
                if !visited.Has(point) {
                    visited[point] := 1, RegionQuery(point)
                    if !clustered.Has(point)
                        C[c_n].Push(point), clustered[point] := 1
                }
            }
        }

        RegionQuery(P) {
            local point
            for point in objs
                if !visited.Has(point)
                    if compareFunc(P, point)
                        neighbourPts.Push(point)
        }
    }

    static SortArray(arr, optionsOrCallback:="N", key?) {
        if (arr.Length < 2)
            return this
        if HasMethod(optionsOrCallback)
            compareFunc := optionsOrCallback, optionsOrCallback := ""
        else {
            if InStr(optionsOrCallback, "N")
                compareFunc := IsSet(key) ? NumericCompareKey.Bind(key) : NumericCompare
            if RegExMatch(optionsOrCallback, "i)C(?!0)|C1|COn")
                compareFunc := IsSet(key) ? StringCompareKey.Bind(key,,True) : StringCompare.Bind(,,True)
            if RegExMatch(optionsOrCallback, "i)C0|COff")
                compareFunc := IsSet(key) ? StringCompareKey.Bind(key) : StringCompare
            if InStr(optionsOrCallback, "Random") {
                len := arr.Length
                Loop len-1 {
                    i := len + 1 - A_Index
                    j := Random(1, i)
                    if (j != i)
                        tmp := arr[i], arr[i] := arr[j], arr[j] := tmp
                }
                return arr
            }
            if !IsSet(compareFunc)
                throw ValueError("No valid options provided!", -1)
        }
        QuickSort(1, arr.Length)
        if RegExMatch(optionsOrCallback, "i)R(?!a)")
            this.ReverseArray(arr)
        if InStr(optionsOrCallback, "U")
            arr := this.UniqueArray(arr)
        return arr

        NumericCompare(left, right) => (left > right) - (left < right)
        NumericCompareKey(key, left, right) => ((f1 := left.HasProp("__Item") ? left[key] : left.%key%), (f2 := right.HasProp("__Item") ? right[key] : right.%key%), (f1 > f2) - (f1 < f2))
        StringCompare(left, right, casesense := False) => StrCompare(left "", right "", casesense)
        StringCompareKey(key, left, right, casesense := False) => StrCompare((left.HasProp("__Item") ? left[key] : left.%key%) "", (right.HasProp("__Item") ? right[key] : right.%key%) "", casesense)

        QuickSort(left, right) {
            i := left
            j := right
            pivot := arr[(left + right) // 2]

            while (i <= j) {
                while (compareFunc(arr[i], pivot) < 0)
                    i++
                while (compareFunc(arr[j], pivot) > 0)
                    j--
                if (i <= j) {
                    temp := arr[i], arr[i] := arr[j], arr[j] := temp
                    i++, j--
                }
            }
            if (left < j)
                QuickSort(left, j)
            if (i < right)
                QuickSort(i, right)
        }
    }
    static ReverseArray(arr) {
        local len := arr.Length + 1, max := (len // 2), i := 0
        while ++i <= max
            temp := arr[len - i], arr[len - i] := arr[i], arr[i] := temp
        return arr
    }
    static UniqueArray(arr) {
        local unique := Map()
        for v in arr
            unique[v] := 1
        return [unique*]
    }

    static FlattenArray(arr) {
        local r := []
        for v in arr {
            if v is Array
                r.Push(this.FlattenArray(v)*)
            else
                r.Push(v)
        }
        return r
    }


    static TransformSoftwareBitmap(SoftwareBitmap, &sbW, &sbH, scale:=1, rotate:=0, flip:=0, X?, Y?, W?, H?) {
        InMemoryRandomAccessStream := this.SoftwareBitmapToRandomAccessStream(SoftwareBitmap)

        ComCall(this.Vtbl_GetDecoder.png, this.BitmapDecoderStatics, "ptr", DecoderGUID:=Buffer(16))
        ComCall(15, this.BitmapDecoderStatics, "ptr", DecoderGUID, "ptr", InMemoryRandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        this.WaitForAsync(&BitmapDecoder)

        BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, IBitmapFrameWithSoftwareBitmap := "{FE287C9A-420C-4963-87AD-691436E08383}")
        BitmapFrame := ComObjQuery(BitmapDecoder, IBitmapFrame := "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")

        BitmapTransform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")

        if IsSet(W) && W
            sbW := Min(sbW, W)
        if IsSet(H) && H
            sbH := Min(sbH, H)
        local sW := Floor(sbW*scale), sH := Floor(sbH*scale), intermediate
        if scale != 1 {
            ComCall(7, BitmapTransform, "uint", sW)
            ComCall(9, BitmapTransform, "uint", sH)
        }
        if rotate {
            ComCall(15, BitmapTransform, "uint", rotate//90)
            if rotate = 90 || rotate = 270
                intermediate := sW, sW := sH, sH := intermediate
        }
        if flip
            ComCall(13, BitmapTransform, "uint", flip)

        if (IsSet(X) && X != 0) || (IsSet(Y) && Y != 0) || IsSet(W) || IsSet(H)  {
            bounds := Buffer(16,0), NumPut("int", Floor(X*scale), "int", Floor(Y*scale), "int", Floor(sbW*scale), "int", Floor(sbH*scale), bounds)
            ComCall(17, BitmapTransform, "ptr", bounds)
        }
        ComCall(8, BitmapFrame, "uint*", &BitmapPixelFormat:=0)
        ComCall(9, BitmapFrame, "uint*", &BitmapAlphaMode:=0)
        ComCall(8, BitmapFrameWithSoftwareBitmap, "uint", BitmapPixelFormat, "uint", BitmapAlphaMode, "ptr", BitmapTransform, "uint", IgnoreExifOrientation := 0, "uint", DoNotColorManage := 0, "ptr*", SoftwareBitmap:=ComValue(13,0))

        this.WaitForAsync(&SoftwareBitmap)
        this.CloseIClosable(InMemoryRandomAccessStream)
        sbW := sW, sbH := sH
        return SoftwareBitmap
    }

    static CreateDIBSection(w, h, hdc?, bpp:=32, &ppvBits:=0) {
        local hdc2 := IsSet(hdc) ? hdc : DllCall("GetDC", "Ptr", 0, "UPtr")
        , bi := Buffer(40, 0), hbm
        NumPut("int", 40, "int", w, "int", h, "ushort", 1, "ushort", bpp, "int", 0, bi)
        hbm := DllCall("CreateDIBSection", "uint", hdc2, "ptr" , bi, "uint" , 0, "uint*", &ppvBits:=0, "uint" , 0, "uint" , 0)
        if !IsSet(hdc)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc2)
        return hbm
    }

    static CreateHBitmap(X, Y, W, H, hWnd:=0, scale:=1) {
        local sW := Ceil(W*scale), sH := Ceil(H*scale), onlyClientArea := 0, mode := 2, HDC, obm, hbm, pdc, hbm2
        if hWnd {
            if IsObject(hWnd)
                onlyClientArea := hWnd.HasOwnProp("onlyClientArea") ? hWnd.onlyClientArea : onlyClientArea, mode := hWnd.HasOwnProp("mode") ? hWnd.mode : mode, hWnd := hWnd.hWnd
            HDC := DllCall("GetDCEx", "Ptr", hWnd, "Ptr", 0, "Int", 2|!onlyClientArea, "Ptr")
            if mode > 0 {
                PDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
                HBM := DllCall("CreateCompatibleBitmap", "Ptr", HDC, "Int", Max(40,X+W), "Int", Max(40,Y+H), "Ptr")
                , OBM := DllCall("SelectObject", "Ptr", PDC, "Ptr", HBM, "Ptr")
                , DllCall("PrintWindow", "Ptr", hWnd, "Ptr", PDC, "UInt", (mode=2?2:0)|!!onlyClientArea)
                if scale != 1 || X != 0 || Y != 0 {
                    PDC2 := DllCall("CreateCompatibleDC", "Ptr", PDC, "Ptr")
                    , HBM2 := DllCall("CreateCompatibleBitmap", "Ptr", PDC, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr")
                    , OBM2 := DllCall("SelectObject", "Ptr", PDC2, "Ptr", HBM2, "Ptr")
                    , PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
                    , DllCall("StretchBlt", "Ptr", PDC2, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", PDC, "Int", X, "Int", Y, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
                    , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
                    , DllCall("SelectObject", "Ptr", PDC2, "Ptr", obm2)
                    , DllCall("DeleteDC", "Ptr", PDC)
                    , DllCall("DeleteObject", "UPtr", HBM)
                    , hbm := hbm2, pdc := pdc2
                }
                DllCall("SelectObject", "Ptr", PDC, "Ptr", OBM)
                , DllCall("DeleteDC", "Ptr", HDC)
                , oHBM := this.IBase(HBM), oHBM.DC := PDC
                return oHBM.DefineProp("__Delete", {call:(this, *)=>(DllCall("DeleteObject", "Ptr", this), DllCall("DeleteDC", "Ptr", this.DC))})
            }
        } else {
            HDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        }
        PDC := DllCall("CreateCompatibleDC", "Ptr", HDC, "Ptr")
        , HBM := DllCall("CreateCompatibleBitmap", "Ptr", HDC, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr")
        , OBM := DllCall("SelectObject", "Ptr", PDC, "Ptr", HBM, "Ptr")
        if sW < 40 || sH < 40
            DllCall("StretchBlt", "Ptr", PDC, "Int", 0, "Int", 0, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr", HDC, "Int", X, "Int", Y, "Int", 1, "Int", 1, "UInt", 0x00CC0020 | this.CAPTUREBLT)
        PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
        , DllCall("StretchBlt", "Ptr", PDC, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", HDC, "Int", X, "Int", Y, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
        , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
        , DllCall("SelectObject", "Ptr", PDC, "Ptr", OBM)
        , DllCall("DeleteDC", "Ptr", HDC)
        , oHBM := this.IBase(HBM), oHBM.DC := PDC
        return oHBM.DefineProp("__Delete", {call:(this, *)=>(DllCall("DeleteObject", "Ptr", this), DllCall("DeleteDC", "Ptr", this.DC))})
    }

    static CreateDirect3DSoftwareBitmapFromWindow(hWnd) {
        static init := 0, DXGIDevice, Direct3DDevice, Direct3D11CaptureFramePoolStatics, GraphicsCaptureItemInterop, GraphicsCaptureItemGUID, D3D_Device, D3D_Context
        local x, y, w, h, rect
        if !init {
            DllCall("LoadLibrary","str","DXGI")
            DllCall("LoadLibrary","str","D3D11")
            DllCall("LoadLibrary","str","Dwmapi")
            DllCall("D3D11\D3D11CreateDevice", "ptr", 0, "int", D3D_DRIVER_TYPE_HARDWARE := 1, "ptr", 0, "uint", D3D11_CREATE_DEVICE_BGRA_SUPPORT := 0x20, "ptr", 0, "uint", 0, "uint", D3D11_SDK_VERSION := 7, "ptr*", D3D_Device:=ComValue(13, 0), "ptr*", 0, "ptr*", D3D_Context:=ComValue(13, 0))
            DXGIDevice := ComObjQuery(D3D_Device, IID_IDXGIDevice := "{54ec77fa-1377-44e6-8c32-88fd5f44c84c}")
            DllCall("D3D11\CreateDirect3D11DeviceFromDXGIDevice", "ptr", DXGIDevice, "ptr*", GraphicsDevice:=ComValue(13, 0))
            Direct3DDevice := ComObjQuery(GraphicsDevice, IDirect3DDevice := "{A37624AB-8D5F-4650-9D3E-9EAE3D9BC670}")
            Direct3D11CaptureFramePoolStatics := this.CreateClass("Windows.Graphics.Capture.Direct3D11CaptureFramePool", IDirect3D11CaptureFramePoolStatics := "{7784056a-67aa-4d53-ae54-1088d5a8ca21}")
            GraphicsCaptureItemStatics := this.CreateClass("Windows.Graphics.Capture.GraphicsCaptureItem", IGraphicsCaptureItemStatics := "{A87EBEA5-457C-5788-AB47-0CF1D3637E74}")
            GraphicsCaptureItemInterop := ComObjQuery(GraphicsCaptureItemStatics, IGraphicsCaptureItemInterop := "{3628E81B-3CAC-4C60-B7F4-23CE0E0C3356}")
            GraphicsCaptureItemGUID := Buffer(16,0)
            DllCall("ole32\CLSIDFromString", "wstr", IGraphicsCaptureItem := "{79c3f95b-31f7-4ec2-a464-632ef5d30760}", "ptr", GraphicsCaptureItemGUID)
            init := 1
        }

        DllCall("Dwmapi.dll\DwmGetWindowAttribute", "ptr", hWnd, "uint", DWMWA_EXTENDED_FRAME_BOUNDS := 9, "ptr", rect := Buffer(16,0), "uint", 16)
        x := NumGet(rect, 0, "int"), y := NumGet(rect, 4, "int"), w := NumGet(rect, 8, "int") - x, h := NumGet(rect, 12, "int") - y
        ComCall(6, Direct3D11CaptureFramePoolStatics, "ptr", Direct3DDevice, "int", B8G8R8A8UIntNormalized := 87, "int", numberOfBuffers := 2, "int64", (h << 32) | w, "ptr*", Direct3D11CaptureFramePool:=ComValue(13, 0))
        if ComCall(3, GraphicsCaptureItemInterop, "ptr", hWnd, "ptr", GraphicsCaptureItemGUID, "ptr*", GraphicsCaptureItem:=ComValue(13, 0), "uint") {
            this.CloseIClosable(Direct3D11CaptureFramePool)
            throw Error("Failed to capture GraphicsItem of window",, -1)
        }
        ComCall(10, Direct3D11CaptureFramePool, "ptr", GraphicsCaptureItem, "ptr*", GraphicsCaptureSession:=ComValue(13, 0))

        GraphicsCaptureSession2 := ComObjQuery(GraphicsCaptureSession, IGraphicsCaptureSession2 := "{2c39ae40-7d2e-5044-804e-8b6799d4cf9e}")
        ComCall(7, GraphicsCaptureSession2, "int", 0)

        if (Integer(StrSplit(A_OSVersion, ".")[3]) >= 20348) {
            GraphicsCaptureSession3 := ComObjQuery(GraphicsCaptureSession, IGraphicsCaptureSession3 := "{f2cdd966-22ae-5ea1-9596-3a289344c3be}")
            ComCall(7, GraphicsCaptureSession3, "int", 0)
        }
        ComCall(6, GraphicsCaptureSession)
        Loop {
            ComCall(7, Direct3D11CaptureFramePool, "ptr*", Direct3D11CaptureFrame:=ComValue(13, 0))
            if (Direct3D11CaptureFrame.ptr != 0)
                break
        }
        ComCall(6, Direct3D11CaptureFrame, "ptr*", Direct3DSurface:=ComValue(13, 0))

        ComCall(11, this.SoftwareBitmapStatics, "ptr", Direct3DSurface, "ptr*", SoftwareBitmap:=ComValue(13, 0))
        this.WaitForAsync(&SoftwareBitmap)

        this.CloseIClosable(Direct3D11CaptureFramePool)
        this.CloseIClosable(GraphicsCaptureSession)
        if GraphicsCaptureSession2 {
            this.CloseIClosable(GraphicsCaptureSession2)
        }
        if IsSet(GraphicsCaptureSession3) {
            this.CloseIClosable(GraphicsCaptureSession3)
        }
        this.CloseIClosable(Direct3D11CaptureFrame)
        this.CloseIClosable(Direct3DSurface)

        SoftwareBitmap.x := x, SoftwareBitmap.y := y, SoftwareBitmap.w := w, SoftwareBitmap.h := h
        return SoftwareBitmap
    }

    static HBitmapToRandomAccessStream(hBitmap) {
        static PICTYPE_BITMAP := 1
             , BSOS_DEFAULT   := 0
             , sz := 8 + A_PtrSize*2
        local PICTDESC, riid, size, pIRandomAccessStream
             
        DllCall("Ole32\CreateStreamOnHGlobal", "Ptr", 0, "UInt", true, "Ptr*", pIStream:=ComValue(13,0), "UInt")
        , PICTDESC := Buffer(sz, 0)
        , NumPut("uint", sz, "uint", PICTYPE_BITMAP, "ptr", IsInteger(hBitmap) ? hBitmap : hBitmap.ptr, PICTDESC)
        , riid := this.CLSIDFromString(this.IID_IPicture)
        , DllCall("OleAut32\OleCreatePictureIndirect", "Ptr", PICTDESC, "Ptr", riid, "UInt", 0, "Ptr*", pIPicture:=ComValue(13,0), "UInt")
        , ComCall(15, pIPicture, "Ptr", pIStream, "UInt", true, "uint*", &size:=0, "UInt")
        , riid := this.CLSIDFromString(this.IID_IRandomAccessStream)
        , DllCall("ShCore\CreateRandomAccessStreamOverStream", "Ptr", pIStream, "UInt", BSOS_DEFAULT, "Ptr", riid, "Ptr*", pIRandomAccessStream:=ComValue(13, 0), "UInt")
        Return pIRandomAccessStream
    }

    static HBitmapToSoftwareBitmap(hBitmap, hDC?, transform?) {
        local bi := Buffer(40, 0), W, H, BitmapBuffer, MemoryBuffer, MemoryBufferReference, BufferByteAccess, BufferSize
        hDC := (hBitmap is OCR.IBase ? hBitmap.DC : (hDC ?? dhDC := DllCall("GetDC", "Ptr", 0, "UPtr")))

        NumPut("uint", 40, bi, 0)
        DllCall("GetDIBits", "ptr", hDC, "ptr", hBitmap, "uint", 0, "uint", 0, "ptr", 0, "ptr", bi, "uint", 0)
        W := NumGet(bi, 4, "int"), H := NumGet(bi, 8, "int")

        ComCall(7, this.SoftwareBitmapFactory, "int", 87, "int", W, "int", H, "int", 0, "ptr*", SoftwareBitmap := ComValue(13,0))
        ComCall(15, SoftwareBitmap, "int", 2, "ptr*", &BitmapBuffer := 0)
        MemoryBuffer := ComObjQuery(BitmapBuffer, "{fbc4dd2a-245b-11e4-af98-689423260cf8}")
        ComCall(6, MemoryBuffer, "ptr*", &MemoryBufferReference := 0)
        BufferByteAccess := ComObjQuery(MemoryBufferReference, "{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
        ComCall(3, BufferByteAccess, "ptr*", &SoftwareBitmapByteBuffer:=0, "uint*", &BufferSize:=0)

        NumPut("short", 32, "short", 0, bi, 14), NumPut("int", -H, bi, 8)
        DllCall("GetDIBits", "ptr", hDC, "ptr", hBitmap, "uint", 0, "uint", H, "ptr", SoftwareBitmapByteBuffer, "ptr", bi, "uint", 0)
        if IsSet(transform) {
            if (transform.HasProp("grayscale") && transform.grayscale)
                DllCall(this.GrayScaleMCode, "ptr", SoftwareBitmapByteBuffer, "uint", w, "uint", h, "uint", (w*4+3) // 4 * 4, "cdecl uint")
            if (transform.HasProp("monochrome") && transform.monochrome)
                DllCall(this.MonochromeMCode, "ptr", SoftwareBitmapByteBuffer, "uint", w, "uint", h, "uint", (w*4+3) // 4 * 4, "uint", transform.monochrome, "cdecl uint")
            if (transform.HasProp("invertcolors") && transform.invertcolors)
                DllCall(this.InvertColorsMCode, "ptr", SoftwareBitmapByteBuffer, "uint", w, "uint", h, "uint", (w*4+3) // 4 * 4, "cdecl uint")
        }
        
        if IsSet(dhDC)
            DllCall("DeleteDC", "ptr", dhDC)
        if BufferByteAccess.HasMethod("Dispose")
            BufferByteAccess.Dispose()
        if MemoryBuffer.HasMethod("Dispose")
            MemoryBuffer.Dispose()
        BufferByteAccess := "", ObjRelease(MemoryBufferReference), MemoryBuffer := "", ObjRelease(BitmapBuffer)

        return SoftwareBitmap
    }

    static MCode(mcode) {
        static e := Map('1', 4, '2', 1), c := (A_PtrSize=8) ? "x64" : "x86"
        if (!regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", &m))
          return
        if (!DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", 0, "uint*", &s := 0, "ptr", 0, "ptr", 0))
          return
        p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
        if (c="x64")
          DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", &op := 0)
        if (DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", p, "uint*", &s, "ptr", 0, "ptr", 0))
          return p
        DllCall("GlobalFree", "ptr", p)
      }

    static DisplayHBitmap(hBitmap) {
        local gImage := Gui("-DPIScale"), W, H
        , hPic := gImage.Add("Text", "0xE w640 h640")
        SendMessage(0x172, 0, hBitmap,, hPic.hWnd)
        hPic.GetPos(,,&W, &H)
        gImage.Show("w" (W+20) " H" (H+20))
        WinWaitClose gImage
    }

    static SoftwareBitmapToRandomAccessStream(SoftwareBitmap) {
        InMemoryRandomAccessStream := this.CreateClass("Windows.Storage.Streams.InMemoryRandomAccessStream")
        ComCall(8, this.BitmapEncoderStatics, "ptr", encoderId := Buffer(16, 0))
        ComCall(13, this.BitmapEncoderStatics, "ptr", encoderId, "ptr", InMemoryRandomAccessStream, "ptr*", BitmapEncoder:=ComValue(13,0))
        this.WaitForAsync(&BitmapEncoder)
        BitmapEncoderWithSoftwareBitmap := ComObjQuery(BitmapEncoder, "{686cd241-4330-4c77-ace4-0334968b1768}")
        ComCall(6, BitmapEncoderWithSoftwareBitmap, "ptr", SoftwareBitmap)
        ComCall(19, BitmapEncoder, "ptr*", asyncAction:=ComValue(13,0))
        this.WaitForAsync(&asyncAction)
        ComCall(11, InMemoryRandomAccessStream, "int64", 0)
        return InMemoryRandomAccessStream
    }

    static CreateClass(str, interface?) {
        local hString := this.CreateHString(str), result
        if !IsSet(interface) {
            result := DllCall("Combase.dll\RoActivateInstance", "ptr", hString, "ptr*", cls:=ComValue(13, 0), "uint")
        } else {
            GUID := this.CLSIDFromString(interface)
            result := DllCall("Combase.dll\RoGetActivationFactory", "ptr", hString, "ptr", GUID, "ptr*", cls:=ComValue(13, 0), "uint")
        }
        if (result != 0) {
            if (result = 0x80004002)
                throw Error("No such interface supported", -1, interface)
            else if (result = 0x80040154)
                throw Error("Class not registered", -1)
            else
                throw Error(result)
        }
        this.DeleteHString(hString)
        return cls
    }
    
    static CreateHString(str) => (DllCall("Combase.dll\WindowsCreateString", "wstr", str, "uint", StrLen(str), "ptr*", &hString:=0), hString)
    
    static DeleteHString(hString) => DllCall("Combase.dll\WindowsDeleteString", "ptr", hString)
    
    static WaitForAsync(&obj) {
        local AsyncInfo := ComObjQuery(obj, this.IID_IAsyncInfo), status, ErrorCode
        Loop {
            ComCall(7, AsyncInfo, "uint*", &status:=0)
            if (status != 0) {
                if (status != 1) {
                    ComCall(8, ASyncInfo, "uint*", &ErrorCode:=0)
                    throw Error("AsyncInfo failed with status error " ErrorCode, -1)
                }
                break
            }
            Sleep this.PerformanceMode ? -1 : 0
        }
        ComCall(8, obj, "ptr*", ObjectResult:=this.IBase())
        obj := ObjectResult
    }

    static CloseIClosable(pClosable) {
        static IClosable := "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}"
        local Close := ComObjQuery(pClosable, IClosable)
        ComCall(6, Close)
    }

    static CLSIDFromString(IID) {
        local CLSID := Buffer(16), res
        if res := DllCall("ole32\CLSIDFromString", "WStr", IID, "Ptr", CLSID, "UInt")
           throw Error("CLSIDFromString failed. Error: " . Format("{:#x}", res))
        Return CLSID
    }

    static NormalizeCoordinates(result, scale, x:=0, y:=0) {
        local word
        if (scale == 1 && x == 0 && y == 0)
            return result
        for word in result.Words
            word.x := Integer(word.x / scale)+x, word.y := Integer(word.y / scale)+y, word.w := Integer(word.w / scale), word.h := Integer(word.h / scale), word.BoundingRect := {X:word.x, Y:word.y, W:word.w, H:word.h}
        return result
    }
    
    static __OpenPdfDocument(IRandomAccessStream, Password:="") {
        PdfDocumentStatics := this.CreateClass("Windows.Data.Pdf.PdfDocument", this.IID_IPdfDocumentStatics)
        ComCall(8, PdfDocumentStatics, "ptr", IRandomAccessStream, "ptr*", PdfDocument:=ComValue(13, 0))
        this.WaitForAsync(&PdfDocument)
        return PdfDocument
    }

    static __ExtractNamedParameters(obj, params*) {
        local i := 0
        if !IsObject(obj) || Type(obj) != "Object"
            return 0
        Loop params.Length // 2 {
            name := params[++i], value := params[++i]
            if obj.HasProp(name)
                %value% := obj.%name%
        }
        return 1
    }

    static __ExtractTransformParameters(obj, &transform) {
        local scale := 1, grayscale := 0, invertcolors := 0, monochrome := 0, rotate := 0, flip := 0
        if IsObject(obj)
            this.__ExtractNamedParameters(obj, "scale", &scale, "grayscale", &grayscale, "invertcolors", &invertcolors, "monochrome", &monochrome, "rotate", &rotate, "flip", &flip, "transform", &transform)

        if IsSet(transform) && IsObject(transform) {
            for prop in ["scale", "grayscale", "invertcolors", "monochrome", "rotate", "flip"]
                if !transform.HasProp(prop)
                    transform.%prop% := %prop%
        } else
            transform := {scale:scale, grayscale:grayscale, invertcolors:invertcolors, monochrome:monochrome, rotate:rotate, flip:flip}
    
        transform.flip := transform.flip = "y" ? 1 : transform.flip = "x" ? 2 : transform.flip
    }

    static __DeleteProps(obj, props*) {
        if IsObject(obj)
            for prop in props
                obj.DeleteProp(prop)
    }

    static ConvertWinPos(X, Y, &outX, &outY, relativeFrom:="", relativeTo:="screen", winTitle?, winText?, excludeTitle?, excludeText?) {
        relativeFrom := relativeFrom || A_CoordModeMouse
        if relativeFrom = relativeTo {
            outX := X, outY := Y
            return
        }
        local hWnd := WinExist(winTitle?, winText?, excludeTitle?, excludeText?)

        switch relativeFrom, 0 {
            case "screen", "s":
                if relativeTo = "window" || relativeTo = "w" {
                    DllCall("user32\GetWindowRect", "Int", hWnd, "Ptr", RECT := Buffer(16))
                    outX := X-NumGet(RECT, 0, "Int"), outY := Y-NumGet(RECT, 4, "Int")
                } else { 
                    pt := Buffer(8), NumPut("int",X,pt), NumPut("int",Y,pt,4)
                    DllCall("ScreenToClient", "Int", hWnd, "Ptr", pt)
                    outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
                }
            case "window", "w":
                WinGetPos(&outX, &outY,,,hWnd)
                outX += X, outY += Y
                if relativeTo = "client" || relativeTo = "c" {
                    pt := Buffer(8), NumPut("int",outX,pt), NumPut("int",outY,pt,4)
                    DllCall("ScreenToClient", "Int", hWnd, "Ptr", pt)
                    outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
                }
            case "client", "c":
                pt := Buffer(8), NumPut("int",X,pt), NumPut("int",Y,pt,4)
                DllCall("ClientToScreen", "Int", hWnd, "Ptr", pt)
                outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
                if relativeTo = "window" || relativeTo = "w" {
                    DllCall("user32\GetWindowRect", "Int", hWnd, "Ptr", RECT := Buffer(16))
                    outX -= NumGet(RECT, 0, "Int"), outY -= NumGet(RECT, 4, "Int")
                }
        }
    }
}
