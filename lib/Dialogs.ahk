; Общие тёмные диалоги: сообщения, подтверждения, ввод и выбор файлов.
class DarkDialog {
    static last := 0

    static Frame(title, width := 620) {
        owner := DllCall('GetActiveWindow', 'ptr')
        g := Gui('-Caption +Border' (owner ? ' +Owner' owner : ''), title)
        Theme.Window(g)
        g.MarginX := 24, g.MarginY := 22
        heading := g.AddText('x24 y23 w' (width - 88) ' h30 BackgroundTrans', title)
        heading.SetFont('s15 w600')
        heading.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        close := Theme.Button(g, 'x' (width - 51) ' y22 w27 h27 -Tabstop', '×', '252527')
        return {gui: g, owner: owner, close: close, width: width, buttons: []}
    }

    static Wait(frame, height, cancel := 'Cancel') {
        result := cancel
        frame.finish := Finish
        this.last := frame
        frame.close.OnEvent('Click', (*) => Finish(cancel))
        frame.gui.OnEvent('Close', (*) => Finish(cancel))
        frame.gui.OnEvent('Escape', (*) => Finish(cancel))
        if frame.owner
            DllCall('EnableWindow', 'ptr', frame.owner, 'int', false)
        frame.gui.Show('w' frame.width ' h' height (A_Args.Length && A_Args[1] = '--check' ? ' Hide' : ''))
        WinWaitClose frame.gui
        if frame.owner {
            DllCall('EnableWindow', 'ptr', frame.owner, 'int', true)
            DllCall('SetActiveWindow', 'ptr', frame.owner)
        }
        return result
        Finish(value, *) {
            result := value
            frame.gui.Destroy()
        }
    }

    static Window(title, width := 700, onClose := 0) {
        frame := this.Frame(title, width)
        frame.close.OnEvent('Click', Close)
        frame.gui.OnEvent('Close', Close)
        frame.gui.OnEvent('Escape', Close)
        ; Явная точка начала содержимого, чтобы оно не наследовало X кнопки закрытия.
        frame.gui.AddText('x24 y56 w1 h1 Hidden', '')
        return frame.gui
        Close(*) {
            if IsObject(onClose)
                onClose.Call()
            frame.gui.Destroy()
        }
    }

    static Message(text, title := 'Binder by Hatiksu', options := 'OK') {
        frame := this.Frame(title)
        lines := Max(2, Ceil(StrLen(text) / 65) + StrSplit(text, '`n').Length)
        bodyHeight := Min(310, Max(70, lines * 22))
        frame.gui.AddText('x24 y78 w572 h' bodyHeight ' cC8C8D3 BackgroundTrans', text)
        choices := options = 'YesNoCancel' ? [['Заменить', 'Yes'], ['Объединить', 'No'], ['Отмена', 'Cancel']] :
            options = 'YesNo' ? [['Да', 'Yes'], ['Нет', 'No']] : [['Понятно', 'OK']]
        for index, choice in choices {
            button := Theme.Button(frame.gui, 'x' (620 - 24 - (choices.Length - index + 1) * 148) ' y' (bodyHeight + 103) ' w136 h38', choice[1], index = 1 ? '765DFF' : '303033')
            button.OnEvent('Click', Complete.Bind(choice[2]))
            frame.buttons.Push(button)
        }
        return this.Wait(frame, bodyHeight + 166, options = 'YesNo' ? 'No' : 'Cancel')
        Complete(value, *) {
            frame.finish.Call(value)
        }
    }

    static Prompt(text, title := 'Новый профиль', options := '', initial := '') {
        frame := this.Frame(title)
        frame.gui.AddText('x24 y78 w572 h56 cB0B0BD BackgroundTrans', text)
        input := frame.gui.AddEdit('x24 y142 w572 h34 Background171719 cEEEEF2 -Multi -VScroll', initial)
        Theme.SingleLine(input)
        frame.input := input
        for index, choice in [['Сохранить', 'OK'], ['Отмена', 'Cancel']] {
            button := Theme.Button(frame.gui, 'x' (308 + (index - 1) * 148) ' y203 w140 h38', choice[1], index = 1 ? '765DFF' : '303033')
            button.OnEvent('Click', Complete.Bind(choice[2]))
            frame.buttons.Push(button)
        }
        value := initial
        result := this.Wait(frame, 267)
        return {Result: result, Value: value}
        Complete(status, *) {
            value := input.Value
            frame.finish.Call(status)
        }
    }

    static File(mode := 1, initial := '', title := 'Выбор файла', filter := '') {
        saving := InStr(mode, 'S') > 0
        frame := this.Frame(title, 790)
        startDir := DirExist(initial) ? initial : A_ScriptDir
        SplitPath initial, &initialName
        frame.gui.AddText('x24 y76 w740 h22 c9999A8', 'Папка')
        address := frame.gui.AddEdit('x24 y104 w566 h34 Background171719 cEEEEF2 -Multi -VScroll', startDir)
        Theme.SingleLine(address)
        Theme.Button(frame.gui, 'x602 y103 w76 h36', 'Открыть').OnEvent('Click', (*) => Navigate(address.Value))
        Theme.Button(frame.gui, 'x690 y103 w76 h36', '↑ Выше').OnEvent('Click', Up)
        listing := frame.gui.AddListView('x24 y156 w742 h294 -Hdr -Multi Background1C1C1F cEEEEF2 -LV0x1 -E0x200', ['Имя', 'Тип'])
        Theme.Dark(listing)
        Theme.List(listing, 2)
        listing.ModifyCol(1, 572), listing.ModifyCol(2, 145)
        frame.gui.AddText('x24 y466 w742 h22 c9999A8', saving ? 'Имя файла' : 'Файл • можно вставить полный путь')
        filename := frame.gui.AddEdit('x24 y495 w742 h34 Background171719 cEEEEF2 -Multi -VScroll', saving ? initialName : '')
        Theme.SingleLine(filename)
        frame.filename := filename
        hint := frame.gui.AddText('x24 y542 w420 h38 c9999A8', filter)
        extensions := []
        position := 1
        while RegExMatch(filter, '\*\.(\w+)', &match, position) {
            extensions.Push(StrLower(match[1]))
            position := match.Pos + match.Len
        }
        rows := []
        selectedPath := ''
        listing.OnEvent('ItemSelect', Select)
        listing.OnEvent('DoubleClick', Open)
        ok := Theme.Button(frame.gui, 'x470 y549 w142 h38', saving ? 'Сохранить' : 'Выбрать', '765DFF')
        ok.OnEvent('Click', Commit)
        cancel := Theme.Button(frame.gui, 'x624 y549 w142 h38', 'Отмена')
        cancel.OnEvent('Click', (*) => frame.finish.Call('Cancel'))
        frame.buttons := [ok, cancel]
        Navigate(startDir)
        status := this.Wait(frame, 613)
        return status = 'OK' ? selectedPath : ''

        Navigate(directory) {
            if !DirExist(directory) {
                hint.Text := 'Папка не найдена.'
                return
            }
            address.Value := RTrim(directory, '\') '\'
            listing.Delete(), rows := []
            try {
                loop files address.Value '*', 'D' {
                    rows.Push({path: A_LoopFileFullPath, directory: true})
                    listing.Add(, '▸ ' A_LoopFileName, 'Папка')
                }
                loop files address.Value '*', 'F' {
                    SplitPath A_LoopFileName, , , &extension
                    allowed := extensions.Length = 0
                    for candidate in extensions {
                        if StrLower(extension) = candidate
                            allowed := true
                    }
                    if !allowed
                        continue
                    rows.Push({path: A_LoopFileFullPath, directory: false})
                    listing.Add(, A_LoopFileName, StrUpper(extension))
                }
            } catch
                hint.Text := 'Не удалось прочитать папку.'
        }
        Up(*) {
            SplitPath RTrim(address.Value, '\'), , &parent
            if parent
                Navigate(parent)
        }
        Select(control, index, selected) {
            if selected && index && !rows[index].directory {
                SplitPath rows[index].path, &name
                filename.Value := name
            }
        }
        Open(control, index) {
            if !index
                return
            if rows[index].directory
                Navigate(rows[index].path)
            else
                Commit()
        }
        Commit(*) {
            name := Trim(filename.Value)
            if name = '' {
                hint.Text := 'Укажи имя файла.'
                return
            }
            path := RegExMatch(name, 'i)^(?:[A-Z]:\\|\\\\)') ? name : address.Value name
            SplitPath path, , &directory, &extension
            if saving && extension = '' && extensions.Length
                path .= '.' extensions[1]
            if !DirExist(directory) {
                hint.Text := 'Папка для файла не найдена.'
                return
            }
            if !saving && !FileExist(path) {
                hint.Text := 'Файл не найден.'
                return
            }
            if saving && FileExist(path) && DarkDialog.Message('Заменить существующий файл?', 'Сохранение', 'YesNo') != 'Yes'
                return
            selectedPath := path
            frame.finish.Call('OK')
        }
    }

    static Choice(title, choices, current := '') {
        frame := this.Frame(title, 620)
        list := frame.gui.AddListView('x24 y82 w572 h344 -Hdr -Multi Background1C1C1F cEEEEF2 -LV0x1 -E0x200', ['Вариант'])
        Theme.Dark(list)
        Theme.List(list, 1)
        list.ModifyCol(1, 552)
        for index, label in choices {
            list.Add(, label)
            if label = current
                list.Modify(index, 'Select Focus Vis')
        }
        result := ''
        list.OnEvent('DoubleClick', Commit)
        select := Theme.Button(frame.gui, 'x308 y450 w140 h38', 'Выбрать', '765DFF')
        select.OnEvent('Click', Commit)
        cancel := Theme.Button(frame.gui, 'x456 y450 w140 h38', 'Отмена')
        cancel.OnEvent('Click', (*) => frame.finish.Call('Cancel'))
        frame.buttons := [select, cancel]
        frame.list := list
        status := this.Wait(frame, 513)
        return status = 'OK' ? result : ''
        Commit(*) {
            index := list.GetNext()
            if index {
                result := choices[index]
                frame.finish.Call('OK')
            }
        }
    }
}
