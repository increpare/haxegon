package haxegon;

import haxe.Constraints.Function;
import haxe.Timer;
import openfl.Lib;
import openfl.geom.Matrix;
import starling.events.*;
import starling.display.*;
import starling.core.Starling;
import starling.core.StatsDisplay;

@:access(Main)
@:access(haxegon.Gfx)
@:access(haxegon.Text)
@:access(haxegon.Music)
@:access(haxegon.Mouse)
@:access(haxegon.Input)
@:access(haxegon.Scene)
class Core extends Sprite {
	public function new() {
		super();	
		
		addEventListener(Event.ADDED_TO_STAGE, addedtostage);
	}
	
	private function addedtostage(e:Event = null) {
		removeEventListener(Event.ADDED_TO_STAGE, addedtostage);
		loaded();
	}
	
	private static function callfunctionstartframe(?f:Function) {
		if (f == null) {
			startframeextended = false;
			extendedstartframefunction = null;
		}else {
			startframeextended = true;
			extendedstartframefunction = f;
		}
	}
	
	public static function callfunctionafterupdate(?f:Function) {
		if (f == null) {
		  updateextended = false;	
			extendedupdatefunction = null;
		}else {
			updateextended = true;
			extendedupdatefunction = f;
		}
	}
	
	public static function callfunctionafterrender(?f:Function) {
		if (f == null) {
		  renderextended = false;	
			extendedrenderfunction = null;
		}else {
			renderextended = true;
			extendedrenderfunction = f;
		}
	}
	
	private function loaded() {
		//Init library classes
		Random.setseed(Std.int(Math.random() * 233280));
		Input.init(this.stage, Starling.current.nativeStage);
		Mouse.init(this.stage, Starling.current.nativeStage);
		Gfx.init(this.stage);
		Music.init();
		Scene.init();
		
		//Did Main.new() already call Gfx.resizescreen? Then we can skip this! Otherwise...
		if(!Gfx.gfxinit){
			Gfx.resizescreen(stage.stageWidth, stage.stageHeight, 1);
		}
		
		// start game loop
		_rate3 = Math.round(3000 / TARGETFRAMERATE);
		_target3 = 3 * Lib.getTimer() + _rate3;
		
    stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
	
	private function onEnterFrame(e:Event) {
		if (!Scene.hasseperaterenderfunction) {
			//If we don't have a seperate render function, just fall back to onEnterFrame for now
			doupdate(0, 1);
		  return;	
		}
		
		var updatecount:Int = 0;
		
		// Ready the time!
		// "_time3", "_target3" and "_rate3" all work in thirds of a millisecond. This is because
		// frame times use even thirds (30fps = 33 1/3 ms, 60fps = 16 2/3ms) and we want to track
		// them accurately, so we can't use floating point (which would start to lose precision 
		// after an hour or so).
		//
		// Keep this in mind when working with these values. Divide them by 3 to get milliseconds.
		var _time3:Int = 3*Lib.getTimer();
		
		// Frames too fast? If we got here too soon, quit now and come back next time.
		// This uses a 0.5 frame offset because we want the hard boundaries that decide frameskip/
		// delay to be as far as possible from our regular frame timings. This way, our game needs
		// to move an entire half a frame off course in either direction before it stutters.
		if (_time3 < _target3 - 0.5*_rate3) {
			return;
		}
		
		if (startframeextended) extendedstartframefunction();
		
		// How many updates do we want?
		// Again, this uses a 0.5 frame offset before triggering frameskip.
		var frameupdates:Int = Math.ceil(Math.max(1.0, (_time3 - _target3 + 0.5 * _rate3) / _rate3));
		if (frameupdates > MAXFRAMESKIP) {
			_target3 += _rate3 * (frameupdates - MAXFRAMESKIP);
			frameupdates = MAXFRAMESKIP;
		}
		
		if (frameupdates == 1) {
			// TIME TWEAK: That 0.5 frame offset only helps smoothness if we can line up _target
			// with our regular frame times from OpenFL. This does that, by sliding _target backwards
			// and forwards as necessary.
			// Sliding by 1/3 ms per frame amounts to a 1% timeslip; 30fps becomes 29.7 - 30.3fps.
			// Barely noticeable, and OpenFL will be feeding us a solid 30 most of the time anyway.
			if (_target3 - _time3 > 0.1*_rate3) {
				_target3 -= 1;
			} else if (_target3 - _time3 < -0.1*_rate3) {
				_target3 += 1;
			}
		}

		// Run our frames!
		for (upd in 0 ... frameupdates) {
			_target3 += _rate3;
			
			// update loop
			doupdate(upd, frameupdates);
		}
		
		// render loop
		dorender();
	}

	private function doupdate(updateindex:Int, updatecount:Int) {
		Mouse.update(Gfx.getscreenx(Lib.current.mouseX), Gfx.getscreeny(Lib.current.mouseY), updateindex == 0);
		Input.update();
		
		if (!Scene.hasseperaterenderfunction) {
			Gfx.backbuffer.drawBundled(
				function(unused0:DisplayObject, unused1:Matrix, unused2:Float) {
					Scene.update();	
					Text.drawstringinput();
					Debug.showlog();
					
					if (updateextended) extendedupdatefunction(updateindex, updatecount);
				}
			);
		}else {
		  Scene.update();	
			if (updateextended) extendedupdatefunction(updateindex, updatecount);
		}
		
		Music.processmusic();
	}
	
	private function dorender() {
		Gfx.backbuffer.drawBundled(
		  function(unused0:DisplayObject, unused1:Matrix, unused2:Float) {
				Scene.render();
				Text.drawstringinput();
				Debug.showlog();
      }
		);
		
		if (renderextended) extendedrenderfunction();
	}
	
	public static var fps(get,set):Int;
	private static var _fps:Int;
	
	static function get_fps():Int {
		return _fps;
	}

	static function set_fps(_newfps:Int) {
		Starling.current.nativeStage.frameRate = _newfps;
		return _newfps;
	}
	
	// Timing information.
	private static inline var TARGETFRAMERATE:Int = 30;
	private static inline var MAXFRAMESKIP:Int = 4;

	private static var extendedstartframefunction:Dynamic = null;
	private static var extendedupdatefunction:Dynamic = null;
	private static var extendedrenderfunction:Dynamic = null;
	private static var startframeextended:Bool = false;
	private static var updateextended:Bool = false;
	private static var renderextended:Bool = false;
	
	private static var	_rate3:Int; // The time between frames, in thirds of a millisecond.
	private static var _target3:Int; // The ideal time to start the next frame, in thirds of a millisecond.
	
	public static var showstats(get,set):Bool;
	private static var _showstats:Bool;
	private static var statsdisplay:StatsDisplay;

	static function get_showstats():Bool {
		return _showstats;
	}

	static function set_showstats(_b:Bool) {
		if (Gfx.gfxinit) {
			//If we've already initilised the screen, add/remove the stats display now
			if (_b) {
			  statsdisplay = new StatsDisplay();
				Gfx.gfxstage.addChild(statsdisplay);
			}else {
			  if(statsdisplay != null) Gfx.gfxstage.removeChild(statsdisplay);
			}
		}
		_showstats = _b;
		return _showstats;
	}
}