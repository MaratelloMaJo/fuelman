name: "💡 Feature Request / Идея или улучшение"
description: "Suggest a feature, formula, or integration / Предложить новую фичу или формулу"
title: "[FEATURE]: "
labels: ["enhancement"]
body:
  - type: dropdown
    id: category
    attributes:
      label: "Category / Категория"
      options:
        - "🔋 Hybrid & Battery Logic / Расчеты батареи"
        - "📊 Analytics & Charts / Аналитика и графики"
        - "🔌 OBD2 / BLE Telemetry / Телеметрия"
        - "🎨 UI & Theme / Интерфейс"
        - "🌐 Localization / Локализация"
        - "⚙️ Export & Import (CSV/PDF) / Экспорт данных"
    validations:
      required: true

  - type: textarea
    id: problem
    attributes:
      label: "Problem / Проблема"
      description: "What pain does this solve? / Какую проблему решает?"
      placeholder: "Currently hard to track dual-rate electricity tariffs..."
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: "Proposed Solution / Предлагаемое решение"
      placeholder: "Add day/night tariff inputs on charging screen..."
    validations:
      required: true

  - type: checkboxes
    id: help
    attributes:
      label: "Contribution / Готовность помочь"
      options:
        - label: "I can test this feature / Готов протестировать"
        - label: "I can submit a PR / Могу сделать Pull Request"
