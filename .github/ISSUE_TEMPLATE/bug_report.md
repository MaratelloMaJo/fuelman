name: "Bug Report / Отчет об ошибке"
description: "Report a bug, calculation issue, or app crash / Сообщить об ошибке или сбое"
title: "[BUG]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        ### 🇷🇺 Спасибо за помощь! / 🇬🇧 Thanks for reporting!
        Please fill in the details below / Пожалуйста, заполните форму ниже.

  - type: dropdown
    id: powertrain
    attributes:
      label: "Powertrain Type / Тип силовой установки"
      description: "Select powertrain of the vehicle / Выберите тип двигателя"
      options:
        - "PHEV (Plug-in Hybrid / Плагин-гибрид)"
        - "HEV (Classic Hybrid / Гибрид)"
        - "EV (Electric Vehicle / Электромобиль)"
        - "ICE (Petrol / Diesel / ДВС)"
        - "General UI / Settings (Общий интерфейс)"
    validations:
      required: true

  - type: dropdown
    id: platform
    attributes:
      label: "Platform / Платформа"
      options:
        - "Android"
        - "iOS"
        - "Emulator / Desktop"
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: "App Version or Commit / Версия приложения или коммит"
      placeholder: "e.g. v1.0.0 or 20eb38d"
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: "What happened? / Что пошло не так?"
      description: "Clear explanation of the error / Подробное описание проблемы"
      placeholder: "Cost per km calculation returns negative value when..."
    validations:
      required: true

  - type: textarea
    id: steps
    attributes:
      label: "Reproduction Steps / Шаги воспроизведения"
      placeholder: |
        1. Open 'Add Entry' screen
        2. Set SOC from 20% to 80%
        3. Tap Save button
    validations:
      required: true

  - type: textarea
    id: attachments
    attributes:
      label: "Logs or Screenshots / Логи или скриншоты"
      description: "Attach screenshots or paste logcat / flutter output"

  - type: checkboxes
    id: confirmations
    attributes:
      label: "Checklist / Чек-лист"
      options:
        - label: "I checked that this issue does not exist / Я проверил, что такого бага еще нет"
          required: true
