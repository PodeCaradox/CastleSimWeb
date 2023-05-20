import {AfterViewInit, Component, ElementRef, HostListener, OnInit, ViewChild} from '@angular/core';
import init, { InitOutput } from "src/assets/wasm/castle_sim";
import screenfull from 'screenfull';
@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements AfterViewInit, OnInit  {
  wasmModule: InitOutput | undefined;
  @ViewChild('gameFieldDiv') gameFieldDiv: ElementRef | undefined;
  @ViewChild('loadingElement', { read: ElementRef, static:false }) loading: ElementRef | undefined;
  isFullscreen: boolean = false;
  isLoaded: boolean = false;
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
      const canvas: HTMLCanvasElement = document.getElementById('castle_sim_canvas') as HTMLCanvasElement;
      if (canvas) {
        canvas.focus();
      }
    }


  }

  loading_state() {
    this.isLoaded = this.loading!.nativeElement.getAttribute('tag') as boolean;
    const canvas: HTMLCanvasElement = document.getElementById('castle_sim_canvas') as HTMLCanvasElement;
    if (canvas) {
      canvas.focus();
    }
  }

  ngOnInit(): void {
    this.isLoaded = false;
  }
}
