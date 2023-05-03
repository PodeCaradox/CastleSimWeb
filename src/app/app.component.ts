import {AfterViewInit, Component, ElementRef, HostListener, OnInit, ViewChild} from '@angular/core';
import init, { InitOutput } from "src/assets/wasm/castle_sim";
import screenfull from 'screenfull';
@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements AfterViewInit  {
  wasmModule: InitOutput | undefined;
  @ViewChild('gameFieldDiv') gameFieldDiv: ElementRef | undefined;
  isFullscreen: boolean = false;
  async ngAfterViewInit() {
    if (screenfull.isEnabled) {
      screenfull.on('change', () => {
        this.isFullscreen = screenfull.isFullscreen;
      });
    }
    init().then(value => {
      this.wasmModule = value;
      this.wasmModule.run(this.gameFieldDiv?.nativeElement!.clientWidth, this.gameFieldDiv?.nativeElement!.clientHeight);
    });
  }


  fullscreen() {
    if (screenfull.isEnabled) {
      if(!screenfull.isFullscreen){
        screenfull.request();
      }else{
        screenfull.exit();
      }
    }

  }

}
