; Контурные векторные иконки. Отрисовка GDI+ с антиалиасингом, без шрифтов и PNG.
class Icons {
    static token := 0
    static cache := Map()
    static prefixes := Map('⌂', 'home', '▱', 'layers', '⌨', 'keyboard', 'ϟ', 'zap', '▣', 'folder',
        '⚙', 'settings', '▤', 'history', '↻', 'refresh', '◉', 'discord', 'ⓘ', 'help', '↗', 'upload',
        '↓', 'download', '↑', 'upload', '+', 'plus', '−', 'minus', '×', 'close', '←', 'back',
        '✥', 'move', '✓', 'check', '⌁', 'folder', '☷', 'sliders', '✦', 'sparkles', '●', 'check-circle', '○', 'circle')

    static Init() {
        if this.token
            return
        input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut('uint', 1, input)
        status := DllCall('gdiplus\GdiplusStartup', 'ptr*', &token := 0, 'ptr', input, 'ptr', 0)
        if status
            throw Error('Не удалось загрузить векторные иконки')
        this.token := token
        ; GDI+ остаётся загруженной до завершения процесса: окна могут получать
        ; WM_PAINT во время закрытия, после выполнения обработчиков OnExit.
    }

    static Decode(text) {
        if this.cache.Has(text)
            return this.cache[text]
        result := {name: '', label: text, trailing: false}
        if text = 'H'
            result := {name: 'brand', label: '', trailing: false}
        else if RegExMatch(text, '^●\s+(.+?)\s+⌄$', &profile)
            result := {name: 'user', label: profile[1], trailing: true}
        else if this.prefixes.Has(SubStr(text, 1, 1)) {
            result.name := this.prefixes[SubStr(text, 1, 1)]
            result.label := Trim(SubStr(text, 2))
        } else {
            named := Map('Изменить', 'pencil', 'Удалить', 'trash', 'Сохранить', 'check', 'Сохранить настройки', 'check',
                'Диагностика конфига', 'search', 'Открыть папку профиля', 'folder', 'К репортам', 'reports',
                'Показать / скрыть', 'eye', 'Обнулить день', 'refresh', 'Выбрать…', 'folder', 'Понятно', 'check')
            if named.Has(text)
                result.name := named[text]
        }
        this.cache[text] := result
        return result
    }

    static Draw(dc, name, x, y, size, color := 'B7B4C7') {
        this.Init()
        DllCall('gdiplus\GdipCreateFromHDC', 'ptr', dc, 'ptr*', &graphics := 0)
        DllCall('gdiplus\GdipSetSmoothingMode', 'ptr', graphics, 'int', 4)
        DllCall('gdiplus\GdipTranslateWorldTransform', 'ptr', graphics, 'float', x, 'float', y, 'int', 0)
        DllCall('gdiplus\GdipScaleWorldTransform', 'ptr', graphics, 'float', size / 24, 'float', size / 24, 'int', 0)
        DllCall('gdiplus\GdipCreatePen1', 'uint', 0xFF000000 | Integer('0x' color), 'float', 1.7, 'int', 2, 'ptr*', &pen := 0)
        DllCall('gdiplus\GdipSetPenLineCap197819', 'ptr', pen, 'int', 2, 'int', 2, 'int', 0)
        DllCall('gdiplus\GdipSetPenLineJoin', 'ptr', pen, 'int', 2)
        try {
            switch name {
                case 'brand':
                    DllCall('gdiplus\GdipSetPenWidth', 'ptr', pen, 'float', 3)
                    this.Line(graphics, pen, 7, 4, 7, 20)
                    this.Line(graphics, pen, 17, 4, 17, 20)
                    this.Line(graphics, pen, 7, 12, 17, 12)
                case 'home':
                    this.Lines(graphics, pen, [3,10, 12,3, 21,10])
                    this.Lines(graphics, pen, [5,9, 5,21, 10,21, 10,14, 14,14, 14,21, 19,21, 19,9])
                case 'layers':
                    this.Lines(graphics, pen, [3,8, 12,3, 21,8, 12,13, 3,8])
                    this.Lines(graphics, pen, [3,12, 12,17, 21,12])
                    this.Lines(graphics, pen, [3,16, 12,21, 21,16])
                case 'keyboard':
                    this.Box(graphics, pen, 2, 5, 20, 14)
                    for row in [9, 12] {
                        for column in [6, 10, 14, 18]
                            this.Line(graphics, pen, column, row, column + 0.2, row)
                    }
                    this.Line(graphics, pen, 7, 16, 17, 16)
                case 'zap':
                    this.Lines(graphics, pen, [14,2, 4,14, 11,14, 10,22, 20,10, 13,10, 14,2])
                case 'reports', 'history':
                    this.Box(graphics, pen, 5, 3, 14, 18)
                    this.Line(graphics, pen, 8, 8, 16, 8)
                    this.Line(graphics, pen, 8, 12, 16, 12)
                    this.Line(graphics, pen, 8, 16, name = 'reports' ? 13 : 16, 16)
                case 'settings':
                    points := []
                    loop 24 {
                        angle := (A_Index - 1) * 3.14159265359 / 12
                        radius := Mod(A_Index - 1, 4) < 2 ? 10 : 7.8
                        points.Push(12 + Cos(angle) * radius, 12 + Sin(angle) * radius)
                    }
                    points.Push(points[1], points[2])
                    this.Lines(graphics, pen, points)
                    this.Circle(graphics, pen, 8.7, 8.7, 6.6)
                case 'folder':
                    this.Lines(graphics, pen, [3,8, 3,5, 9,5, 12,8, 21,8, 21,20, 3,20, 3,8, 21,8])
                case 'upload', 'download':
                    this.Lines(graphics, pen, [4,16, 4,21, 20,21, 20,16])
                    this.Line(graphics, pen, 12, 3, 12, 15)
                    this.Lines(graphics, pen, name = 'upload' ? [7,8, 12,3, 17,8] : [7,10, 12,15, 17,10])
                case 'refresh':
                    DllCall('gdiplus\GdipDrawArc', 'ptr', graphics, 'ptr', pen, 'float', 4, 'float', 4, 'float', 16, 'float', 16, 'float', 42, 'float', 280)
                    this.Lines(graphics, pen, [20,4, 20,10, 14,10])
                case 'discord':
                    this.Lines(graphics, pen, [8,5, 5,6, 2.5,17, 7,19, 9,16])
                    this.Lines(graphics, pen, [16,5, 19,6, 21.5,17, 17,19, 15,16])
                    this.Lines(graphics, pen, [5,7, 9,6, 15,6, 19,7])
                    this.Lines(graphics, pen, [7,16, 10,17, 14,17, 17,16])
                    this.Circle(graphics, pen, 7, 10, 2.5)
                    this.Circle(graphics, pen, 14.5, 10, 2.5)
                case 'help':
                    this.Circle(graphics, pen, 3, 3, 18)
                    DllCall('gdiplus\GdipDrawBezier', 'ptr', graphics, 'ptr', pen, 'float', 8.5, 'float', 8.5, 'float', 9, 'float', 3.8, 'float', 18, 'float', 7, 'float', 12, 'float', 12)
                    this.Line(graphics, pen, 12, 12, 12, 13)
                    this.Line(graphics, pen, 12, 17, 12.1, 17)
                case 'plus':
                    this.Line(graphics, pen, 5, 12, 19, 12)
                    this.Line(graphics, pen, 12, 5, 12, 19)
                case 'minus': this.Line(graphics, pen, 5, 12, 19, 12)
                case 'close':
                    this.Line(graphics, pen, 6, 6, 18, 18)
                    this.Line(graphics, pen, 18, 6, 6, 18)
                case 'check': this.Lines(graphics, pen, [4,12, 9,17, 20,6])
                case 'back':
                    this.Line(graphics, pen, 4, 12, 21, 12)
                    this.Lines(graphics, pen, [10,6, 4,12, 10,18])
                case 'chevron': this.Lines(graphics, pen, [6,9, 12,15, 18,9])
                case 'move':
                    this.Line(graphics, pen, 12, 3, 12, 21)
                    this.Line(graphics, pen, 3, 12, 21, 12)
                    for points in [[9,6,12,3,15,6], [9,18,12,21,15,18], [6,9,3,12,6,15], [18,9,21,12,18,15]]
                        this.Lines(graphics, pen, points)
                case 'pencil':
                    this.Lines(graphics, pen, [4,20, 5,15, 17,3, 21,7, 9,19, 4,20])
                    this.Line(graphics, pen, 14, 6, 18, 10)
                case 'trash':
                    this.Line(graphics, pen, 3, 6, 21, 6)
                    this.Lines(graphics, pen, [8,6,8,3,16,3,16,6])
                    this.Lines(graphics, pen, [5,6,6,21,18,21,19,6])
                    this.Line(graphics, pen, 10, 10, 10, 17)
                    this.Line(graphics, pen, 14, 10, 14, 17)
                case 'search':
                    this.Circle(graphics, pen, 3, 3, 13)
                    this.Line(graphics, pen, 15, 15, 21, 21)
                case 'user':
                    this.Circle(graphics, pen, 8, 3, 8)
                    DllCall('gdiplus\GdipDrawArc', 'ptr', graphics, 'ptr', pen, 'float', 4, 'float', 14, 'float', 16, 'float', 14, 'float', 180, 'float', 180)
                case 'eye':
                    this.Lines(graphics, pen, [2,12,6,7,12,5,18,7,22,12,18,17,12,19,6,17,2,12])
                    this.Circle(graphics, pen, 9, 9, 6)
                case 'sliders':
                    for x in [5,12,19]
                        this.Line(graphics, pen, x, 3, x, 21)
                    this.Box(graphics, pen, 2.5, 7, 5, 4)
                    this.Box(graphics, pen, 9.5, 14, 5, 4)
                    this.Box(graphics, pen, 16.5, 5, 5, 4)
                case 'sparkles':
                    this.Lines(graphics, pen, [12,2,15,9,22,12,15,15,12,22,9,15,2,12,9,9,12,2])
                case 'circle', 'check-circle':
                    this.Circle(graphics, pen, 3, 3, 18)
                    if name = 'check-circle'
                        this.Lines(graphics, pen, [7,12,11,16,17,8])
            }
        } finally {
            DllCall('gdiplus\GdipDeletePen', 'ptr', pen)
            DllCall('gdiplus\GdipDeleteGraphics', 'ptr', graphics)
        }
    }

    static Line(g, pen, x1, y1, x2, y2) {
        DllCall('gdiplus\GdipDrawLine', 'ptr', g, 'ptr', pen, 'float', x1, 'float', y1, 'float', x2, 'float', y2)
    }
    static Lines(g, pen, points) {
        loop points.Length // 2 - 1 {
            i := (A_Index - 1) * 2 + 1
            this.Line(g, pen, points[i], points[i + 1], points[i + 2], points[i + 3])
        }
    }
    static Circle(g, pen, x, y, size) {
        DllCall('gdiplus\GdipDrawEllipse', 'ptr', g, 'ptr', pen, 'float', x, 'float', y, 'float', size, 'float', size)
    }
    static Box(g, pen, x, y, width, height) {
        DllCall('gdiplus\GdipDrawRectangle', 'ptr', g, 'ptr', pen, 'float', x, 'float', y, 'float', width, 'float', height)
    }
}
