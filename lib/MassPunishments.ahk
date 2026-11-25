class MassPunishments {
    __New(app) {
        this.app := app
        this.running := false
        this.serial := 0
        this.draft := []
        this.key := IniRead(app.ini, 'MassPunishments', 'Key', '')
        this.tickCallback := this.Tick.Bind(this)
    }
    Build() {
        app := this.app, page := 'Массовые наказания'
        app.Card(page, 272, 102, 884, 611)
        app.Label(page, 298, 122, 810, 'Добавить наказания', 13, , 700)
        app.Label(page, 298, 153, 810, 'Вводи готовые команды. Каждое наказание с новой строки, например /mute 123 30 Причина.', 10, 'A9A9B3')
        this.input := app.window.AddEdit('x298 y187 w610 h80 Multi WantReturn VScroll Background252527 cEEEEF2 -E0x200')
        Theme.Dark(this.input)
        app.pages[page].Push(this.input)
        app.Button(page, 926, 187, 196, 'Добавить в список', this.Add.Bind(this))
        this.list := app.Add(page, 'ListView', 'x298 y288 w824 h220 -Multi', ['№', 'Команда'])
        app.Columns(this.list, [60, 740])
        app.Button(page, 298, 523, 180, 'Удалить строку', this.Remove.Bind(this))
        app.Button(page, 494, 523, 180, 'Очистить список', this.Clear.Bind(this))
        app.Button(page, 690, 523, 180, 'Остановить', this.Stop.Bind(this))
        this.keyField := KeyPicker(app.window, 'x298 y578 w420 h40', this.key)
        app.pages[page].Push(this.keyField.control)
        app.Button(page, 738, 578, 210, 'Сохранить клавишу', this.SaveKey.Bind(this))
        this.status := app.Label(page, 298, 636, 824, 'Назначь клавишу. В игре она запускает и останавливает выдачу.', 10, 'B8B8C0', , 52)
        this.Register()
    }
    static Queue(text) {
        queue := []
        for line in StrSplit(text, '`n', '`r') {
            line := Trim(line)
            if line = ''
                continue
            if !RegExMatch(line, '^/[A-Za-z][A-Za-z0-9_]*\s+\S') || RegExMatch(line, '[{}\x00-\x1F]') || StrLen(line) > 500
                throw ValueError('Введи готовую команду с аргументами без маркеров: ' SubStr(line, 1, 60))
            queue.Push(line)
            if queue.Length > 500
                throw ValueError('За один запуск можно добавить до 500 команд.')
        }
        if !queue.Length
            throw ValueError('Введи хотя бы одну команду.')
        return queue
    }
    Add(*) {
        if this.running
            return
        try {
            commands := MassPunishments.Queue(this.input.Value)
            if this.draft.Length + commands.Length > 500
                throw ValueError('В списке может быть до 500 команд.')
            this.draft.Push(commands*)
            this.input.Value := ''
            this.Render()
        } catch as err
            this.status.Text := err.Message
    }
    Render() {
        this.list.Delete()
        for index, command in this.draft
            this.list.Add('', index, command)
        this.status.Text := 'В очереди: ' this.draft.Length '. Выдача по порядку, раз в секунду. Чат перед запуском должен быть закрыт.'
    }
    Remove(*) {
        if this.running
            return
        row := this.list.GetNext()
        if row {
            this.draft.RemoveAt(row)
            this.Render()
        }
    }
    Clear(*) {
        if this.running
            return
        this.draft := []
        this.Render()
    }
    SaveKey(*) {
        UtilityHotkey.Save(this)
    }
    Register() {
        UtilityHotkey.Register(this)
    }
    Toggle(*) {
        if this.running
            this.Stop()
        else {
            for modifier in ['Ctrl', 'Alt', 'Shift', 'LWin', 'RWin']
                KeyWait modifier
            this.Start()
        }
        if this.key != ''
            KeyWait RegExReplace(this.key, '^[~*$<>^!+#]+')
    }
    Start(*) {
        if this.running
            return
        if !this.draft.Length {
            this.status.Text := 'Добавь команды в список.'
            return
        }
        if this.app.entry.running || this.app.clicker.running {
            this.status.Text := 'Останови кликер и дождись завершения команд при входе.'
            return
        }
        if !this.app.context() {
            this.status.Text := 'Запуск доступен только в окне игры.'
            return
        }
        this.queue := this.draft.Clone(), this.sent := 0
        this.target := DllCall('GetForegroundWindow', 'ptr')
        this.serial += 1
        this.running := true
        this.status.Text := 'Выдача запущена.'
        SetTimer this.tickCallback, -1
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
