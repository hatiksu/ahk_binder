; Считаем только последовательность: номер → клик по закрытию → пустая панель.
class ReportDetector {
    __New() {
        this.Reset()
    }
    Reset() {
        this.id := '', this.stable := 0, this.pending := '', this.emptyFrames := 0
        this.button := 0, this.seen := 0
    }
    Observe(id, empty, button := 0, now := A_TickCount) {
        if this.pending != '' {
            if now - this.clicked > 5000 || (id != '' && id != this.pending) {
                this.pending := ''
            } else if empty {
                this.emptyFrames += 1
                if this.emptyFrames >= 2 {
                    closed := this.pending
                    this.Reset()
                    return closed
                }
            } else
                this.emptyFrames := 0
        }
        this.stable := id != '' && id = this.id ? this.stable + 1 : 1
        this.id := id, this.button := button, this.seen := now
        return ''
    }
    Click(x, y, now := A_TickCount) {
        b := this.button
        if this.id = '' || this.stable < 2 || now - this.seen > 800 || !IsObject(b)
            return
        if x >= b.x && y >= b.y && x <= b.x + b.w && y <= b.y + b.h {
            this.pending := this.id, this.clicked := now, this.emptyFrames := 0
        }
    }
    static Parse(result) {
        id := '', button := 0, empty := false
        for line in result.Lines {
            text := RegExReplace(line.Text, '\s+', ' ')
            if RegExMatch(text, 'i)^ОБРАЩЕНИЕ\s*[:.]?\s*(\d{6,12})\b', &m)
                id := m[1]
            if RegExMatch(text, 'i)^закрыть(?:\s|$)')
                button := {x: line.x - 10, y: line.y - 10, w: line.w + 80, h: line.h + 20}
            if RegExMatch(text, 'i)^выберите\s+обр')
                empty := true
        }
        return {id: id, button: button, empty: empty && id = ''}
    }
}
