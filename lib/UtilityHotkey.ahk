class UtilityHotkey {
    static Conflict(owner, key) {
        if key = ''
            return ''
        app := owner.app
        for item in app.binds
            if item.key = key
                return 'Эта клавиша занята биндом.'
        for item in app.customOverlays
            if item.key = key
                return 'Эта клавиша занята оверлеем.'
        for other in [app.mass, app.clicker, app.entry]
            if other != owner && other.key = key
                return 'Эта клавиша уже назначена другой функции.'
        return ''
    }
    static Save(owner) {
        key := owner.keyField.Value
        conflict := this.Conflict(owner, key)
        if conflict != '' {
            owner.status.Text := conflict
            return
        }
        previous := owner.key
        owner.key := key
        try owner.Register()
        catch {
            owner.key := previous
            owner.Register()
            owner.status.Text := 'Не удалось назначить клавишу.'
            return
        }
        section := owner is Clicker ? 'Clicker' : 'MassPunishments'
        IniWrite key, owner.app.ini, section, 'Key'
        owner.status.Text := key = '' ? 'Клавиша убрана.' : 'Клавиша сохранена. Нажатие в игре запускает и останавливает.'
    }
    static Register(owner) {
        HotIf owner.app.context
        try {
            if owner.HasOwnProp('registeredKey') && owner.registeredKey != ''
                Hotkey owner.registeredKey, 'Off'
            owner.registeredKey := ''
            if owner.key != '' && this.Conflict(owner, owner.key) = '' {
                Hotkey owner.key, owner.Toggle.Bind(owner), 'On'
                owner.registeredKey := owner.key
            }
        } finally
            HotIf
    }
}
