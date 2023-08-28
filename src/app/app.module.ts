import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import {MatIconModule} from '@angular/material/icon';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import {MatButtonModule} from "@angular/material/button";
import {MatProgressSpinnerModule} from "@angular/material/progress-spinner";
import {NoRightClickDirective} from "./no-right-click.directive";

@NgModule({
  declarations: [
    AppComponent,
    NoRightClickDirective
  ],
    imports: [
        BrowserModule,
        AppRoutingModule,
        MatIconModule,
        MatButtonModule,
        BrowserAnimationsModule,
        MatProgressSpinnerModule,
    ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
