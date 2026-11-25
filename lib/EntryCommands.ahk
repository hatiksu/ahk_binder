class EntryCommands {
    static commands := ['/hidecheatinfo', '/showcheats', '/dl', '/esp', '/templeader', '/chide', '/zzdebug', '/objdl', '/netstat', '/gm']
    static simpleCommands := ['/hidecheatinfo', '/showcheats', '/dl', '/chide', '/zzdebug', '/objdl', '/netstat', '/gm']
    __New(app) {
        this.app := app
        this.selected := Map()
        for command in EntryCommands.commands
            this.selected[command] := IniRead(app.ini, 'EntryCommands', SubStr(command, 2), command = '/hidecheatinfo' || command = '/esp' || command = '/chide' ? '1' : '0') = '1'
        this.trigger := IniRead(app.ini, 'EntryCommands', 'Trigger', '.вход')
        this.key := IniRead(app.ini, 'EntryCommands', 'Key', '')
        this.running := false
        this.registeredTrigger := '', this.registeredKey := ''
    }
    Build() {
        app := this.app, page := 'Команды при входе'
        app.pages[page] := []
        app.Card(page, 272, 102, 884, 611)
        app.Button(page, 298, 122, 150, '← На главную', (*) => app.ShowPage('Основное'))
        app.Label(page, 298, 178, 810, 'Отметь команды для запуска одним биндом', 14, , 700)
        this.buttons := Map()
        for index, command in EntryCommands.simpleCommands {
            x := 298 + Mod(index - 1, 3) * 280
            y := 221 + ((index - 1) // 3) * 48
            this.buttons[command] := app.Button(page, x, y, 264, command, this.Toggle.Bind(this, command), false, 38)
        }
        app.Label(page, 298, 383, 240, 'Тип /esp', 10, 'B8B8C0')
        this.espButtons := Map()
        loop 4 {
            n := A_Index - 1
            this.espButtons[n] := app.Button(page, 298 + n * 66, 411, 60, n = 0 ? 'Выкл.' : n, this.ChooseESP.Bind(this, n), false, 38)
        }
        app.Label(page, 578, 383, 500, 'Фракция для /templeader', 10, 'B8B8C0')
        this.faction := app.Button(page, 578, 411, 544, '', this.ChooseFaction.Bind(this), false, 38)
        app.Label(page, 298, 480, 320, 'Триггер в открытом чате', 10, 'B8B8C0')
        this.triggerField := app.RoundedInput(page, 298, 510, 300, 40, this.trigger)
        app.Label(page, 638, 480, 450, 'Сочетание клавиш (необязательно)', 10, 'B8B8C0')
        this.keyField := KeyPicker(app.window, 'x638 y510 w484 h40', this.key)
        app.pages[page].Push(this.keyField.control)
        app.Button(page, 298, 578, 220, 'Сохранить бинд', this.Save.Bind(this), true)
        this.status := app.Label(page, 538, 586, 590, '', 9, 'B8B8C0')
        app.Label(page, 298, 651, 820, 'Введи триггер и пробел в чате игры или нажми назначенные клавиши. При смене окна выполнение остановится.', 9, '8F8F9B', , 40)
        this.Refresh()
    }
    Refresh() {
        if !this.HasOwnProp('buttons')
            return
        for command, button in this.buttons {
            label := (this.selected[command] ? '● ' : '○ ') command
            if button.Text != label
                button.Text := label
            Theme.Select(button, this.selected[command])
        }
        for n, button in this.espButtons
            Theme.Select(button, this.selected['/esp'] ? n = this.app.esp : n = 0)
        id := this.app.GetFactionID()
        label := !this.selected['/templeader'] ? 'Не использовать ⌄' : (id = '' ? 'Выбрать фракцию ⌄' : this.app.faction ' /templeader ' id ' ⌄')
        if this.faction.Text != label
            this.faction.Text := label
        Theme.Select(this.faction, this.selected['/templeader'])
    }
    Toggle(command, *) {
        this.selected[command] := !this.selected[command]
        IniWrite this.selected[command] ? 1 : 0, this.app.ini, 'EntryCommands', SubStr(command, 2)
        this.Refresh()
    }
    ChooseESP(n, *) {
        this.selected['/esp'] := n != 0
        IniWrite n != 0 ? 1 : 0, this.app.ini, 'EntryCommands', 'esp'
        if n != 0
            this.app.SetESP(n)
        this.Refresh()
    }
    ChooseFaction(*) {
        choices := ['Не использовать']
        for name in BinderFeatures.factionIDs
            choices.Push(name)
        selected := DarkDialog.Choice('Фракция для /templeader', choices, this.selected['/templeader'] ? this.app.faction : 'Не использовать')
        if selected = ''
            return
        this.SelectFaction(selected)
        this.Refresh()
    }
    SelectFaction(name) {
        this.selected['/templeader'] := name != 'Не использовать'
        IniWrite this.selected['/templeader'] ? 1 : 0, this.app.ini, 'EntryCommands', 'templeader'
        if this.selected['/templeader']
            this.app.SetFaction(name)
        this.Refresh()
    }
    Conflict(key, trigger) {
        for item in this.app.binds {
            if key != '' && item.key = key
                return 'Эта клавиша уже занята другим биндом.'
        }
        for item in this.app.customOverlays {
            if key != '' && item.key = key
                return 'Эта клавиша уже занята оверлеем.'
        }
        for item in this.app.config.entries {
            if item.key = trigger
                return 'Такой триггер уже есть в конфиге.'
        }
        return ''
    }
    Save(*) {
        trigger := Trim(this.triggerField.Value), key := this.keyField.Value
        if trigger = '' || RegExMatch(trigger, '[\s:]') {
            this.status.Text := 'Триггер должен быть без пробелов и двоеточий.'
            return
        }
        conflict := this.Conflict(key, trigger)
        if conflict != '' {
            this.status.Text := conflict
            return
        }
        oldTrigger := this.trigger, oldKey := this.key
        this.trigger := trigger, this.key := key
        try this.Register()
        catch {
            this.trigger := oldTrigger, this.key := oldKey
            this.Register()
            this.status.Text := 'Не удалось назначить сочетание клавиш.'
            return
        }
        IniWrite this.trigger, this.app.ini, 'EntryCommands', 'Trigger'
        IniWrite this.key, this.app.ini, 'EntryCommands', 'Key'
        this.status.Text := 'Сохранено. Запуск: ' this.trigger ' + пробел'
    }
    Register() {
        HotIf this.app.context
        if this.registeredTrigger != ''
            Hotstring this.registeredTrigger, , 'Off'
        if this.registeredKey != ''
            Hotkey this.registeredKey, 'Off'
        this.registeredTrigger := '', this.registeredKey := ''
        try {
            if this.Conflict(this.key, this.trigger) != ''
                return
            name := ':?XOZ:' this.trigger
            Hotstring name, this.Run.Bind(this, true), 'On'
            this.registeredTrigger := name
            if this.key != '' {
                Hotkey this.key, this.Run.Bind(this, false), 'On'
                this.registeredKey := this.key
            }
        } finally
            HotIf
    }
    Queue() {
        commands := []
        for command in EntryCommands.commands {
            if !this.selected[command]
                continue
            if command = '/esp'
                command .= ' ' this.app.esp
            else if command = '/templeader' {
                id := this.app.GetFactionID()
                if id = ''
                    throw ValueError('Выбери фракцию для /templeader.')
                command .= ' ' id
            }
            commands.Push(command)
        }
        return commands
    }
    Active(target) {
        return WinExist('A') = target && this.app.context()
    }
    Run(fromChat := false, *) {
        if this.running || this.app.mass.running || this.app.clicker.running || !this.app.context()
            return
        try commands := this.Queue()
        catch as err {
            this.app.Notify(err.Message)
            return
        }
        target := WinExist('A')
        Hotstring 'Reset'
        this.running := true
        try {
            for modifier in ['Ctrl', 'Alt', 'Shift', 'LWin', 'RWin']
                KeyWait modifier
            for index, command in commands {
                if !this.Active(target)
                    return
                if index != 1 || !fromChat {
                    SendEvent '{' this.app.chatKey '}'
                    Sleep this.app.chatDelay
                }
                if !this.Active(target)
                    return
                if !TextInput.Put(command, target)
                    return
                Sleep 40
                if !this.Active(target)
                    return
                SendEvent '{Enter}'
                Sleep 350
            }
        } finally
            this.running := false
    }
}
