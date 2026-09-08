name: "🐛 Отчет об ошибке"
description: "Сообщить о баге, вылете или некорректном расчете расхода/зарядки"
title: "[BUG]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        ### Спасибо за участие в улучшении FuelMan!
        Пожалуйста, заполните форму ниже как можно подробнее. Это сэкономит время при диагностике.

  - type: dropdown
    id: powertrain
    attributes:
      label: "Тип силовой установки авто"
      description: "На каком типе двигателя произошла ошибка?"
      options:
        - "PHEV (Плагин-гибрид)"
        - "HEV (Классический гибрид)"
        - "EV (Чистый электромобиль)"
        - "ICE (Бензин / Дизель)"
        - "Не относится к расчету поездок (общий UI/настройки)"
    validations:
      required: true

  - type: dropdown
    id: platform
    attributes:
      label: "Платформа"
      options:
        - "Android (Realme / Xiaomi / Samsung и др.)"
        - "iOS"
        - "Эмулятор / Desktop"
    validations:
      required: true

  - type: input
    id: app-version
    attributes:
      label: "Версия приложения или коммит"
      placeholder: "например, v1.0.2 или коммит 20eb38d"
    validations:
      required: true

  - type: textarea
    id: what-happened
    attributes:
      label: "Что пошло не так?"
      description: "Четко опишите, что произошло, и чего вы ожидали вместо этого."
      placeholder: "При вводе емкости батареи 18.3 кВт·ч расчет средней стоимости километра выдал отрицательное число..."
    validations:
      required: true

  - type: textarea
    id: repro-steps
    attributes:
      label: "Шаги для воспроизведения"
      description: "Пошаговая инструкция, как добиться этой же ошибки."
      placeholder: |
        1. Открыть вкладку 'Автомобили'
        2. Нажать 'Добавить зарядку'
        3. Заполнить SOC с 20% по 80%
        4. Нажать кнопку сохранения
    validations:
      required: true

  - type: textarea
    id: logs-screenshots
    attributes:
      label: "Скриншоты или логи (если есть)"
      description: "Перетащите изображения прямо в это поле или вставьте логи Flutter (`flutter run -v`)."
      placeholder: "Прикрепите скриншот экрана с ошибкой..."

  - type: checkboxes
    id: checks
    attributes:
      label: "Финальная проверка"
      options:
        - label: "Я проверил, что этот баг еще не описан в существующих Issues"
          required: true
        - label: "Я использую последнюю версию из ветки `main`"
          required: false
