import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  connect() {
  }

  close(event){
    event.preventDefault()
    this.element.innerHTML = ""
  }
}
