class Clicker {
    __New(app) {
        this.app := app
        this.running := false
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
        app.Label(page, 298, 341, 800, 'От 50 до 60000 мс. 1000 мс = 1 секунда.', 10, 'A9A9B3')
        app.Button(page, 298, 407, 250, 'Запустить через 3 секунды', this.Start.Bind(this), true)
        app.Button(page, 568, 407, 180, 'Остановить', this.Stop.Bind(this))
        this.status := app.Label(page, 298, 475, 824, 'Кликер остановлен', 11, 'B8B8C0', , 48)
        app.Label(page, 298, 570, 824, 'После запуска переключись в игру и наведи курсор на нужное место. При переключении из игры кликер остановится. Чтобы продолжить, запусти его снова.', 10, 'A9A9B3', , 60)
        this.Choose(this.button)
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
        this.running := true, this.target := 0, this.count := 0
        this.status.Text := 'Переключись в игру. Запуск через 3 секунды.'
        SetTimer this.tickCallback, -3000
    }
    Stop(*) {
        SetTimer this.tickCallback, 0
        this.running := false
        this.status.Text := 'Кликер остановлен'
    }
    Tick() {
        if !this.running
            return
        if !this.target
            this.target := DllCall('GetForegroundWindow', 'ptr')
        if !this.app.context() || DllCall('GetForegroundWindow', 'ptr') != this.target {
            this.Stop()
            return
        }
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
