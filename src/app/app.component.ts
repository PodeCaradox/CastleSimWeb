import {
  AfterViewInit,
  Component,
  ElementRef,
  EventEmitter,
  HostListener, NgZone,
  OnDestroy,
  OnInit,
  ViewChild
} from '@angular/core';
import init, { InitOutput } from "src/assets/wasm/castle_sim";
import screenfull from 'screenfull';
@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements AfterViewInit, OnInit, OnDestroy  {
  private observer: MutationObserver;
  wasmModule: InitOutput | undefined;
  @ViewChild('gameFieldDiv') gameFieldDiv: ElementRef | undefined;
  @ViewChild('loadingElement', { read: ElementRef, static:false }) loading: ElementRef | undefined;
  isFullscreen: boolean = false;
  isLoaded: boolean = false;
  tagChange = new EventEmitter<string>();
  constructor(private el: ElementRef, private ngZone: NgZone) {
    this.observer = new MutationObserver((mutations: MutationRecord[]) => {
      mutations.forEach((mutation: MutationRecord) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'tag') {
          this.ngZone.run(() => {
            const newTag = this.el.nativeElement.getAttribute('tag');
            this.tagChange.emit(newTag);
          });
        }
      });
    });
  }
  ngOnDestroy(): void {
    this.observer.disconnect();
  }
  async ngAfterViewInit() {
    this.tagChange.subscribe((newTag: string) => this.tagChanged(newTag))
    if (screenfull.isEnabled) {
      screenfull.on('change', () => {
        this.isFullscreen = screenfull.isFullscreen;
      });
    }
    init().then(value => {


      this.observer.observe(this.loading!.nativeElement, {
        attributes: true //configure it to listen to attribute changes
      });



      this.wasmModule = value;
      this.wasmModule.run(this.gameFieldDiv?.nativeElement!.clientWidth, this.gameFieldDiv?.nativeElement!.clientHeight);
    });
  }

  private tagChanged(newTag: string) {

    const canvas: HTMLCanvasElement = document.getElementById('castle_sim_canvas') as HTMLCanvasElement;
    if (canvas) {
      window.dispatchEvent(new Event('resize'));
      canvas.focus();
    }
    this.isLoaded = this.loading!.nativeElement.getAttribute('tag') as boolean;
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

  ngOnInit(): void {
    this.isLoaded = false;
  }
}
