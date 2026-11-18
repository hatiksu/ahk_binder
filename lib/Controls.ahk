; Выбор клавиш без светлого системного поля Hotkey.
class KeyPicker {
    __New(g, options, value := '') {
        this.control := Theme.Button(g, options, '', '252527')
        this.active := false
        this.key := value
        Theme.items[this.control.Hwnd].keyPicker := this
        this.control.OnEvent('Click', (*) => this.Capture())
        this.Update()
    }
    Value {
        get => this.key
        set {
            this.key := value
            this.Update()
        }
    }
    Update() {
        this.control.Text := this.key = '' ? 'Нажми, чтобы назначить клавиши' : KeyLabel(this.key)
    }
    Capture() {
        this.active := true
        this.control.Text := 'Нажми сочетание… · Esc - отмена'
        Theme.Select(this.control, true)
        this.control.Focus()
    }
    Cancel() {
        this.active := false
        Theme.Select(this.control, false)
        this.Update()
    }
    KeyDown(vk, scan) {
        if vk = 0x1B {
            this.Cancel()
            return
        }
        if vk = 0x10 || vk = 0x11 || vk = 0x12 || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C
            return
        modifiers := ''
        for pair in [['Ctrl', '^'], ['Alt', '!'], ['Shift', '+'], ['LWin', '#'], ['RWin', '#']] {
            if GetKeyState(pair[1], 'P') && !InStr(modifiers, pair[2])
                modifiers .= pair[2]
        }
        if modifiers = '' && (vk = 8 || vk = 0x2E)
            this.key := ''
        else {
            keyName := GetKeyName('vk' Format('{:02X}', vk) (scan ? 'sc' Format('{:03X}', scan) : ''))
            if keyName = ''
                return
            this.key := modifiers keyName
        }
        this.Cancel()
    }
}

KeyLabel(key) {
    if key = ''
        return 'Не назначено'
    label := ''
    for pair in [['^', 'Ctrl'], ['!', 'Alt'], ['+', 'Shift'], ['#', 'Win']] {
        if InStr(key, pair[1])
            label .= pair[2] ' + '
    }
    name := RegExReplace(key, '[\^!+#<>~*$]')
    if StrLen(name) = 1
        name := StrUpper(name)
    return label name
}

; Тёмная кнопка-фильтр вместо белого ComboBox.
class CategoryPicker {
    __New(g, options, choices, changed) {
        this.control := Theme.Button(g, options, '', '252527')
        this.choices := choices
        this.index := 1
        this.changed := changed
        this.control.OnEvent('Click', (*) => this.Open())
        this.Choose(1)
    }
    Text {
        get => this.choices.Length ? this.choices[this.index] : ''
    }
    Value {
        get => this.index
    }
    Delete() {
        this.choices := []
        this.index := 1
    }
    Add(choices) {
        this.choices := choices
    }
    Choose(index) {
        this.index := index
        this.control.Text := this.Text ' ⌄'
    }
    Select(index, *) {
        this.Choose(index)
        this.changed.Call()
    }
    Open() {
        selected := DarkDialog.Choice('Категории триггеров', this.choices, this.Text)
        for index, label in this.choices {
            if label = selected {
                this.Select(index)
                return
            }
        }
    }
}
