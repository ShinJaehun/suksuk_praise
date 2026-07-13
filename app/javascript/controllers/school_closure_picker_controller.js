import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["startInput", "endInput", "status", "dayButton"]
    static values = {
        defaultStatus: String,
        startStatus: String,
        rangeStatus: String,
        resetStatus: String
    }

    connect() {
        this.syncFromInputs()
    }

    selectDate(event) {
        const date = event.currentTarget.dataset.schoolClosurePickerDateValue
        if (!date) return

        if (!this.startDate || (this.startDate && this.endDate && this.startDate !== this.endDate)) {
            this.setRange(date, date)
            this.setStatus(this.startStatusValue, { start: date })
            return
        }

        if (date < this.startDate) {
            this.setRange(date, date)
            this.setStatus(this.resetStatusValue, { start: date })
            return
        }

        this.setRange(this.startDate, date)
        this.setStatus(this.rangeStatusValue, { start: this.startDate, end: date })
    }

    reset() {
        this.setRange("", "")
        this.setStatus(this.defaultStatusValue)
    }

    syncFromInputs() {
        this.startDate = this.hasStartInputTarget ? this.startInputTarget.value : ""
        this.endDate = this.hasEndInputTarget ? this.endInputTarget.value : ""
        this.paintSelection()
    }

    setRange(start, end) {
        this.startDate = start
        this.endDate = end
        if (this.hasStartInputTarget) this.startInputTarget.value = start
        if (this.hasEndInputTarget) this.endInputTarget.value = end
        this.paintSelection()
    }

    paintSelection() {
        if (!this.hasDayButtonTarget) return

        this.dayButtonTargets.forEach((button) => {
            const date = button.dataset.schoolClosurePickerDateValue
            const selected = date && (date === this.startDate || date === this.endDate)
            const inRange = date && this.startDate && this.endDate && date >= this.startDate && date <= this.endDate

            button.classList.toggle("school-closure-calendar__day--selected", selected)
            button.classList.toggle("school-closure-calendar__day--in-range", inRange)
        })
    }

    setStatus(template, values = {}) {
        if (!this.hasStatusTarget || !template) return

        this.statusTarget.textContent = template
            .replace("%{start}", values.start || "")
            .replace("%{end}", values.end || "")
    }
}
