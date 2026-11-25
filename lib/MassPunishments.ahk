class MassPunishments {
    __New(app) {
        this.app := app
        this.running := false
        this.serial := 0
        this.tickCallback := this.Tick.Bind(this)
    }
    Build() {
        app := this.app, page := 'Массовые наказания'
        app.Card(page, 272, 102, 884, 611)
        app.Label(page, 298, 124, 810, 'Список ID', 13, , 700)
        app.Label(page, 298, 155, 810, 'Разделяй ID пробелами, запятыми или новой строкой. Повторы будут убраны.', 10, 'A9A9B3')
        this.ids := app.window.AddEdit('x298 y190 w250 h310 Multi WantReturn VScroll Background252527 cEEEEF2 -E0x200')
        Theme.Dark(this.ids)
        app.pages[page].Push(this.ids)
        app.Label(page, 574, 192, 544, 'Команда для каждого игрока', 12, , 600)
        this.template := app.RoundedInput(page, 574, 231, 548, 40, IniRead(app.ini, 'MassPunishments', 'Template', '/mute {id} 30 Причина'))
        app.Label(page, 574, 286, 548, 'Вместо {id} подставится ID из списка. Укажи срок и причину в самой команде.', 10, 'A9A9B3', , 46)
        app.Button(page, 574, 347, 220, 'Предпросмотр', this.Preview.Bind(this))
        this.previewField := app.window.AddEdit('x574 y405 w548 h95 Multi ReadOnly VScroll Background252527 cEEEEF2 -E0x200')
        Theme.Dark(this.previewField)
        app.pages[page].Push(this.previewField)
        app.Button(page, 298, 530, 250, 'Запустить через 3 секунды', this.Start.Bind(this), true)
        app.Button(page, 574, 530, 170, 'Остановить', this.Stop.Bind(this))
        this.status := app.Label(page, 298, 587, 824, 'Готово к запуску', 10, 'B8B8C0', , 38)
        app.Label(page, 298, 644, 824, 'После запуска переключись в игру с закрытым чатом. При смене окна отправка остановится. Счётчик показывает отправку, а не результат выдачи.', 10, '8F8F9B', , 48)
    }
    static Queue(ids, template) {
        template := Trim(template)
        if !RegExMatch(template, '^/[A-Za-z][A-Za-z0-9_]*\s') || InStr(template, '`n') || InStr(template, '`r')
            throw ValueError('Укажи одну команду, начиная с /.')
        if StrSplit(template, '{id}').Length != 2 || RegExMatch(StrReplace(template, '{id}'), '[{}]')
            throw ValueError('В команде должно быть ровно одно поле {id}, без других маркеров.')
        if StrLen(template) > 500
            throw ValueError('Команда слишком длинная.')
        if RegExMatch(ids, '[^0-9\s,;]')
            throw ValueError('В списке должны быть только числовые ID и разделители.')
        queue := [], seen := Map()
        for id in StrSplit(RegExReplace(Trim(ids), '[\s,;]+', ' '), ' ') {
            if id = ''
                continue
            if StrLen(id) > 10
                throw ValueError('Слишком длинный ID: ' id)
            id := Integer(id)
            if seen.Has(id)
                continue
            seen[id] := true
            queue.Push(StrReplace(template, '{id}', id))
            if queue.Length > 500
                throw ValueError('За один запуск можно отправить до 500 команд.')
        }
        if !queue.Length
            throw ValueError('Добавь ID игроков в список.')
        return queue
    }
    Preview(*) {
        try {
            queue := MassPunishments.Queue(this.ids.Value, this.template.Value)
            text := ''
            for index, command in queue {
                if index > 10
                    break
                text .= (index = 1 ? '' : '`r`n') command
            }
            this.previewField.Value := text
            this.status.Text := 'Команд: ' queue.Length '. Интервал: 1 секунда. В предпросмотре первые 10.'
            return queue
        } catch as err {
            this.previewField.Value := ''
            this.status.Text := err.Message
            return false
        }
    }
    Start(*) {
        if this.running {
            this.status.Text := 'Список уже выполняется.'
            return
        }
        queue := this.Preview()
        if !queue
            return
        if this.app.entry.running || this.app.clicker.running {
            this.status.Text := 'Останови кликер и дождись завершения команд при входе.'
            return
        }
        IniWrite Trim(this.template.Value), this.app.ini, 'MassPunishments', 'Template'
        this.queue := queue, this.sent := 0, this.target := 0
        this.serial += 1
        this.running := true
        this.status.Text := 'Переключись в игру. Отправка начнётся через 3 секунды.'
        SetTimer this.tickCallback, -3000
    }
    Stop(*) {
        this.serial += 1
        SetTimer this.tickCallback, 0
        if this.running
            this.status.Text := 'Остановлено. Отправлено: ' this.sent ' из ' this.queue.Length '.'
        this.running := false
    }
    Active(serial) {
        return this.running && this.serial = serial && this.app.context() && DllCall('GetForegroundWindow', 'ptr') = this.target
    }
    Cancel(serial) {
        if serial = this.serial
            this.Stop()
    }
    Tick() {
        if !this.running
            return
        serial := this.serial
        if !this.target
            this.target := DllCall('GetForegroundWindow', 'ptr')
        try {
            if !this.Active(serial) {
                this.Cancel(serial)
                return
            }
            SendEvent '{' this.app.chatKey '}'
            Sleep this.app.chatDelay
            if !this.Active(serial) {
                this.Cancel(serial)
                return
            }
            if !TextInput.Put(this.queue[this.sent + 1], this.target) || !this.Active(serial) {
                this.Cancel(serial)
                return
            }
            SendEvent '{Enter}'
            this.sent += 1
            this.status.Text := 'Отправлено: ' this.sent ' из ' this.queue.Length '.'
            if this.sent = this.queue.Length {
                this.running := false
                this.status.Text := 'Отправка завершена. Команд: ' this.sent '.'
            } else
                SetTimer this.tickCallback, -1000
        } catch as err {
            this.Cancel(serial)
            this.status.Text := 'Отправка остановлена: ' err.Message
        }
    }
}
