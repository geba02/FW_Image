# 🎨 Fireworks Image Generator

Нативное macOS-приложение для генерации изображений через [Fireworks AI](https://fireworks.ai) API.

## Установка (одна команда)

Открой **Терминал** и вставь:

```bash
curl --http1.1 -fsSL https://raw.githubusercontent.com/geba02/FW_Image/main/install.sh | bash
```

## Что установится

- Приложение `Fireworks Generator` в `~/Applications/`
- Ярлык на рабочем столе
- Папка для картинок `~/Applications/FW_Image/generated_images/`

## Требования

- macOS 12+
- Python 3 ([скачать](https://www.python.org/downloads/))
- API ключ [Fireworks AI](https://fireworks.ai) (бесплатная регистрация)

## Модели

| Модель | Скорость | Качество | Тип |
|--------|----------|----------|-----|
| ⚡ FLUX Schnell | 2-4 сек | Хорошее | Быстрая генерация |
| 📸 FLUX.1 Dev | 10-15 сек | Высокое | Фотореализм |
| 🎨 Kontext Pro | 15-30 сек | Высокое | Дизайн, текст |
| 💎 Kontext Max | 15-30 сек | Максимум | Лучшее качество |

## Использование

1. Запусти приложение
2. Введи API ключ Fireworks AI и нажми 💾
3. Выбери модель и формат
4. Напиши промпт
5. Нажми 🚀 Сгенерировать

> 💡 Промпт можно писать на любом языке, но на английском модели понимают точнее и выдают лучший результат.
