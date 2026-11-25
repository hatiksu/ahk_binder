class Clicker {
    __New(app) {
        this.app := app
        this.running := false
        this.key := IniRead(app.ini, 'Clicker', 'Key', '')
        this.button := IniRead(app.ini, 'Clicker', 'Button', 'Left') = 'Right' ? 'Right' : 'Left'
        this.tickCallback := this.Tick.Bind(this)
    }
    Build() {
        app := this.app, page := 'Кликер'
        app.Card(page, 272, 102, 884, 611)
        app.Label(page, 298, 134, 810, 'Кнопка мыши', 13, , 700)
        this.left := app.Button(page, 298, 178, 200, 'Левая', this.Choose.Bind(this, 'Left'))
        this.right := app.Button(page, 514, 178, 200, 'Правая', this.Choose.Bind(this, 'Right'))
        app.Label(page, 298, 246, 600, 'Интервал между нажатиями, мс', 11)
        this.intervalField := app.RoundedInput(page, 298, 283, 240, 40, IniRead(app.ini, 'Clicker', 'Interval', '1000'))
        this.keyField := KeyPicker(app.window, 'x298 y407 w420 h40', this.key)
        app.pages[page].Push(this.keyField.control)
        app.Button(page, 738, 407, 210, 'Сохранить клавишу', this.SaveKey.Bind(this))
        this.status := app.Label(page, 298, 480, 824, 'Кликер остановлен', 11, 'B8B8C0', , 48)
        this.Choose(this.button)
        this.Register()
    }
    Choose(button, *) {
        this.button := button
        Theme.Select(this.left, button = 'Left')
        Theme.Select(this.right, button = 'Right')
        IniWrite button, this.app.ini, 'Clicker', 'Button'
    }
    static Interval(value) {
        if !RegExMatch(value, '^\d{2,5}$') || Integer(value) < 50 || Integer(value) > 60000
            throw ValueError('Укажи интервал от 50 до 60000 мс.')
        return Integer(value)
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
        try interval := Clicker.Interval(Trim(this.intervalField.Value))
        catch as err {
            this.status.Text := err.Message
            return
        }
        if this.app.mass.running || this.app.entry.running {
            this.status.Text := 'Дождись завершения отправки команд.'
            return
        }
        this.interval := interval, this.activeButton := this.button
        IniWrite interval, this.app.ini, 'Clicker', 'Interval'
        this.running := true, this.count := 0
        this.status.Text := 'Кликер запущен.'
        SetTimer this.tickCallback, -1
    }
    Stop(*) {
        SetTimer this.tickCallback, 0
        this.running := false
        this.status.Text := 'Кликер остановлен'
    }
    Tick() {
        if !this.running
            return
        try {
            SendEvent '{Click ' this.activeButton '}'
            this.count += 1
            if Mod(this.count, 10) = 1
                this.status.Text := 'Кликер работает. Интервал: ' this.interval ' мс.'
            SetTimer this.tickCallback, -this.interval
        } catch as err {
            this.Stop()
            this.status.Text := 'Кликер остановлен: ' err.Message
        }
    }
}
