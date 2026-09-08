name: "💡 Идея или улучшение"
description: "Предложить новую формулу расчета, виджет или поддержку нового датчика/стандарта"
title: "[FEATURE]: "
labels: ["enhancement"]
body:
  - type: markdown
    attributes:
      value: |
        ### Есть крутая идея для гибридов, UI или аналитики?
        Опишите концепт, чтобы мы могли запланировать его в роадмапе.

  - type: dropdown
    id: feature-category
    attributes:
      label: "Категория предложения"
      options:
        - "🔋 Гибридный модуль / Расчеты батареи"
        - "📊 Аналитика, графики и статистика"
        - "🔌 Подключение OBD2 / Bluetooth телеметрия"
        - "🎨 Интерфейс, темы и анимации"
        - "🌐 Локализация (RU / EN / KK)"
        - "⚙️ Экспорт / Импорт данных (CSV, PDF)"
    validations:
      required: true

  - type: textarea
    id: problem
    attributes:
      label: "Какую проблему или боль решает эта фича?"
      placeholder: "Сейчас тяжело отслеживать ночной тариф на зарядку авто дома..."
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: "Предлагаемое решение"
      placeholder: "Добавить в настройки профиля авто поле 'Стоимость 1 кВт·ч (ночь)' и тумблер на экране добавления зарядки..."
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: "Альтернативы, которые вы рассматривали"
      placeholder: "Сейчас приходится вручную пересчитывать тенге в уме и вводить итоговую сумму..."

  - type: checkboxes
    id: contribution
    attributes:
      label: "Готовы помочь в реализации?"
      options:
        - label: "Я готов протестировать эту функцию, когда появится альфа-версия"
        - label: "Я готов сделать Pull Request с кодом"
