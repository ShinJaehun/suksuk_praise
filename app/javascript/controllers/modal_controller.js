import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["progress"]
  connect() {
  }

  close(){
    //this.element.innerHTML = ""
    //this.element.className = "modal-default"
    this.element.closest("turbo-frame#modal").innerHTML="";
  }

  //showProgress(event){
    //if(this.hasProgressTarget){
      //this.progressTarget.classList.remove("hidden");
      //this.progressTarget.querySelector(".bar").style.width="70%";
    //}
  //}
  showProgress(event) {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove("hidden");
      // 0%에서 시작
      let progress = 0;
      let target = this.progressTarget.querySelector('.bar');
      let count = Number(document.querySelector('input[type=number]').value || 30);
      let step = 100 / count;
      target.style.width = "0%";
      // 진짜 생성과 동기화되는 건 아니지만, UX 개선용
      let interval = setInterval(() => {
        progress += step;
        if (progress >= 100) {
          progress = 100;
          clearInterval(interval);
        }
        target.style.width = progress + "%";
      }, 100); // 0.1초마다 1명씩 처리된다고 가정
    }
  }
}
