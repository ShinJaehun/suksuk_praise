import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  connect() {
  }

  close(){
    //this.element.innerHTML = ""
    //this.element.className = "modal-default"
    this.element.closest("turbo-frame#modal").innerHTML="";
  }
}
