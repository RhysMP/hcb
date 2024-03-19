import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'field',
    'button',
    'form',
    'move',
    'memo',
    'memoField',
    'card',
  ]
  static values = {
    enabled: { type: Boolean, default: false },
    locked: { type: Boolean, default: false },
    memo: { type: String, default: 'Untitled Expense' },
  }

  connect() {
    for (const field of this.fieldTargets) {
      field.readOnly = !this.enabledValue
      field.addEventListener('dblclick', () => this.edit())
      this.#addTooltip(field, 'Double-click to edit...')
    }

    this.buttonTarget.addEventListener('click', e => {
      e.preventDefault()
      if (this.enabledValue) {
        this.formTarget.requestSubmit()
      } else {
        this.edit()
      }
    })

    this.#buttons()
    this.#label()
    this.#memo()
    this.#memoInput()
    this.#card()
    this.#move()
  }

  edit() {
    if (this.enabledValue || this.lockedValue) return
    this.enabledValue = true

    this.#memo()
    this.#buttons()
    this.#label()
    this.#card()
    this.#move()

    for (const field of this.fieldTargets) {
      field.readOnly = false
      this.#removeTooltip(field)
    }
  }

  #memoInput() {
    if (this.enabledValue) {
      this.memoFieldTarget.focus()
    }
  }

  #buttons() {
    if (!this.lockedValue) {
      this.buttonTarget.querySelector('[aria-label=checkmark]').style.display =
        this.enabledValue ? 'block' : 'none'
      this.buttonTarget.querySelector('[aria-label=edit]').style.display = this
        .enabledValue
        ? 'none'
        : 'block'
    }
  }

  #card() {
    if (this.enabledValue && !this.lockedValue) {
      this.cardTarget.classList.add('b--warning')
    }
  }

  #label() {
    if (!this.lockedValue) {
      this.buttonTarget.ariaLabel =
        this.enabledValue && !this.lockedValue
          ? 'Save edits'
          : 'Edit this expense'
    }
  }

  #move() {
    if (this.enabledValue && !this.lockedValue) {
      this.moveTarget.style.display = 'none'
    }
  }

  #memo() {
    this.memoTarget.innerText =
      this.enabledValue && !this.lockedValue
        ? `Unsaved Changes`
        : this.memoValue
    if (this.enabledValue && !this.lockedValue) {
      this.memoTarget.classList.add('warning')
      this.memoTarget.classList.remove('muted')
    }
  }

  #addTooltip(field, label) {
    if (!label || this.lockedValue || this.enabledValue) return

    const fieldWrapper = document.createElement('div')
    field.parentNode.insertBefore(fieldWrapper, field)
    fieldWrapper.appendChild(field)
    fieldWrapper.classList.add('tooltipped', 'tooltipped--n')
    fieldWrapper.setAttribute('aria-label', label)
  }

  #removeTooltip(field) {
    const fieldWrapper = field.parentNode
    fieldWrapper.parentNode.insertBefore(field, fieldWrapper)
    fieldWrapper.remove()
  }
}
